import 'package:flutter/material.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_ausweisapp_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

const _defaultUrl =
    'https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request';

const _reader = {
  'name': 'Simulator',
  'insertable': true,
  'attached': true,
  'keypad': true,
  'card': null,
};

Future<FakeAusweisAppTransport> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final fake = FakeAusweisAppTransport();
  await tester.pumpWidget(MyApp(transport: fake));
  return fake;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Finder _inLog(String text) => find.descendant(
  of: find.byKey(const Key('eventLog')),
  matching: find.textContaining(text),
);

Future<void> _start(WidgetTester tester) => _tap(tester, 'SDK starten');

void main() {
  testWidgets('start button starts the SDK and shows it running', (
    tester,
  ) async {
    final fake = await _pump(tester);
    expect(find.text('SDK gestoppt'), findsOneWidget);

    await _start(tester);

    expect(fake.sent.map((c) => c['cmd']), contains('SET_API_LEVEL'));
    expect(find.text('SDK läuft'), findsOneWidget);
    expect(find.text('SDK gestoppt'), findsNothing);
  });

  testWidgets('authentication button sends RUN_AUTH with the default URL', (
    tester,
  ) async {
    final fake = await _pump(tester);
    await _start(tester);

    await _tap(tester, 'Authentisierung starten');

    final run = fake.sent.singleWhere((c) => c['cmd'] == 'RUN_AUTH');
    expect(run['tcTokenURL'], _defaultUrl);
  });

  testWidgets('optional access rights become switches that send '
      'SET_ACCESS_RIGHTS', (tester) async {
    final fake = await _pump(tester);
    await _start(tester);

    fake.emit({
      'msg': 'ACCESS_RIGHTS',
      'chat': {
        'effective': ['Address', 'FamilyName'],
        'optional': ['Address', 'Nationality'],
        'required': ['FamilyName'],
      },
    });
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SwitchListTile, 'Address'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Nationality'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Nationality'));
    await tester.pumpAndSettle();

    final set = fake.sent.singleWhere((c) => c['cmd'] == 'SET_ACCESS_RIGHTS');
    expect(set['chat'], unorderedEquals(['Address', 'Nationality']));
  });

  testWidgets('sending a PIN sends SET_PIN and keeps it out of the log', (
    tester,
  ) async {
    final fake = await _pump(tester);
    await _start(tester);

    await tester.enterText(find.byKey(const Key('secretField')), '123456');
    await _tap(tester, 'als PIN senden');

    final set = fake.sent.singleWhere((c) => c['cmd'] == 'SET_PIN');
    expect(set['value'], '123456');
    expect(_inLog('123456'), findsNothing);
  });

  testWidgets('the plugin log switch keeps the PIN out of the log', (
    tester,
  ) async {
    final fake = await _pump(tester);
    await tester.tap(find.byKey(const Key('pluginLogSwitch')));
    await tester.pumpAndSettle();
    await _start(tester);

    await tester.enterText(find.byKey(const Key('secretField')), '123456');
    await _tap(tester, 'als PIN senden');

    expect(fake.sent.any((c) => c['cmd'] == 'SET_PIN'), isTrue);
    expect(_inLog('SET_PIN'), findsWidgets);
    expect(_inLog('123456'), findsNothing);
  });

  testWidgets('an ENTER_PIN message shows up in the event log', (tester) async {
    final fake = await _pump(tester);
    await _start(tester);

    fake.emit({'msg': 'ENTER_PIN', 'reader': _reader});
    await tester.pumpAndSettle();

    expect(_inLog('PinRequested'), findsOneWidget);
  });

  testWidgets('an eID client link fills the URL field', (tester) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const Key('clientLinkField')),
      'http://127.0.0.1:24727/eID-Client?tcTokenURL='
      '${Uri.encodeComponent('https://example.org/token')}',
    );
    await _tap(tester, 'Link übernehmen');

    expect(find.text('https://example.org/token'), findsOneWidget);
  });

  testWidgets('an invalid eID client link shows a hint', (tester) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const Key('clientLinkField')),
      'nonsense',
    );
    await _tap(tester, 'Link übernehmen');

    expect(
      find.textContaining('Kein gültiger eID-Client-Link'),
      findsOneWidget,
    );
  });

  testWidgets('an empty input field sends SET_PIN without a value', (
    tester,
  ) async {
    final fake = await _pump(tester);
    await _start(tester);

    await _tap(tester, 'als PIN senden');

    final set = fake.sent.singleWhere((c) => c['cmd'] == 'SET_PIN');
    expect(set.containsKey('value'), isFalse);
  });

  testWidgets('an invalid URL sends nothing and logs a hint', (tester) async {
    final fake = await _pump(tester);
    await _start(tester);
    await tester.enterText(
      find.byKey(const Key('tcTokenUrlField')),
      'ht!tp://',
    );

    await _tap(tester, 'Authentisierung starten');

    expect(fake.sent.any((c) => c['cmd'] == 'RUN_AUTH'), isFalse);
    expect(_inLog('Ungültige tcTokenURL'), findsOneWidget);
  });
}
