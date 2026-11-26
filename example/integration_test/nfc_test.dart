import 'package:flutter/foundation.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const limit = Duration(seconds: 30);
  const nfc = MethodChannelAusweisAppNfc();

  testWidgets('the NFC status is answered while the SDK is stopped', (
    tester,
  ) async {
    final status = await nfc.status().timeout(limit);

    // An emulator and a simulator have no NFC and answer `unsupported`; a
    // device answers with its real state.
    debugPrint('NFC status: ${status.name}');
    expect(NfcStatus.values, contains(status));
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      expect(status, isNot(NfcStatus.disabled));
    }
    expect(await MethodChannelAusweisAppTransport().isRunning(), isFalse);
  });

  testWidgets(
    'openSettings does nothing on iOS and returns false',
    (tester) async {
      expect(await nfc.openSettings().timeout(limit), isFalse);
      // Not run on Android: there the call leaves the app for the settings.
    },
    skip: defaultTargetPlatform != TargetPlatform.iOS,
  );
}
