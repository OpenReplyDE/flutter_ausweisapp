import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp_example/web_login.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _tcTokenUrl = 'https://eid.example.org/tctoken?session=abc';

/// A page that goes to [target] by script, as a login page does when it
/// starts the eID client.
Uri _pageRedirectingTo(String target) => Uri.dataFromString(
  '<html><body><script>window.location.href = "$target";</script>'
  '</body></html>',
  mimeType: 'text/html',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the web view reports a redirect to an app scheme before following it',
    (tester) async {
      final web = WebViewLogin();
      final seen = Completer<Uri>();
      web.onNavigation = (url) {
        if (url.scheme != 'de.example.app') return false;
        if (!seen.isCompleted) seen.complete(url);
        return true;
      };
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: web.buildView())),
      );

      await web.load(
        _pageRedirectingTo('de.example.app:/oauth2redirect?code=1&state=2'),
      );

      final url = await tester.runAsync(
        () => seen.future.timeout(const Duration(seconds: 20)),
      );
      expect(url!.queryParameters.keys, containsAll(['code', 'state']));
    },
  );

  testWidgets('the web view presents itself to a page as the system browser', (
    tester,
  ) async {
    final web = WebViewLogin();
    final seen = Completer<String>();
    web.onNavigation = (url) {
      if (url.scheme != 'de.example.app') return false;
      if (!seen.isCompleted) seen.complete(url.queryParameters['value']);
      return true;
    };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: web.buildView())));

    await web.load(
      Uri.dataFromString(
        '<html><body><script>window.location.href = "de.example.app:/ua'
        '?value=" + encodeURIComponent(navigator.userAgent);</script>'
        '</body></html>',
        mimeType: 'text/html',
      ),
    );

    final userAgent = await tester.runAsync(
      () => seen.future.timeout(const Duration(seconds: 20)),
    );
    // Safari and Chrome both name Safari; only the Android web view carries
    // the Version token next to Chrome.
    expect(userAgent, contains('Safari/'));
    expect(userAgent, isNot(matches(r'Version/\S+ Chrome/')));
    debugPrint('User agent of the web view: $userAgent');
  });

  for (final scheme in ['http', 'eid']) {
    testWidgets(
      'the web view hands an eID client link with the $scheme scheme to the '
      'app instead of opening it',
      (tester) async {
        final link =
            '$scheme://127.0.0.1:24727/eID-Client'
            '?tcTokenURL=${Uri.encodeQueryComponent(_tcTokenUrl)}';
        final web = WebViewLogin();
        final taken = Completer<Uri>();
        web.onNavigation = (url) {
          final tcTokenUrl = tcTokenUrlFromEidClientLink(url);
          if (tcTokenUrl == null) return false;
          if (!taken.isCompleted) taken.complete(tcTokenUrl);
          return true;
        };
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: web.buildView())),
        );

        await web.load(_pageRedirectingTo(link));

        final tcTokenUrl = await tester.runAsync(
          () => taken.future.timeout(const Duration(seconds: 20)),
        );
        expect(tcTokenUrl, Uri.parse(_tcTokenUrl));
      },
    );
  }
}
