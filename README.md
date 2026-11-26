# flutter_ausweisapp

Deutsche Fassung: [README.de.md](README.de.md)

`flutter_ausweisapp` integrates the Governikus AusweisApp SDK (version 2.6.3) into Flutter apps for Android and iOS. With it, a user can authenticate with the German eID (Online-Ausweis) without leaving the app: the SDK reads the card over NFC, and the app shows all dialogs (PIN, CAN, PUK, access rights) on its own screens. The plugin ships no user interface. It passes the SDK's JSON commands and messages through to Dart and exposes them as typed methods and as an event stream.

**Status of the device tests.** On iOS, the plugin has been tested on an iPhone 16 Pro with iOS 27.2.1 and a real ID card, including a complete login against a production service; the results are in `docs/device-test.md`. **On Android, real NFC is still untested:** the emulator and the simulator have no NFC, and the SDK's simulator card bypasses reading the card entirely. Everything that involves NFC on Android counts as verified only once the checklist has been completed there on a real device.

## Contents

- [Usage](#usage)
- [Android setup](#android-setup)
- [iOS setup](#ios-setup)
- [Platform differences](#platform-differences)
- [Lifecycle and errors](#lifecycle-and-errors)
- [Handling PIN, CAN and PUK](#handling-pin-can-and-puk)
- [Simulator card](#simulator-card)
- [Development](#development)
- [SDK update](#sdk-update)
- [Scope: the app's login flow](#scope-the-apps-login-flow)
- [License](#license)

## Usage

Add the plugin through a path or Git entry in the app's `pubspec.yaml` (it is not published on pub.dev). After that, one import is enough:

```dart
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
```

The class `AusweisApp` has one method for each SDK command. Responses arrive only as events on the `events` stream, named after their meaning (for example `PinRequested`).

**Subscribe to `events` before you call `start()`.** The stream is a broadcast stream; events without a listener are lost.

```dart
final eid = AusweisApp();

final subscription = eid.events.listen((event) {
  switch (event) {
    case AuthenticationStarted():
      showProgress();
    case AuthenticationStartFailed(:final error):
      showStartError(error); // RUN_AUTH rejected, for example because of the tcTokenURL
    case AccessRightsRequested(:final rights):
      showRights(rights); // afterwards eid.accept() or eid.cancel()
    case InsertCardRequested():
      showCardHint();
    case PinRequested(:final reader):
      eid.interrupt(); // closes the NFC dialog on iOS, see below
      showPinScreen(reader.card?.retryCounter); // afterwards eid.setPin(...)
    case CanRequested():
      eid.interrupt();
      showCanScreen(); // afterwards eid.setCan(...)
    case PukRequested():
      eid.interrupt();
      showPukScreen(); // afterwards eid.setPuk(...)
    case NewPinRequested():
      eid.interrupt();
      showNewPinScreen(); // afterwards eid.setNewPin(...)
    case Paused():
      showReposition(); // afterwards eid.continueWorkflow()
    case AuthenticationCompleted(:final result):
      // The URL reports the result to the service, including a failure.
      if (result.url case final url?) openResultUrl(url);
      showResult(result.isSuccess);
    case ChangePinCompleted(:final success):
      showPinChanged(success);
    default:
      break;
  }
});

await eid.start();
await eid.startAuthentication(tcTokenUrl: Uri.parse(tcTokenUrl));
```

The `showXyz` functions and `openResultUrl` are placeholders for your own screens and your own flow. At the end of an authentication, the SDK returns an address in `result.url` that the app is supposed to call, both on success and on failure: this is how the service learns the result. `tcTokenUrl` is the address supplied by the counterpart's eID server. If it arrives as an eID client link (`…/eID-Client?tcTokenURL=…`) from a web flow, `tcTokenUrlFromEidClientLink(Uri)` extracts it and returns `null` if the link does not match or the address does not start with `https`.

To clean up, call `await eid.stop()` and then `eid.dispose()`. Further options:

- `startChangePin()` starts a PIN change (also for the five-digit transport PIN).
- `setAccessRights(...)` restricts the optional access rights, `getCertificate()` returns the counterpart's certificate.
- `rawMessages` delivers every SDK message unchanged, `sendRaw(map)` sends a command that the typed API does not know yet.
- `logger:` in the constructor logs commands and messages, see below.

### The NFC dialog on iOS and `interrupt()`

On iOS, the system shows its own NFC dialog while the SDK reads the card. According to the SDK documentation, the SDK does not close this dialog by itself when it asks for a PIN, CAN, PUK or new PIN (`PinRequested`, `CanRequested`, `PukRequested`, `NewPinRequested`). The app must then close it with `eid.interrupt()` before it shows its input screen; otherwise the dialog stays on top of that screen. On Android, `interrupt()` sends nothing, so the call can stay in the code for both platforms.

`interrupt()` is allowed only directly after one of these four events. At any other time, for example during `InsertCardRequested`, the SDK responds with the event `BadState`.

This is confirmed on an iPhone 16 Pro with iOS 27.2.1: the dialog stays open after `PinRequested`, and the app cannot be operated underneath it. If the user closes the dialog with its own button, the SDK aborts the flow and reports `AuthenticationCompleted` with `reason: User_Cancelled`.

### Testing the app without a device

`package:flutter_ausweisapp/testing.dart` contains `FakeAusweisAppTransport`. With `AusweisApp(transport: fake)`, you can test your own screens in widget tests, without the SDK and without a device.

## Android setup

1. **minSdk 28.** The SDK needs minSdk 28. Set `minSdk = 28` (or higher) in the app's `android/app/build.gradle.kts`.
2. **Adapt your own `Application` class.** The SDK runs in a separate process whose name ends in `ausweisapp2_service`, and it creates the app's `Application` class a second time there. If your app has its own `Application` class with initializations (for example Firebase), it must skip them in this process:

   ```kotlin
   class MyApp : Application() {
       override fun onCreate() {
           super.onCreate()
           if (Application.getProcessName().endsWith("ausweisapp2_service")) return
           // One-time initialization of the app, for example Firebase.
       }
   }
   ```

   Without your own `Application` class, there is nothing to do.
3. **Devices.** The SDK supports only Android devices with extended-length NFC. On other devices, the ID card cannot be read.

The plugin binds the SDK service itself. The permission `android.permission.NFC` and the service reach the app through the SDK's Android package. The plugin itself switches the NFC reader mode on and off while the SDK is running and the activity is in the foreground; your app needs no native code of its own for this.

## iOS setup

1. **Enable Swift Package Manager.** On iOS, the plugin supports only Swift Package Manager (there is no podspec). Enable it in the app's `pubspec.yaml`, without changing the global Flutter configuration:

   ```yaml
   flutter:
     config:
       enable-swift-package-manager: true
   ```

   Flutter keeps integrating plugins of your app that do not offer a Swift package yet through CocoaPods. The switch does not have to happen in one step.
2. **Minimum version iOS 17.0.** Set the app's deployment target to at least 17.0.
3. **NFC entitlement.** The app needs the entry `com.apple.developer.nfc.readersession.formats` with the value `TAG` in its `Runner.entitlements`. For this, the capability "Near Field Communication Tag Reading" must be enabled for the app identifier in the Apple developer account.
4. **Two entries in the `Info.plist`.**

   ```xml
   <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
   <array>
     <string>E80704007F00070302</string>
   </array>
   <key>NFCReaderUsageDescription</key>
   <string>Die App liest per NFC Ihren Personalausweis, um Sie online auszuweisen.</string>
   ```

   The text under `NFCReaderUsageDescription` is shown to the user; adapt it to your app.

Known build limitation: with Flutter 3.41.7 and Xcode 27.2, `flutter build ios --simulator` fails for every app, even an empty one (observed on November 24, 2026; Flutter's call to `lipo -verify_arch` is rejected). Builds for a specific simulator or a device work, for example `flutter run -d <id>`.

**Multiple Flutter engines.** On iOS, the SDK exists once per process. If a second engine calls `start()`, it takes over the messages, and the first engine does not learn about it. Use the plugin from a single engine.

## Platform differences

| Feature | Android | iOS |
| --- | --- | --- |
| `userInfoMessages` in `startAuthentication` and `startChangePin` (texts of the NFC dialog) | no effect | takes effect |
| `interrupt()` (closes the NFC dialog) | sends nothing | takes effect |
| Event `Disconnected` (connection to the SDK lost) | is reported | is not reported |
| NFC dialog | – | shown by iOS itself; its texts come through `userInfoMessages` |
| ID card is pulled away while it is being read | not yet tested on a device | no `Paused`; the flow ends with an unsuccessful `AuthenticationCompleted`, and the login has to start over (observed on an iPhone) |

Android specifics:

- After `stop()`, the SDK terminates its own process. A `start()` directly afterwards waits up to 3 seconds for this process to end and only then binds again. Otherwise, Android would restart the service only after a delay of about 10 seconds.
- Known limitation: if the plugin is attached to an activity that is already in the foreground (add-to-app with a `FlutterFragment` inserted later), the NFC reader mode switches on only after the next pause and resume. This does not occur with a regular `FlutterActivity`.

## Lifecycle and errors

- **Only one `AusweisApp` at a time.** The SDK exists once per process. Two objects working at the same time are not supported. Events always go to the object that called `start()` last. The usual switch between two screens works nonetheless: if the new screen has already called `start()` on its `AusweisApp` when the old screen calls `dispose()`, the old object does not stop the new one's SDK.
- `start()` has a timeout of 15 seconds by default and throws `AusweisAppStartException` (codes `start_failed`, `timeout`, `api_level`). The first step of `start()` sets API level 3.
- `stop()` waits at most 15 seconds and otherwise throws `AusweisAppTransportException` (code `timeout`). If a stop is still in progress, for example after a failed `start()`, `stop()` waits for it.
- `dispose()` triggers the stop but does not wait for it. This is meant for `State.dispose()`, which cannot wait. A new `AusweisApp` that starts afterwards waits by itself until this stop has finished.
- Commands while the SDK is not running throw `AusweisAppNotRunningException`. If the SDK itself reports in response to a command that it is not running, the command also throws `AusweisAppNotRunningException`; `isRunning` is then `false`, and `start()` restarts the SDK. Transport errors while sending throw `AusweisAppTransportException`.
- Error messages from the SDK (`BAD_STATE`, `INTERNAL_ERROR`, `INVALID`, `UNKNOWN_COMMAND`) arrive as events: `BadState`, `InternalError`, `InvalidCommand`, `UnknownCommand`. Messages that the plugin does not know arrive as `UnknownMessageReceived` with the raw JSON.
- A flow that fails for a functional reason (wrong PIN, cancellation, blocked card) is **not** an exception but a normal event, for example `AuthenticationCompleted` with a result whose `isSuccess` is false.
- After `stop()` in the middle of a flow, no `AuthenticationCompleted` and no `ChangePinCompleted` arrives any more (observed on an iPhone). Do not wait for a completion event after `stop()`.

## Handling PIN, CAN and PUK

- The plugin never writes commands containing secrets to the log. Logging of commands and messages is off by default (`logger:` in the constructor of `AusweisApp`). If you enable it, the plugin replaces PIN, CAN, PUK and the values of HTTP headers with `***`.
- The plugin does not redact addresses in the log: the `tcTokenURL` in the `RUN_AUTH` command and the result address in the `AUTH` message appear in plain text. Both usually contain a session token. Logging is therefore intended for development only; do not enable it in shipped apps.
- On Android, the plugin overwrites the character array with zeros after sending.
- Known limitation: in Flutter, the input is captured as a Dart string and cannot be deliberately erased from memory there. This applies to every Flutter approach.

## Simulator card

The SDK ships a virtual card. It sits in a built-in reader named `Simulator` and is inserted with `eid.setCard('Simulator')`, for example when `InsertCardRequested` arrives. It works only against test environments, such as the Governikus test service `https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request`, and for that, `startAuthentication` needs the parameter `developerMode: true`.

The `Simulator` reader reports itself as a reader with its own keypad. PIN, CAN, PUK and new PIN must therefore be sent **without a value**: `eid.setPin(null)`. With a value, the SDK rejects the input every time.

The simulator card also runs in the emulator and in the simulator, but it needs network access to the test service.

**Real ID cards need a production service.** At the Governikus test service, a real ID card is read and the PIN is accepted; the flow then ends with the reason `Process_Certificates_From_Eac2_Cvc_Chain_Missing`, because the test service uses test certificates. Conversely, the SDK rejects a production service as long as `developerMode: true` is set, according to the SDK documentation with the reason `Pre_Verification_No_Test_Environment`. For a production service, leave `developerMode` at its default `false`.

## Development

Tests in this repository:

- `flutter test` in the root directory runs the unit tests, without a device.
- `flutter test` in the `example/` directory runs the widget tests of the example app.
- `flutter test integration_test -d <device>` in the `example/` directory runs the integration tests on an emulator, simulator or device. The test with the simulator card needs network access to the Governikus test service.

The example app in `example/` is a simple test interface that triggers all flows. How to start it on a device is described in `example/README.md`; the checklist for real devices is in `docs/device-test.md`.

**Hot restart.** After a hot restart, the native SDK keeps running. `start()` then returns immediately. A running flow remains active and can be ended with `cancel()`.

## SDK update

The SDK version appears in two places: in `android/build.gradle.kts` (`com.governikus:ausweisapp:2.6.3`) and in `ios/flutter_ausweisapp/Package.swift` (`exact: "2.6.3"`). Before raising it, read the SDK changelog at `AusweisApp-community/docs/sdk/changelog.rst`, because the plugin implements the protocol itself and has to follow changes there. The plugin sets API level 3 at startup so that a newer SDK does not silently change the behavior.

## Scope: the app's login flow

This plugin only handles card access and accepts a `tcTokenURL`. How the app obtains this address from its login flow (for example from an identity provider such as Keycloak with a connected BundID account) and then completes the login is up to the app. Whether the respective service permits this route must be clarified with its operator. Independently of that, the plugin can be developed entirely against the Governikus test service.

## License

Copyright © 2026 Open Reply GmbH.

The plugin is licensed under the European Union Public Licence (EUPL), version 1.2. The license text is in the file `LICENSE`.

The bundled Governikus AusweisApp SDK is also licensed under the EUPL 1.2. Whoever ships an app with this plugin distributes the SDK along with it. What to observe in that case is described in `NOTICE.md`.
