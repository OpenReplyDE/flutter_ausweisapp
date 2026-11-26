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

  @override
  Future<void> load(Uri url) => _controller.loadRequest(url);

  @override
  Widget buildView() => WebViewWidget(controller: _controller);
}
