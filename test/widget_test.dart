// Test de base de l'application GeoCollect EUDR.
import 'package:flutter_test/flutter_test.dart';
import 'package:geocollect_mobile/config.dart';

void main() {
  test('Configuration API definie', () {
    expect(kApiBase.startsWith('https://'), true);
    expect(kAppName, 'GeoCollect EUDR');
  });
}
