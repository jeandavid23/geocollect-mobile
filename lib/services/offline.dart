import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Parcelle enregistrée sur le téléphone, en attente d'envoi au serveur.
class PendingParcel {
  final String clientId;            // identifiant unique créé sur le téléphone (aucun doublon côté serveur)
  final Map<String, dynamic> body;  // corps de la requête POST /parcels/
  final String producerName;
  final DateTime createdAt;
  final String userId;              // agent auteur du relevé (téléphone partagé : envoyé uniquement sous son compte)
  int attempts;
  String? error;                    // refus définitif du serveur (données invalides) : ne plus réessayer seul

  PendingParcel({required this.clientId, required this.body, required this.producerName, required this.createdAt,
      required this.userId, this.attempts = 0, this.error});

  Map<String, dynamic> toJson() => {
        'client_id': clientId, 'body': body, 'producer_name': producerName,
        'created_at': createdAt.toIso8601String(), 'user_id': userId, 'attempts': attempts, 'error': error,
      };

  static PendingParcel fromJson(Map<String, dynamic> j) => PendingParcel(
        clientId: j['client_id'], body: Map<String, dynamic>.from(j['body']), producerName: j['producer_name'] ?? '',
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(), userId: j['user_id'] ?? '',
        attempts: j['attempts'] ?? 0, error: j['error'],
      );
}

/// Mode hors ligne : boîte d'envoi des parcelles + copies locales des listes (producteurs, parcelles).
/// Les parcelles sont TOUJOURS enregistrées d'abord sur le téléphone, puis envoyées dès que le réseau le permet.
class Offline extends ChangeNotifier {
  Offline._();
  static final Offline instance = Offline._();

  static const _kOutbox = 'outbox_parcels';
  final List<PendingParcel> outbox = [];
  bool syncing = false;
  DateTime? lastSync;
  String? lastMessage;
  Timer? _timer;

  String get _me => Api.instance.user?['id']?.toString() ?? '';
  /// Relevés de l'agent connecté (ceux d'un autre agent sur le même téléphone restent en attente de son compte).
  List<PendingParcel> get mine => outbox.where((p) => p.userId == _me).toList();
  int get pendingCount => mine.where((p) => p.error == null).length;
  int get errorCount => mine.where((p) => p.error != null).length;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    outbox
      ..clear()
      ..addAll((jsonDecode(p.getString(_kOutbox) ?? '[]') as List).map((e) => PendingParcel.fromJson(Map<String, dynamic>.from(e))));
    final ls = p.getString('last_sync');
    lastSync = ls == null ? null : DateTime.tryParse(ls);
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOutbox, jsonEncode(outbox.map((e) => e.toJson()).toList()));
  }

  static String newClientId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Enregistre la parcelle sur le téléphone (instantané, sans réseau).
  Future<PendingParcel> enqueue(Map<String, dynamic> body, String producerName) async {
    final id = newClientId();
    final item = PendingParcel(clientId: id, body: {...body, 'client_id': id}, producerName: producerName,
        createdAt: DateTime.now(), userId: _me);
    outbox.add(item);
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> remove(PendingParcel item) async {
    outbox.removeWhere((p) => p.clientId == item.clientId);
    await _persist();
    notifyListeners();
  }

  /// Remet une parcelle refusée dans la file (après correction côté coopérative, par exemple).
  Future<void> retry(PendingParcel item) async {
    item.error = null;
    await _persist();
    notifyListeners();
    await sync();
  }

  /// Envoie les parcelles en attente. Renvoie le nombre de parcelles envoyées.
  Future<int> sync() async {
    if (syncing || !Api.instance.isLoggedIn) return 0;
    final todo = mine.where((p) => p.error == null).toList();
    if (todo.isEmpty) return 0;
    syncing = true;
    notifyListeners();
    int sent = 0;
    try {
      for (final item in todo) {
        item.attempts++;
        final r = await Api.instance.send('/parcels/', item.body);
        if (r.ok) {
          outbox.removeWhere((p) => p.clientId == item.clientId);
          sent++;
        } else if (r.offline) {
          lastMessage = 'Pas de réseau : nouvel essai automatique.';
          break;                                       // inutile d'insister : on réessaiera plus tard
        } else if (r.status == 401) {
          lastMessage = 'Session expirée : reconnectez-vous (vos parcelles restent sur le téléphone).';
          break;
        } else if (r.status >= 400 && r.status < 500) {
          item.error = r.message;                      // donnée refusée : à corriger, pas de boucle infinie
        } else {
          lastMessage = 'Serveur indisponible : nouvel essai automatique.';
          break;
        }
        await _persist();
      }
      if (sent > 0) {
        lastSync = DateTime.now();
        lastMessage = '$sent parcelle(s) envoyée(s).';
        final p = await SharedPreferences.getInstance();
        await p.setString('last_sync', lastSync!.toIso8601String());
      }
    } finally {
      await _persist();
      syncing = false;
      notifyListeners();
    }
    return sent;
  }

  /// Essais automatiques toutes les 2 minutes tant que l'application est ouverte.
  void startAutoSync() {
    _timer ??= Timer.periodic(const Duration(minutes: 2), (_) => sync());
    sync();
  }

  // ─── Copies locales des listes (consultables sans réseau) ────────────────────
  static Future<void> cacheList(String key, List<dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('cache_$key', jsonEncode(data));
    await p.setString('cache_${key}_at', DateTime.now().toIso8601String());
  }

  static Future<List<dynamic>?> cachedList(String key) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('cache_$key');
    return s == null ? null : jsonDecode(s) as List<dynamic>;
  }

  static Future<DateTime?> cachedAt(String key) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('cache_${key}_at');
    return s == null ? null : DateTime.tryParse(s);
  }

  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('cache_')).toList()) {
      await p.remove(k);
    }
    // la boîte d'envoi est conservée : un agent qui se déconnecte ne perd pas ses relevés
  }
}
