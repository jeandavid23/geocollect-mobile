import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocollect_mobile/services/api.dart';
import 'package:geocollect_mobile/services/offline.dart';

Map<String, dynamic> parcel() => {
      'producer': 'p1', 'geometry': {'type': 'Polygon', 'coordinates': [[[-5.7, 7.7], [-5.69, 7.7], [-5.69, 7.71], [-5.7, 7.7]]]},
      'area_hectares': 1.2,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'access': 'old', 'refresh': 'r1', 'user': jsonEncode({'id': 'agent-1', 'role': 'agent', 'full_name': 'Agent'}),
    });
    await Api.instance.loadToken();
    await Offline.instance.load();
    Offline.instance.outbox.clear();
  });

  test('sans réseau : la parcelle reste sur le téléphone', () async {
    Api.instance.client = MockClient((_) async => throw const SocketException('pas de réseau'));
    await Offline.instance.enqueue(parcel(), 'Kouamé');
    final sent = await Offline.instance.sync();
    expect(sent, 0);
    expect(Offline.instance.pendingCount, 1);
    // survit à un redémarrage de l'application
    await Offline.instance.load();
    expect(Offline.instance.pendingCount, 1);
  });

  test('retour du réseau : envoi, session renouvelée, même identifiant à chaque essai', () async {
    final ids = <String>[];
    var refreshed = false;
    Api.instance.client = MockClient((req) async {
      if (req.url.path.endsWith('/auth/token/refresh/')) {
        refreshed = true;
        return http.Response(jsonEncode({'access': 'new', 'refresh': 'r2'}), 200);
      }
      ids.add(jsonDecode(req.body)['client_id']);
      // jeton expiré après une journée sans réseau
      if (req.headers['Authorization'] == 'Bearer old') return http.Response('{"detail":"expired"}', 401);
      return http.Response(jsonEncode({'id': 'x', 'field_id': 'F-1'}), 201);
    });
    await Offline.instance.enqueue(parcel(), 'Kouamé');
    final sent = await Offline.instance.sync();
    expect(refreshed, true);
    expect(sent, 1);
    expect(Offline.instance.pendingCount, 0);
    expect(ids.length, 2);
    expect(ids[0], ids[1]);                 // le serveur dédoublonne grâce à cet identifiant
    final p = await SharedPreferences.getInstance();
    expect(p.getString('refresh'), 'r2');   // jeton tourné bien enregistré
  });

  test('refus du serveur : relevé marqué, pas de boucle infinie', () async {
    var calls = 0;
    Api.instance.client = MockClient((_) async { calls++; return http.Response(jsonEncode({'producer': ['Producteur inconnu.']}), 400); });
    await Offline.instance.enqueue(parcel(), 'Kouamé');
    await Offline.instance.sync();
    await Offline.instance.sync();
    expect(calls, 1);
    expect(Offline.instance.errorCount, 1);
    expect(Offline.instance.mine.first.error, contains('Producteur inconnu'));
  });

  test("téléphone partagé : les relevés d'un autre agent ne partent pas sous ce compte", () async {
    Api.instance.client = MockClient((_) async => http.Response('{}', 201));
    await Offline.instance.enqueue(parcel(), 'Kouamé');            // relevé de agent-1
    Api.instance.user = {'id': 'agent-2', 'role': 'agent'};
    expect(Offline.instance.pendingCount, 0);
    expect(await Offline.instance.sync(), 0);
    expect(Offline.instance.outbox.length, 1);
  });

  test('liste hors ligne : dernière copie reçue', () async {
    Api.instance.client = MockClient((_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'results': [{'id': 'p1', 'full_name': 'Kouamé'}], 'next': null})), 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    final online = await Api.instance.listCached('/producers/', 'producers');
    expect(online.fromCache, false);
    Api.instance.client = MockClient((_) async => throw const SocketException('pas de réseau'));
    final offline = await Api.instance.listCached('/producers/', 'producers');
    expect(offline.fromCache, true);
    expect(offline.data.first['full_name'], 'Kouamé');
  });
}
