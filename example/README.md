# flutter_ausweisapp_example

Deutsche Fassung: [README.de.md](README.de.md)

The example app is a simple test interface for the plugin `flutter_ausweisapp`. It triggers all flows (authentication, PIN change, PIN, CAN, PUK, access rights) and shows every plugin event in the "Protokoll" (log) section. You also use it to work through the checklist `../docs/device-test.md` on real devices.

The default is the Governikus test service `https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request` with developer mode switched on.

## Running on an Android device

1. Connect the device over USB and enable developer options and USB debugging. The device must support NFC with extended length.
2. `flutter devices` shows the device ID.
3. In the `example/` directory, run: `flutter run --release -d <device ID>`.

The release variant is signed with the debug key so that it can be started without signing of your own.

## Running on an iPhone

The app is not signed for your Apple team. Before the first launch, set up the following:

1. Open `example/ios/Runner.xcworkspace` in Xcode.
2. In the "Runner" target under "Signing & Capabilities", choose your own team and enter your own, unique bundle ID (the preset one does not belong to you).
3. Add the capability "Near Field Communication Tag Reading" there. It must also be enabled for the app identifier in the Apple developer account. The file `example/ios/Runner/Runner.entitlements` already contains the matching entry `TAG`, and the `Info.plist` the card identifier and the usage text.
4. Connect the iPhone; `flutter devices` shows the device ID. In the `example/` directory, run: `flutter run --release -d <device ID>`.

The iPhone needs iOS 17.0 or newer. The example app enables Swift Package Manager in its `pubspec.yaml` (`flutter` → `config` → `enable-swift-package-manager: true`).

Note on building on November 24, 2026: with Flutter 3.41.7 and Xcode 27.2, `flutter build ios --simulator` fails (Flutter's call to `lipo -verify_arch` is rejected), even for an empty app. Starts on a specific simulator or a device (`flutter run -d <device ID>`) work.

## Usage

1. Tap "SDK starten" (start the SDK); the top of the screen then shows "SDK läuft" (SDK is running).
2. Tap "Authentisierung starten" (start authentication); the events appear in the log.
3. You enter PIN, CAN and PUK in the "Eingabe" (input) field and send them with the four buttons below it.

On iOS, the "PIN, CAN, PUK" section additionally contains the switch "NFC-Dialog bei PIN-, CAN- und PUK-Abfrage automatisch schließen" (automatically close the NFC dialog when a PIN, CAN or PUK is requested). It is on by default and sends `INTERRUPT` as soon as the SDK asks for a PIN, CAN, PUK or new PIN. Otherwise, the system's NFC dialog stays open, and the app cannot be operated underneath it (confirmed on an iPhone 16 Pro with iOS 27.2.1). For more on this, see the section "The NFC dialog on iOS and `interrupt()`" in the plugin's `README.md`.

For each event, the log shows the most important fields, such as `retryCounter` or the result of an authentication. It does not show addresses, because they can contain a session token, but only whether one is present.

With the SDK's simulator card (button "Simulator-Karte einlegen", insert the simulator card), a whole authentication runs without a real ID card. In that case, leave the "Eingabe" field **empty** and tap "als PIN senden" (send as PIN): the simulator reports itself as a reader with its own keypad, and the SDK rejects every PIN that has a value.

## Login in the browser

With the section "Anmeldung im Browser" (login in the browser), you test the flow against a real service, for example a login that redirects to the eID function. At the Governikus test service, authentication succeeds only with a test card; a real ID card needs a production service.

1. Enter the address of the login in the "Login-Adresse" (login address) field.
2. Tap "Im Browser anmelden" (log in in the browser). The app opens the page in an embedded web view.
3. On the page, choose to log in with the eID. As soon as the page wants to start the ID client, the app closes the web view, starts the SDK if necessary and begins the authentication.
4. As usual, tap "Akzeptieren" (accept), hold the ID card against the device and send the PIN.
5. After a successful authentication, the app opens the return address in the same web view. There, the service completes the login. If the authentication fails, the app stays on the log so that the reason is visible and does not open the return address.
6. If the service finally redirects to an app's scheme (for example `de.example.app:/oauth2redirect?code=…`), the example app closes the web view and reports `Weiterleitung an eine App empfangen` (redirect to an app received) in the log, with the scheme and the names of the parameters. It does not show the values. In your app, you intercept this redirect and use it to complete the login.

Login in the browser always starts the authentication without developer mode, regardless of the switch: the SDK immediately rejects a production service in developer mode. The switch applies only to "Authentisierung starten".

The app recognizes the start of the ID client by a link of the form `…/eID-Client?tcTokenURL=https://…`. If a service starts the client in another way, the takeover does not work; whether a particular service permits this route must be clarified with its operator.

The web view is only a helper of the example app. The plugin itself contains no web view; in your app, you build this part yourself.

## Tests

- `flutter test` in the `example/` directory runs the widget tests.
- `flutter test integration_test -d <device ID>` runs the integration tests; the test with the simulator card needs network access to the Governikus test service.
