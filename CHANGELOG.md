# Changes

Deutsche Fassung: [CHANGELOG.de.md](CHANGELOG.de.md)

## 0.2.0

Additions for apps that show their own screens. Nothing that existed changes.

- `AusweisAppNfc` (implemented by `MethodChannelAusweisAppNfc`) reports the NFC state of the device as `NfcStatus` (`unsupported`, `disabled`, `available`), without a running SDK. `openSettings()` opens the system's NFC settings on Android; on iOS, which has none, it does nothing and returns `false`.
- `FailureKind` sorts failure codes into `network`, `timeout`, `userCancelled`, `cardConnection` and `other`. It is available as `AuthResult.failureKind`, `ChangePinCompleted.failureKind`, `AusweisAppException.failureKind` and `FailureKind.fromReason`; the raw codes stay unchanged. The assignment follows the list of failure codes in the SDK documentation, which is now part of the repository (`AusweisApp-community/docs/failurecodes/failurecodes.rst`).
- `FakeAusweisAppNfc` in `package:flutter_ausweisapp/testing.dart` replaces the NFC state in tests.
- The example app shows the NFC state, a button to the NFC settings and the failure kind in its log.
- Documented: the SDK's Android package declares NFC as an optional feature, so an app with the plugin stays installable on devices without NFC.

The NFC functions have run on an iOS simulator only. On real devices they are untested on both platforms; see `docs/device-test.md`.

## 0.1.0

First version. The plugin integrates the AusweisApp SDK 2.6.3 into Flutter for Android and iOS and can:

- start and stop the SDK and send all 20 SDK commands as methods, including authentication, PIN change (also transport PIN), PIN, CAN and PUK, viewing and restricting access rights, certificate, status and cancellation,
- deliver all SDK messages as named events in a stream, unknown messages with the raw JSON,
- control the NFC reader mode on Android by itself,
- show the NFC dialog with custom texts on iOS and close it with `interrupt()`,
- read the `tcTokenURL` from an eID client link (`tcTokenUrlFromEidClientLink`),
- log commands and messages on request, with PIN, CAN, PUK and header values replaced by `***`,
- be tested without a device using `FakeAusweisAppTransport` (`package:flutter_ausweisapp/testing.dart`).

The plugin is licensed under the EUPL 1.2.

The Git tag `v0.0.1` marks the same code from before the version number was set to 0.1.0.

On iOS, the plugin has been tested on a real device; on Android, real NFC is still untested; see `docs/device-test.md`.
