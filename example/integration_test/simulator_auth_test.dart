import 'dart:async';

import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full authentication with the built-in simulator card', (
    tester,
  ) async {
    final eid = AusweisApp();
    final done = Completer<AuthenticationCompleted>();
    eid.events.listen((event) {
      switch (event) {
        case AccessRightsRequested():
          eid.accept();
        case InsertCardRequested():
          eid.setCard('Simulator');
        case PinRequested():
          // The simulator reader has a keypad: the SDK rejects a PIN value
          // ("Value cannot be defined") and takes the PIN from the reader.
          eid.setPin(null);
        case AuthenticationCompleted():
          done.complete(event);
        case AuthenticationStartFailed(:final error):
          done.completeError(StateError(error));
        default:
      }
    });
    await eid.start();
    await eid.startAuthentication(
      tcTokenUrl: Uri.parse(
        'https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request',
      ),
      developerMode: true,
    );
    final result = (await done.future.timeout(
      const Duration(seconds: 60),
    )).result;
    expect(result.isSuccess, isTrue);
    expect(result.url, isNotNull);
    await eid.stop();
  });
}
