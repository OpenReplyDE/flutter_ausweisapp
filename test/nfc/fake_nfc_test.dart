import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports NFC as available by default', () async {
    final AusweisAppNfc nfc = FakeAusweisAppNfc();
    expect(await nfc.status(), NfcStatus.available);
  });

  test('reports the status it was created with', () async {
    for (final status in NfcStatus.values) {
      expect(await FakeAusweisAppNfc(nfcStatus: status).status(), status);
    }
  });

  test('the status can be changed between two queries', () async {
    final nfc = FakeAusweisAppNfc(nfcStatus: NfcStatus.disabled);
    expect(await nfc.status(), NfcStatus.disabled);
    nfc.nfcStatus = NfcStatus.available;
    expect(await nfc.status(), NfcStatus.available);
  });

  test('openSettings counts its calls and returns true by default', () async {
    final nfc = FakeAusweisAppNfc();
    expect(nfc.openSettingsCalls, 0);
    expect(await nfc.openSettings(), isTrue);
    expect(await nfc.openSettings(), isTrue);
    expect(nfc.openSettingsCalls, 2);
  });

  test('openSettings returns the configured result', () async {
    final nfc = FakeAusweisAppNfc(openSettingsResult: false);
    expect(await nfc.openSettings(), isFalse);
    expect(nfc.openSettingsCalls, 1);
  });

  test('statusError is thrown by the next status only', () async {
    final nfc = FakeAusweisAppNfc()
      ..statusError = const AusweisAppTransportException('nfc_failed', 'x');
    await expectLater(nfc.status(), throwsA(isA<AusweisAppException>()));
    expect(await nfc.status(), NfcStatus.available);
  });
}
