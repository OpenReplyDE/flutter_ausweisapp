import 'dart:convert';

import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('start, GET_INFO, stop', (tester) async {
    final eid = AusweisApp();
    final info = eid.events
        .where((e) => e is InfoReceived)
        .cast<InfoReceived>()
        .first;
    await eid.start();
    await eid.getInfo();
    expect((await info).versionInfo!.implementationVersion, '2.6.3');
    await eid.stop();
    expect(eid.isRunning, isFalse);
  });

  testWidgets('native send without start reports not_running', (tester) async {
    final transport = MethodChannelAusweisAppTransport();
    await expectLater(
      transport.send('{"cmd":"GET_INFO"}'),
      throwsA(isA<AusweisAppNotRunningException>()),
    );
  });

  testWidgets('second native start while running succeeds (hot restart)', (
    tester,
  ) async {
    final a = MethodChannelAusweisAppTransport();
    await a.start();
    // A new Dart side while the SDK keeps running.
    final b = MethodChannelAusweisAppTransport();
    final message = b.events.where((e) => e is TransportMessage).first;
    await b.start();
    await b.send('{"cmd":"GET_INFO"}');
    // The new Dart side receives messages.
    await message;
    await b.stop();
    expect(await b.isRunning(), isFalse);
  });

  testWidgets('start after stop works again', (tester) async {
    final transport = MethodChannelAusweisAppTransport();
    await transport.start();
    await transport.stop();
    expect(await transport.isRunning(), isFalse);

    final info = transport.events
        .where((e) => e is TransportMessage)
        .cast<TransportMessage>()
        .map((e) => jsonDecode(e.json))
        .firstWhere((json) => json is Map && json['msg'] == 'INFO');
    await transport.start();
    await transport.send('{"cmd":"GET_INFO"}');
    expect(await info, isA<Map<dynamic, dynamic>>());
    await transport.stop();
    expect(await transport.isRunning(), isFalse);
  });
}
