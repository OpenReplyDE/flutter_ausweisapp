import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A browser session inside the example app.
///
/// The login of a real service runs in a web page. That page ends in an eID
/// client link, which the app takes over, and the service expects the return
/// address of the authentication to be opened in the same session. Tests
/// replace the web view with a fake.
abstract interface class WebLogin {
  /// Called before the page navigates to [url]. Returns true when the app
  /// handles the address itself; the page then does not navigate.
  bool Function(Uri url)? onNavigation;

  /// Opens [url] in this session.
  Future<void> load(Uri url);

  /// The widget that shows the page.
  Widget buildView();
}

/// Turns the user agent of a web view into that of the system browser.
///
/// Some services check the browser on the server and turn a web view away,
/// because its user agent names no browser: on iOS it lacks the tokens
/// `Version/…` and `Safari/…`, on Android it carries `Version/4.0`, which
/// reads as a very old Safari. [osVersion] is
/// `Platform.operatingSystemVersion`; Safari carries the version of iOS.
String browserUserAgent(String userAgent, {required String osVersion}) {
  if (userAgent.contains('Chrome/')) {
    return userAgent.replaceFirst(RegExp(r' Version/[\d.]+'), '');
  }
  if (!userAgent.contains('AppleWebKit/') || userAgent.contains('Safari/')) {
    return userAgent;
  }
  final version = RegExp(r'\d+\.\d+').firstMatch(osVersion)?.group(0);
  if (version == null) return userAgent;
  // Safari names the version before the Mobile token, which an iPad lacks.
  final mobile = userAgent.indexOf(' Mobile/');
  final end = mobile < 0 ? userAgent.length : mobile;
  return '${userAgent.substring(0, end)} Version/$version'
      '${userAgent.substring(end)} Safari/604.1';
}

/// [WebLogin] backed by the platform web view.
class WebViewLogin implements WebLogin {
  WebViewLogin() {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: _onNavigationRequest),
      );
  }

  final _controller = WebViewController();

  @override
  bool Function(Uri url)? onNavigation;

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = Uri.tryParse(request.url);
    final handled = url != null && (onNavigation?.call(url) ?? false);
    return handled ? NavigationDecision.prevent : NavigationDecision.navigate;
  }

  /// Completes when the web view presents itself as the system browser.
  late final Future<void> _browserUserAgent = _useBrowserUserAgent();

  Future<void> _useBrowserUserAgent() async {
    final userAgent = await _controller.getUserAgent();
    if (userAgent == null) return;
    await _controller.setUserAgent(
      browserUserAgent(userAgent, osVersion: Platform.operatingSystemVersion),
    );
  }

  @override
  Future<void> load(Uri url) async {
    await _browserUserAgent;
    await _controller.loadRequest(url);
  }

  @override
  Widget buildView() => WebViewWidget(controller: _controller);
}
