# Integrating the plugin into an app

Deutsche Fassung: [integration.de.md](integration.de.md)

This guide is for developers who add `flutter_ausweisapp` to an existing Flutter app whose login runs through a web page, for example an identity provider that offers the German eID (Online-Ausweis) as a login method. It describes what the app has to build around the plugin. The plugin's API and the platform setup are in the [README](../README.md).

## What changes for the app

Without the plugin, the login page hands the eID step to the separate AusweisApp. With the plugin, the app does this step itself:

1. The app opens the login page in an embedded web view.
2. When the user chooses the eID, the page navigates to an eID client link (`…/eID-Client?tcTokenURL=https://…`). The app intercepts this navigation and passes the `tcTokenURL` to the plugin.
3. The plugin reports what the SDK needs: access rights to confirm, the ID card, the PIN. The app shows its own screens for this.
4. When the authentication ends, the SDK returns an address. The app opens it in the same web view, so that the service learns the result in the session that started the login.
5. The login page finishes and redirects to the app's own scheme (for example `com.example.app:/oauth2redirect?code=…`). The app intercepts this navigation as well and completes its login with the code, as it does today.

This flow has been run on an iPhone with a real ID card against a production service up to the redirect in step 5; see [device-test.md](device-test.md). Whether a particular service permits it must be clarified with its operator.

## Requirements

| Requirement | Value |
| --- | --- |
| Flutter | 3.41 or newer (Dart 3.11) |
| Android | `minSdk` 28 (Android 9), devices with extended-length NFC |
| iOS | deployment target 17.0, Swift Package Manager enabled for the app, NFC entitlement |
| Login | the login page runs in a web view that the app controls |

Two of these are decisions for the product, not just settings:

- **iOS 17.** The SDK does not run on older versions. If the app supports older versions today, it has to raise its minimum version.
- **Web view instead of the system browser.** Login libraries that open the system browser (`ASWebAuthenticationSession` on iOS, Custom Tabs on Android) do not let the app see the eID client link. The login has to run in a web view such as `webview_flutter`, and the app handles the redirect and the token exchange itself.

## 1. Add the dependency

The plugin is not on pub.dev. Reference the Git repository and pin a tag:

```yaml
dependencies:
  flutter_ausweisapp:
    git:
      url: https://github.com/OpenReplyDE/flutter_ausweisapp.git
      ref: v0.2.0
```

The repository is public, so build machines need no access setup. Pin a tag rather than a branch, so that a build does not change without a change in your `pubspec.yaml`.

## 2. Set up the platforms

Follow the sections "Android setup" and "iOS setup" in the [README](../README.md). In short:

- Android: `minSdk = 28`; an own `Application` class skips its initialization in the process whose name ends in `ausweisapp2_service`.
- iOS: enable Swift Package Manager in the app's `pubspec.yaml`, deployment target 17.0, NFC entitlement `TAG`, and the two `Info.plist` entries.

Plugins of the app that do not offer a Swift package yet keep being integrated through CocoaPods.

## 3. Build the login flow

The following class contains the whole flow. It needs the packages `webview_flutter` and `url_launcher` in addition to the plugin. The callbacks stand for the app's own screens and for its existing token exchange.

```dart
import 'dart:async';

import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum EidInput { pin, can, puk }

/// Runs a web login and hands its eID step to the AusweisApp SDK.
class EidLoginFlow {
  EidLoginFlow({
    required this.loginUrl,
    required this.redirectScheme,
    required this.onAccessRights,
    required this.onCardNeeded,
    required this.onInput,
    required this.onRedirect,
    required this.onNfcUnavailable,
    required this.onFailed,
    this.appSchemes = const {},
    this.nfc = const MethodChannelAusweisAppNfc(),
  });

  /// The complete login address of the service, with all its parameters.
  final Uri loginUrl;

  /// The scheme of the app's redirect address, for example `com.example.app`.
  final String redirectScheme;

  /// Show the access rights; afterwards call `eid.accept()` or `eid.cancel()`.
  final void Function(AccessRights rights) onAccessRights;

  /// Ask the user to hold the ID card against the device.
  final void Function() onCardNeeded;

  /// Show the input screen; afterwards call `eid.setPin`, `setCan` or `setPuk`.
  final void Function(EidInput input, int? retryCounter) onInput;

  /// The login is finished: the address carries the code for the token exchange.
  final void Function(Uri redirect) onRedirect;

  /// The device cannot read the ID card now: [status] is
  /// `NfcStatus.unsupported` or, on Android, `NfcStatus.disabled`.
  final void Function(NfcStatus status) onNfcUnavailable;

  /// The authentication failed or was cancelled. [kind] chooses the text;
  /// [code] is the raw code for support.
  final void Function(FailureKind kind, String? code) onFailed;

  /// The schemes of other apps that the login page may open, for example
  /// `elster-secure` for a login with ElsterSecure.
  final Set<String> appSchemes;

  /// The NFC state of the device; tests pass a `FakeAusweisAppNfc`.
  final AusweisAppNfc nfc;

  final eid = AusweisApp();
  late final WebViewController web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(onNavigationRequest: _onNavigation),
    );
  StreamSubscription<AusweisAppEvent>? _events;

  Future<void> start() async {
    // Subscribe before start(), so that no event is lost.
    _events = eid.events.listen(_onEvent);
    await eid.start();
    await web.loadRequest(loginUrl);
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = Uri.tryParse(request.url);
    if (url == null) return NavigationDecision.navigate;

    // The page wants to start the eID client: the SDK takes over.
    final tcTokenUrl = tcTokenUrlFromEidClientLink(url);
    if (tcTokenUrl != null) {
      unawaited(_startScan(tcTokenUrl));
      return NavigationDecision.prevent;
    }

    // The login page is done and redirects to the app.
    if (url.scheme == redirectScheme) {
      onRedirect(url);
      return NavigationDecision.prevent;
    }

    // The page links to another app: the system opens it, the page stays.
    if (appSchemes.contains(url.scheme)) {
      unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  /// Starts the authentication if the device can read the ID card now.
  Future<void> _startScan(Uri tcTokenUrl) async {
    final status = await nfc.status();
    if (status != NfcStatus.available) {
      onNfcUnavailable(status);
      return;
    }
    await eid.startAuthentication(tcTokenUrl: tcTokenUrl);
  }

  void _onEvent(AusweisAppEvent event) {
    switch (event) {
      case AccessRightsRequested(:final rights):
        onAccessRights(rights);
      case InsertCardRequested():
        onCardNeeded();
      case PinRequested(:final reader):
        unawaited(eid.interrupt()); // closes the NFC dialog on iOS
        onInput(EidInput.pin, reader.card?.retryCounter);
      case CanRequested():
        unawaited(eid.interrupt());
        onInput(EidInput.can, null);
      case PukRequested():
        unawaited(eid.interrupt());
        onInput(EidInput.puk, null);
      case AuthenticationCompleted(:final result):
        // The address reports the result to the service, also a failure.
        if (result.url case final url?) unawaited(web.loadRequest(url));
        if (result.failureKind case final kind?) onFailed(kind, result.reason);
      case AuthenticationStartFailed(:final error):
        onFailed(FailureKind.other, error);
      default:
        break;
    }
  }

  Future<void> dispose() async {
    await _events?.cancel();
    await eid.stop();
    await eid.dispose();
  }
}
```

Show the web view with `WebViewWidget(controller: flow.web)` while the user is on the login page, and the app's own screens while the SDK is working. Do not set `developerMode` for a production service; the SDK rejects it there.

The class asks for the NFC state at the moment the page starts the eID step. If the device has no NFC or NFC is switched off, it does not start the authentication, and the web view stays on the login page. On `NfcStatus.disabled`, show a button that calls `flow.nfc.openSettings()`; once NFC is on, the user chooses the eID on the page again. `flow.start()` passes on the `AusweisAppStartException` of `eid.start()`; its `failureKind` is `timeout` or `other`.

### Services that check the browser

Some services check the browser on the server and turn a web view away. ELSTER, which also runs the login of "Mein Unternehmenskonto", shows its configuration assistant with "Nicht unterstützter Browser" (unsupported browser) instead of the login page. The reason is the user agent of the web view: on iOS, it lacks the tokens `Version/…` and `Safari/…` that Safari sends, and on Android, it carries `Version/4.0`, which the check reads as a very old Safari.

If the app has to work with such a service, give the web view the user agent of the system browser. This function converts it:

```dart
import 'dart:io' show Platform;

/// Turns the user agent of a web view into that of the system browser.
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
```

In `start()`, set it before the first page loads:

```dart
    final userAgent = await web.getUserAgent();
    if (userAgent != null) {
      await web.setUserAgent(
        browserUserAgent(userAgent, osVersion: Platform.operatingSystemVersion),
      );
    }
    await web.loadRequest(loginUrl);
```

A service may turn web views away on purpose. Clarify with its operator whether it permits a login in a web view.

### Login methods that use another app

Some login methods continue in another app. For a login with ElsterSecure, the page of ELSTER opens a link with the scheme `elster-secure`, the user confirms the login in the ElsterSecure app, and the page then continues. A web view does not follow such a link by itself, so nothing happens on the page.

The class above hands the schemes in `appSchemes` to the system with `launchUrl` from the package `url_launcher`. It leaves the web view open, because the page waits there for the confirmation:

```dart
final flow = EidLoginFlow(
  // …
  appSchemes: {'elster-secure'},
);
```

Name the schemes explicitly instead of handing over every unknown scheme; otherwise the login page decides which apps your app opens. `launchUrl` returns `false` if no app takes the link. The class ignores that; show a hint at this point if your app needs one.

A login with ElsterSecure needs this handover and the user agent from the previous section. Observed on an iPhone with iOS 27.2.1: with both, the login with ElsterSecure works in the example app. Android has not been tested.

## 4. Complete the login

`onRedirect` receives the redirect address with the parameters `code` and `state`. From here on, nothing is specific to the eID: check `state` against the value the app sent, and exchange `code` at the token endpoint together with the PKCE verifier. The app creates `state` and the PKCE values itself when it builds `loginUrl`, because no login library does it in this flow.

## What the screens have to handle

| Event | What the app shows | Then |
| --- | --- | --- |
| before the scan, `nfc.status()` returns `NfcStatus.unsupported` | a message that this device cannot read the ID card (no NFC) | nothing; the eID step is not possible on this device |
| before the scan, `nfc.status()` returns `NfcStatus.disabled` (Android only) | a message that NFC is switched off, with a button to the settings | `nfc.openSettings()`; ask `nfc.status()` again when the app returns to the foreground |
| `AccessRightsRequested` | the data the service asks for | `eid.accept()` or `eid.cancel()` |
| `InsertCardRequested` | a hint to hold the ID card against the device | nothing; the SDK continues by itself |
| `PinRequested` | PIN input, with `retryCounter` if it is below 3 | `eid.setPin(pin)` |
| `CanRequested` | CAN input (six digits on the front of the card) | `eid.setCan(can)` |
| `PukRequested` | PUK input (from the PIN letter) | `eid.setPuk(puk)` |
| `AuthenticationCompleted` with `isSuccess == false` | a text chosen by `result.failureKind`: `network` for a connection problem, `timeout` for a timeout, `cardConnection` for an ID card that was moved or removed, `userCancelled` for a cancellation (usually no error text), `other` a general text with `result.reason` as the code for support | start the login again |
| `AusweisAppStartException` from `eid.start()` | by its `failureKind`: `timeout` the timeout text, `other` the general text with `code` | call `eid.start()` again |

After a wrong PIN, the SDK asks again with a lower `retryCounter`; at 1 it asks for the CAN first, at 0 for the PUK. A correct PIN resets the counter to 3.

The kinds and the codes behind them are in the section "Failure kinds" of the [README](../README.md). The SDK has no code for a device that is offline; that case arrives as `network` together with other connection problems. NFC states are not failures of the SDK and never arrive as events: the app asks for them itself.

## Behavior on iOS to plan for

Observed on an iPhone 16 Pro with iOS 27.2.1:

- While the SDK waits for the ID card or reads it, the system shows its NFC dialog, and the app cannot be operated underneath it. The app needs no cancel button of its own in this state; the user cancels in the dialog, and the app receives `AuthenticationCompleted` with `reason: User_Cancelled`.
- The dialog stays open when the SDK asks for PIN, CAN or PUK. `eid.interrupt()` closes it, which is why the class above calls it before every input. After the input is sent, the dialog appears again and the user holds the card against the device once more.
- If the card is pulled away while it is being read, the flow fails (`AuthenticationCompleted` without success). The login has to start over.
- The texts of the dialog come from the parameter `userInfoMessages` of `startAuthentication`.

On Android, there is no system dialog; the app shows its own hint while the card is read. Android has not been tested on real hardware yet.

## Testing

- **Screens without a device:** `AusweisApp(transport: FakeAusweisAppTransport())` from `package:flutter_ausweisapp/testing.dart` lets widget tests send any SDK message to the app's screens.
- **NFC states without a device:** `FakeAusweisAppNfc(nfcStatus: NfcStatus.disabled)` from the same file replaces the NFC state of the device, so that the screens for "no NFC" and "NFC switched off" can be tested on any machine.
- **Without an ID card:** the SDK's simulator card works against the Governikus test service with `developerMode: true`; see "Simulator card" in the README.
- **Real ID cards** work only against a production service and without developer mode. Test cards of the test PKI work against test services.
- The example app in `example/` contains the flow described here as a test tool ("Anmeldung im Browser", login in the browser).

## Before release

- Read [NOTICE.md](../NOTICE.md): an app that ships the plugin distributes the SDK and has to meet the obligations of the EUPL.
- Clarify with the operator of the login service whether the embedded flow is permitted.
- Complete the device test on Android; see [device-test.md](device-test.md).
