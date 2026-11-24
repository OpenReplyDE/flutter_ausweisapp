import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Bounds every wait, so that a regression fails instead of hanging.
  const limit = Duration(seconds: 30);

  /// A transport that is stopped after the test, also when the test fails,
  /// so that the next test finds the SDK stopped.
  MethodChannelAusweisAppTransport newTransport() {
    final transport = MethodChannelAusweisAppTransport();
    addTearDown(() => transport.stop().timeout(limit).catchError((_) {}));
    return transport;
  }

  /// A controller on the native transport that is stopped and disposed after
  /// the test, also when the test fails.
  AusweisApp newAusweisApp() {
    final eid = AusweisApp();
    addTearDown(() async {
      await eid.stop().catchError((_) {});
      await eid.dispose();
    });
    return eid;
  }

  Future<InfoReceived> nextInfo(AusweisApp eid) => eid.events
      .where((e) => e is InfoReceived)
      .cast<InfoReceived>()
      .first
      .timeout(limit);

  testWidgets('start, GET_INFO, stop', (tester) async {
    final eid = newAusweisApp();
    final info = nextInfo(eid);
    await eid.start();
    await eid.getInfo();
    expect((await info).versionInfo!.implementationVersion, '2.6.3');
    await eid.stop();
    expect(eid.isRunning, isFalse);
  });

  testWidgets('native send without start reports not_running', (tester) async {
    final transport = newTransport();
    await expectLater(
      transport.send('{"cmd":"GET_INFO"}'),
      throwsA(isA<AusweisAppNotRunningException>()),
    );
  });

  testWidgets('second native start while running succeeds (hot restart)', (
    tester,
  ) async {
    final a = newTransport();
    await a.start();
    // A new Dart side while the SDK keeps running.
    final b = newTransport();
    final message = b.events.where((e) => e is TransportMessage).first;
    await b.start();
    await b.send('{"cmd":"GET_INFO"}');
    // The new Dart side receives messages.
    await message.timeout(limit);
    await b.stop();
    expect(await b.isRunning(), isFalse);
  });

  testWidgets('start after stop works again', (tester) async {
    final transport = newTransport();
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
    expect(await info.timeout(limit), isA<Map<dynamic, dynamic>>());
    await transport.stop();
    expect(await transport.isRunning(), isFalse);
  });

  testWidgets('native stop without a prior start returns', (tester) async {
    // Straight on the channel, so that the call surely reaches the native
    // side.
    const methods = MethodChannel('flutter_ausweisapp/methods');
    await methods.invokeMethod<void>('stop').timeout(limit);
    expect(await methods.invokeMethod<bool>('isRunning'), isFalse);
  });

  testWidgets('native stop during a pending start makes that start fail', (
    tester,
  ) async {
    final transport = newTransport();
    // No stop is in flight, so the native start is sent at once, and the
    // stop right after it.
    final starting = expectLater(
      transport.start(),
      throwsA(
        isA<AusweisAppStartException>().having(
          (e) => e.code,
          'code',
          'start_failed',
        ),
      ),
    );
    await transport.stop().timeout(limit);
    await starting.timeout(limit);
    expect(await transport.isRunning(), isFalse);
  });

  testWidgets('a new AusweisApp starts and receives messages after await '
      'dispose() of the previous one', (tester) async {
    final a = newAusweisApp();
    await a.start();
    await a.dispose();

    final b = newAusweisApp();
    await b.start();
    final info = nextInfo(b);
    await b.getInfo();
    expect((await info).versionInfo!.implementationVersion, '2.6.3');
  });

  testWidgets('a new AusweisApp starts and receives messages after dispose() '
      'of the previous one without await', (tester) async {
    final a = newAusweisApp();
    await a.start();
    unawaited(a.dispose());

    final b = newAusweisApp();
    await b.start();
    final info = nextInfo(b);
    await b.getInfo();
    expect((await info).versionInfo!.implementationVersion, '2.6.3');
  });

  testWidgets('disposing an older AusweisApp that a newer one replaced keeps '
      'the newer one running', (tester) async {
    final a = newAusweisApp();
    await a.start();
    final b = newAusweisApp();
    await b.start();

    await a.dispose();
    // Leave time for a stop the old instance might send.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final info = nextInfo(b);
    await b.getInfo();
    expect((await info).versionInfo!.implementationVersion, '2.6.3');
    expect(b.isRunning, isTrue);
  });
}
