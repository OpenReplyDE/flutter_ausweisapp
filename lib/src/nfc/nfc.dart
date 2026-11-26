/// The NFC state of the device, independent of the AusweisApp SDK.
library;

/// Whether the device can read an ID card over NFC right now.
enum NfcStatus {
  /// The device has no NFC, or cannot read tags with it.
  unsupported,

  /// The device has NFC, but it is switched off in the system settings.
  /// Reported on Android only; NFC cannot be switched off on iOS.
  disabled,

  /// NFC is there and switched on.
  available,
}

/// Asks the device for its NFC state and opens the NFC settings.
///
/// Works without the SDK: no `AusweisApp` has to exist and none has to be
/// started. The state is read anew on every call; there are no change
/// notifications. After the user comes back from the settings, ask again,
/// for example on `AppLifecycleState.resumed`.
///
/// In tests, pass a `FakeAusweisAppNfc` from
/// `package:flutter_ausweisapp/testing.dart` to the code that would
/// otherwise create a `MethodChannelAusweisAppNfc`.
abstract interface class AusweisAppNfc {
  /// The NFC state of the device at this moment.
  ///
  /// Android: [NfcStatus.unsupported] without an NFC adapter,
  /// [NfcStatus.disabled] while NFC is switched off, else
  /// [NfcStatus.available]. iOS: [NfcStatus.available] if the device can
  /// read tags, else [NfcStatus.unsupported]; never [NfcStatus.disabled].
  Future<NfcStatus> status();

  /// Opens the NFC settings of the system. Returns whether they were opened.
  ///
  /// Android: opens the NFC settings and returns true; returns false if the
  /// device offers no such screen. iOS has no NFC setting: the call does
  /// nothing there and returns false.
  Future<bool> openSettings();
}
