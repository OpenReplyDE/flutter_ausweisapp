import 'package:flutter/material.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_ausweisapp_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<FakeAusweisAppTransport> _pump(
  WidgetTester tester,
  FakeAusweisAppNfc nfc,
) async {
  tester.view.physicalSize = const Size(900, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final transport = FakeAusweisAppTransport();
  await tester.pumpWidget(MyApp(transport: transport, nfc: nfc));
  await tester.pumpAndSettle();
  return transport;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Finder _inLog(String text) => find.descendant(
  of: find.byKey(const Key('eventLog')),
  matching: find.textContaining(text),
);

void main() {
  for (final (status, label) in [
    (NfcStatus.unsupported, 'NFC: kein NFC'),
    (NfcStatus.disabled, 'NFC: ausgeschaltet'),
    (NfcStatus.available, 'NFC: verfügbar'),
  ]) {
    testWidgets('shows "$label" without starting the SDK', (tester) async {
      final transport = await _pump(
        tester,
        FakeAusweisAppNfc(nfcStatus: status),
      );

      expect(find.text(label), findsOneWidget);
      expect(find.text('SDK gestoppt'), findsOneWidget);
      expect(transport.sent, isEmpty);
    });
  }

  testWidgets('the status button asks again and logs the answer', (
    tester,
  ) async {
    final nfc = FakeAusweisAppNfc(nfcStatus: NfcStatus.disabled);
    await _pump(tester, nfc);
    expect(_inLog('NFC-Status'), findsNothing);

    nfc.nfcStatus = NfcStatus.available;
    await _tap(tester, 'NFC-Status abfragen');

    expect(find.text('NFC: verfügbar'), findsOneWidget);
    expect(_inLog('NFC-Status: verfügbar (available)'), findsOneWidget);
  });

  testWidgets('the settings button opens the NFC settings', (tester) async {
    final nfc = FakeAusweisAppNfc(nfcStatus: NfcStatus.disabled);
    await _pump(tester, nfc);

    await _tap(tester, 'Zu den NFC-Einstellungen');

    expect(nfc.openSettingsCalls, 1);
    expect(_inLog('NFC-Einstellungen geöffnet: ja'), findsOneWidget);
  });

  testWidgets('the log says so when no settings were opened', (tester) async {
    final nfc = FakeAusweisAppNfc(openSettingsResult: false);
    await _pump(tester, nfc);

    await _tap(tester, 'Zu den NFC-Einstellungen');

    expect(_inLog('NFC-Einstellungen geöffnet: nein'), findsOneWidget);
  });

  testWidgets('asks again when the app comes back to the foreground', (
    tester,
  ) async {
    final nfc = FakeAusweisAppNfc(nfcStatus: NfcStatus.disabled);
    await _pump(tester, nfc);
    expect(find.text('NFC: ausgeschaltet'), findsOneWidget);

    // The user switched NFC on in the settings and came back.
    nfc.nfcStatus = NfcStatus.available;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(find.text('NFC: verfügbar'), findsOneWidget);
  });

  testWidgets('a failing status query shows "unbekannt" and the error', (
    tester,
  ) async {
    final nfc = FakeAusweisAppNfc()
      ..statusError = const AusweisAppTransportException('nfc_failed', 'x');
    await _pump(tester, nfc);

    expect(find.text('NFC: unbekannt'), findsOneWidget);
    expect(_inLog('Fehler bei NFC-Status'), findsOneWidget);
  });

  testWidgets('the log shows the failure kind of a failed authentication', (
    tester,
  ) async {
    final transport = await _pump(tester, FakeAusweisAppNfc());
    await _tap(tester, 'SDK starten');

    transport.emit({
      'msg': 'AUTH',
      'result': {
        'major': 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error',
        'reason': 'Get_TcToken_Network_Error',
      },
    });
    await tester.pumpAndSettle();

    expect(
      _inLog('reason: Get_TcToken_Network_Error, failureKind: network'),
      findsOneWidget,
    );
  });

  testWidgets('the log shows no failure kind for a successful one', (
    tester,
  ) async {
    final transport = await _pump(tester, FakeAusweisAppNfc());
    await _tap(tester, 'SDK starten');

    transport.emit({
      'msg': 'AUTH',
      'result': {
        'major': 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok',
      },
    });
    await tester.pumpAndSettle();

    expect(_inLog('isSuccess: true'), findsOneWidget);
    expect(_inLog('failureKind'), findsNothing);
  });
}
