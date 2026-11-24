import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = 'https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request?a=1&b=2';
  final encoded = Uri.encodeQueryComponent(token);
  for (final link in [
    'http://127.0.0.1:24727/eID-Client?tcTokenURL=$encoded',
    'http://localhost:24727/eID-Client?tcTokenURL=$encoded',
    'eid://127.0.0.1:24727/eID-Client?tcTokenURL=$encoded',
    'https://www.example.de/eID-Client?foo=bar&tcTokenURL=$encoded',
  ]) {
    test('extracts the token URL from $link', () {
      expect(tcTokenUrlFromEidClientLink(Uri.parse(link)), Uri.parse(token));
    });
  }
  for (final link in [
    'http://127.0.0.1:24727/eID-Client', // Parameter fehlt
    'http://127.0.0.1:24727/eID-Client?tcTokenURL=', // leer
    'http://127.0.0.1:24727/eID-Client?tcTokenURL=not%20a%20url',
    'http://127.0.0.1:24727/eID-Client?tcTokenURL=http%3A%2F%2Fa.example%2Ft', // kein https
    'http://127.0.0.1:24727/other?tcTokenURL=$encoded', // anderer Pfad
  ]) {
    test('returns null for $link', () {
      expect(tcTokenUrlFromEidClientLink(Uri.parse(link)), isNull);
    });
  }
}
