# Changes

Deutsche Fassung: [CHANGELOG.de.md](CHANGELOG.de.md)

## 0.0.1

First version. The plugin integrates the AusweisApp SDK 2.6.3 into Flutter for Android and iOS and can:

- start and stop the SDK and send all 20 SDK commands as methods, including authentication, PIN change (also transport PIN), PIN, CAN and PUK, viewing and restricting access rights, certificate, status and cancellation,
- deliver all SDK messages as named events in a stream, unknown messages with the raw JSON,
- control the NFC reader mode on Android by itself,
- show the NFC dialog with custom texts on iOS and close it with `interrupt()`,
- read the `tcTokenURL` from an eID client link (`tcTokenUrlFromEidClientLink`),
- log commands and messages on request, with PIN, CAN, PUK and header values replaced by `***`,
- be tested without a device using `FakeAusweisAppTransport` (`package:flutter_ausweisapp/testing.dart`).

The plugin is licensed under the EUPL 1.2.

On iOS, the plugin has been tested on a real device; on Android, real NFC is still untested; see `docs/device-test.md`.
