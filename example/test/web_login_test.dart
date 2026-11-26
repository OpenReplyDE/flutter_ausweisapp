import 'package:flutter/material.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_ausweisapp_example/main.dart';
import 'package:flutter_ausweisapp_example/web_login.dart';
import 'package:flutter_test/flutter_test.dart';

const _loginUrl = 'https://login.example.org/auth?client_id=app';
const _tcTokenUrl = 'https://eid.example.org/tctoken?session=abc123';
const _returnUrl = 'https://eid.example.org/refresh?session=abc123&result=ok';

/// Stands in for the real web view: records what the app loads and lets the
/// test report a navigation as the page would.
class _FakeWebLogin implements WebLogin {
  final loaded = <Uri>[];

  @override
  bool Function(Uri url)? onNavigation;

  @override
  Future<void> load(Uri url) async => loaded.add(url);

  @override
  Widget buildView() => const Text('web view');
}

Uri _eidClientLink(String tcTokenUrl) => Uri.parse(
  'http://127.0.0.1:24727/eID-Client'
  '?tcTokenURL=${Uri.encodeQueryComponent(tcTokenUrl)}',
);

Finder _inLog(String text) => find.descendant(
  of: find.byKey(const Key('eventLog')),
  matching: find.textContaining(text),
);

Future<(FakeAusweisAppTransport, _FakeWebLogin)> _pump(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(900, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final transport = FakeAusweisAppTransport();
  final web = _FakeWebLogin();
  await tester.pumpWidget(
    MyApp(transport: transport, nfc: FakeAusweisAppNfc(), webLogin: () => web),
  );
  return (transport, web);
}

Future<void> _openBrowser(WidgetTester tester, [String url = _loginUrl]) async {
  await tester.enterText(find.byKey(const Key('loginUrlField')), url);
  await tester.tap(find.text('Im Browser anmelden'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('browser login shows the web page and loads the login address', (
    tester,
  ) async {
    final (_, web) = await _pump(tester);

    await _openBrowser(tester);

    expect(web.loaded, [Uri.parse(_loginUrl)]);
    expect(find.text('web view'), findsOneWidget);
  });

  testWidgets('an invalid login address opens nothing and logs a hint', (
    tester,
  ) async {
    final (_, web) = await _pump(tester);

    await _openBrowser(tester, 'not a url');

    expect(web.loaded, isEmpty);
    expect(find.text('web view'), findsNothing);
    expect(_inLog('Ungültige Login-Adresse'), findsOneWidget);
  });

  testWidgets('an ordinary navigation is left to the web page', (tester) async {
    final (transport, web) = await _pump(tester);
    await _openBrowser(tester);

    final handled = web.onNavigation!(Uri.parse('https://bund.example/next'));
    await tester.pumpAndSettle();

    expect(handled, isFalse);
    expect(find.text('web view'), findsOneWidget);
    expect(transport.sent, isEmpty);
  });

  testWidgets('an eID client link closes the web page, starts the SDK and the '
      'authentication with its tcTokenURL', (tester) async {
    final (transport, web) = await _pump(tester);
    await _openBrowser(tester);

    final handled = web.onNavigation!(_eidClientLink(_tcTokenUrl));
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('web view'), findsNothing);
    expect(transport.sent.map((c) => c['cmd']), ['SET_API_LEVEL', 'RUN_AUTH']);
    expect(transport.sent.last['tcTokenURL'], _tcTokenUrl);
  });

  testWidgets('an eID client link with the eid scheme is taken over too', (
    tester,
  ) async {
    final (transport, web) = await _pump(tester);
    await _openBrowser(tester);

    final handled = web.onNavigation!(
      Uri.parse(
        'eid://127.0.0.1:24727/eID-Client'
        '?tcTokenURL=${Uri.encodeQueryComponent(_tcTokenUrl)}',
      ),
    );
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(transport.sent.last['tcTokenURL'], _tcTokenUrl);
  });

  testWidgets(
    'after the authentication the return address is loaded in the same '
    'browser session and the web page is shown again',
    (tester) async {
      final (transport, web) = await _pump(tester);
      await _openBrowser(tester);
      web.onNavigation!(_eidClientLink(_tcTokenUrl));
      await tester.pumpAndSettle();

      transport.emit({
        'msg': 'AUTH',
        'result': {
          'major': 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok',
        },
        'url': _returnUrl,
      });
      await tester.pumpAndSettle();

      expect(web.loaded, [Uri.parse(_loginUrl), Uri.parse(_returnUrl)]);
      expect(find.text('web view'), findsOneWidget);
    },
  );

  testWidgets('addresses from the browser flow never reach the event log', (
    tester,
  ) async {
    final (transport, web) = await _pump(tester);
    await _openBrowser(tester);
    web.onNavigation!(_eidClientLink(_tcTokenUrl));
    await tester.pumpAndSettle();
    transport.emit({
      'msg': 'AUTH',
      'result': {
        'major': 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok',
      },
      'url': _returnUrl,
    });
    await tester.pumpAndSettle();
    // Back to the test screen, where the log is.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(_inLog('abc123'), findsNothing);
    expect(_inLog('eID-Client-Link aus dem Browser'), findsOneWidget);
    expect(_inLog('Rückkehr-Adresse im Browser geöffnet'), findsOneWidget);
  });

  testWidgets(
    'a redirect to an app scheme closes the web page and logs the scheme '
    'and the parameter names, not the values',
    (tester) async {
      final (transport, web) = await _pump(tester);
      await _openBrowser(tester);

      final handled = web.onNavigation!(
        Uri.parse('de.example.app:/oauth2redirect?state=xyz789&code=s3cr3t'),
      );
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('web view'), findsNothing);
      expect(transport.sent, isEmpty);
      expect(
        _inLog(
          'Weiterleitung an eine App empfangen '
          '(Schema: de.example.app, Parameter: code, state)',
        ),
        findsOneWidget,
      );
      expect(_inLog('s3cr3t'), findsNothing);
      expect(_inLog('xyz789'), findsNothing);
    },
  );

  testWidgets(
    'the browser flow starts the authentication without developer mode, '
    'although the switch is on',
    (tester) async {
      final (transport, web) = await _pump(tester);
      await _openBrowser(tester);

      web.onNavigation!(_eidClientLink(_tcTokenUrl));
      await tester.pumpAndSettle();

      expect(transport.sent.last['cmd'], 'RUN_AUTH');
      expect(transport.sent.last['developerMode'], isFalse);
    },
  );

  testWidgets(
    'an authentication started by hand still uses the developer mode switch',
    (tester) async {
      final (transport, _) = await _pump(tester);
      await tester.tap(find.text('SDK starten'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Authentisierung starten'));
      await tester.pumpAndSettle();

      expect(transport.sent.last['cmd'], 'RUN_AUTH');
      expect(transport.sent.last['developerMode'], isTrue);
    },
  );

  testWidgets(
    'after a failed authentication from the browser the app stays on the '
    'log and does not open the return address',
    (tester) async {
      final (transport, web) = await _pump(tester);
      await _openBrowser(tester);
      web.onNavigation!(_eidClientLink(_tcTokenUrl));
      await tester.pumpAndSettle();

      transport.emit({
        'msg': 'AUTH',
        'result': {
          'major': 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error',
          'reason': 'Pre_Verification_No_Test_Environment',
        },
        'url': _returnUrl,
      });
      await tester.pumpAndSettle();

      expect(web.loaded, [Uri.parse(_loginUrl)]);
      expect(find.text('web view'), findsNothing);
      expect(_inLog('Pre_Verification_No_Test_Environment'), findsOneWidget);
      expect(
        _inLog('Authentisierung gescheitert: Die Rückkehr-Adresse wurde'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an authentication started by hand does not open the browser afterwards',
    (tester) async {
      final (transport, web) = await _pump(tester);
      await tester.tap(find.text('SDK starten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Authentisierung starten'));
      await tester.pumpAndSettle();

      transport.emit({
        'msg': 'AUTH',
        'result': {
          'major': 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok',
        },
        'url': _returnUrl,
      });
      await tester.pumpAndSettle();

      expect(web.loaded, isEmpty);
      expect(find.text('web view'), findsNothing);
    },
  );
}
