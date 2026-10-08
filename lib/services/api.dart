import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import '../config.dart';
import 'offline.dart';

/// Résultat d'un envoi : réussi, sans réseau, ou refusé par le serveur (avec le motif).
class SendResult {
  final bool ok;
  final bool offline;
  final int status;
  final String message;
  final Map<String, dynamic>? data;
  const SendResult({this.ok = false, this.offline = false, this.status = 0, this.message = '', this.data});
}

const _timeout = Duration(seconds: 25);

/// Service API unique (singleton) — gère le token JWT et les appels au backend Django.
class Api {
  Api._();
  static final Api instance = Api._();

  /// Client HTTP (remplaçable dans les tests).
  http.Client client = http.Client();

  String? _access;
  String? _refresh;
  Map<String, dynamic>? user;

  bool get isLoggedIn => _access != null;
  String get role => (user?['role'] ?? '').toString();
  String get fullName => (user?['full_name'] ?? user?['username'] ?? '').toString();
  String? get cooperativeId => user?['cooperative_id']?.toString();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_access != null) 'Authorization': 'Bearer $_access',
      };

  Future<void> loadToken() async {
    final p = await SharedPreferences.getInstance();
    _access = p.getString('access');
    _refresh = p.getString('refresh');
    final u = p.getString('user');
    if (u != null) user = jsonDecode(u) as Map<String, dynamic>;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (_access != null) await p.setString('access', _access!);
    if (_refresh != null) await p.setString('refresh', _refresh!);
    if (user != null) await p.setString('user', jsonEncode(user));
  }

  Future<void> logout() async {
    await Offline.instance.clearAll();
    final p = await SharedPreferences.getInstance();
    await p.remove('access');
    await p.remove('refresh');
    await p.remove('user');
    _access = null;
    _refresh = null;
    user = null;
  }

  /// Renouvelle la session (jeton d'accès de 2 h, renouvelable 30 jours) : indispensable après une journée sans réseau.
  Future<bool> _refreshToken() async {
    if (_refresh == null) return false;
    try {
      final r = await client.post(Uri.parse('$kApiBase/auth/token/refresh/'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh': _refresh})).timeout(_timeout);
      if (r.statusCode != 200) return false;
      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _access = d['access'];
      if (d['refresh'] != null) _refresh = d['refresh'];   // rotation des jetons côté serveur
      await _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Requête authentifiée : renouvelle la session une fois si le jeton a expiré.
  Future<http.Response> _authed(Future<http.Response> Function() call) async {
    var r = await call().timeout(_timeout);
    if (r.statusCode == 401 && await _refreshToken()) r = await call().timeout(_timeout);
    return r;
  }

  /// Envoi d'une création (POST) en distinguant « pas de réseau » d'un refus du serveur.
  Future<SendResult> send(String path, Map<String, dynamic> body) async {
    try {
      final r = await _authed(() => client.post(Uri.parse('$kApiBase$path'), headers: _headers, body: jsonEncode(body)));
      final txt = utf8.decode(r.bodyBytes);
      final d = txt.isEmpty ? null : jsonDecode(txt);
      if (r.statusCode == 200 || r.statusCode == 201) return SendResult(ok: true, status: r.statusCode, data: d as Map<String, dynamic>?);
      return SendResult(status: r.statusCode, message: _errorText(d) ?? 'Erreur ${r.statusCode}');
    } on SocketException {
      return const SendResult(offline: true);
    } on TimeoutException {
      return const SendResult(offline: true);
    } on http.ClientException {
      return const SendResult(offline: true);
    } catch (e) {
      return SendResult(offline: true, message: e.toString());
    }
  }

  static String? _errorText(dynamic d) {
    if (d is Map) {
      if (d['detail'] != null) return d['detail'].toString();
      return d.entries.map((e) => '${e.key} : ${e.value is List ? (e.value as List).join(' ') : e.value}').join(' · ');
    }
    return null;
  }

  /// Liste avec copie locale : sans réseau, renvoie la dernière liste reçue (fromCache = true).
  Future<({List<dynamic> data, bool fromCache})> listCached(String path, String key) async {
    try {
      // toutes les pages (une coopérative peut avoir des milliers de producteurs)
      final all = <dynamic>[];
      String? url = '$kApiBase$path';
      var ok = true;
      for (var page = 0; url != null && page < 100; page++) {
        final u = url;
        final r = await _authed(() => client.get(Uri.parse(u), headers: _headers));
        if (r.statusCode != 200) { ok = false; break; }
        final d = jsonDecode(utf8.decode(r.bodyBytes));
        if (d is List) { all.addAll(d); url = null; } else { all.addAll((d['results'] ?? []) as List<dynamic>); url = d['next'] as String?; }
      }
      if (ok) {   // une erreur serveur n'écrase jamais la copie locale
        await Offline.cacheList(key, all);
        return (data: all, fromCache: false);
      }
    } catch (_) {/* pas de réseau : copie locale */}
    return (data: await Offline.cachedList(key) ?? <dynamic>[], fromCache: true);
  }

  /// Connexion — renvoie true si succès.
  Future<bool> login(String username, String password) async {
    final r = await client.post(
      Uri.parse('$kApiBase/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (r.statusCode == 200) {
      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _access = d['access'];
      _refresh = d['refresh'];
      user = d['user'];
      await _save();
      return true;
    }
    return false;
  }

  /// Connexion avec Google : le jeton d'identité est vérifié par le serveur, qui retrouve le compte par son e-mail.
  /// Renvoie null si succès, sinon le message d'erreur à afficher.
  Future<String?> loginWithGoogle(String idToken) async {
    final r = await client.post(
      Uri.parse('$kApiBase/auth/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'credential': idToken}),
    );
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode == 200 && d is Map<String, dynamic>) {
      _access = d['access'];
      _refresh = d['refresh'];
      user = d['user'];
      await _save();
      return null;
    }
    return (d is Map && d['detail'] != null) ? d['detail'].toString() : 'Connexion Google impossible.';
  }

  /// Liste (gère la pagination DRF).
  Future<List<dynamic>> list(String path) async {
    final r = await client.get(Uri.parse('$kApiBase$path'), headers: _headers);
    if (r.statusCode == 200) {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is List) return d;
      return (d['results'] ?? []) as List<dynamic>;
    }
    return [];
  }

  /// Création (POST).
  Future<Map<String, dynamic>?> create(String path, Map<String, dynamic> body) async {
    final r = await client.post(Uri.parse('$kApiBase$path'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode == 200 || r.statusCode == 201) {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    }
    return null;
  }

  /// Changement de mot de passe.
  Future<bool> changePassword(String oldP, String newP) async {
    final r = await client.post(
      Uri.parse('$kApiBase/auth/change-password/'),
      headers: _headers,
      body: jsonEncode({'old_password': oldP, 'new_password': newP}),
    );
    return r.statusCode == 200;
  }
}
