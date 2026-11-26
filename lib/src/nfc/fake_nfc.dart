/// In-memory NFC state for tests.
library;

import '../errors.dart';
import 'nfc.dart';

/// A scriptable [AusweisAppNfc] that never touches native code.
class FakeAusweisAppNfc implements AusweisAppNfc {
  FakeAusweisAppNfc({
    this.nfcStatus = NfcStatus.available,
    this.openSettingsResult = true,
  });

  /// What [status] reports. Change it to simulate the user switching NFC on
  /// or off.
  NfcStatus nfcStatus;

  /// What [openSettings] returns. Set it to false to simulate a platform
  /// without NFC settings, such as iOS.
  bool openSettingsResult;

  /// How often [openSettings] was called.
  int openSettingsCalls = 0;

  /// Thrown by the next [status], then cleared.
  AusweisAppException? statusError;

  @override
  Future<NfcStatus> status() async {
    final error = statusError;
    if (error != null) {
      statusError = null;
      throw error;
    }
    return nfcStatus;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return openSettingsResult;
  }
}
