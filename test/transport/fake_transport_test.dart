import 'dart:async';

import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAusweisAppTransport fake;

  setUp(() => fake = FakeAusweisAppTransport());

  Future<Object> captureError(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      return e;
    }
    fail('expected an error');
  }

  test('isRunning is false before start and true after', () async {
    expect(await fake.isRunning(), isFalse);
    await fake.start();
    expect(await fake.isRunning(), isTrue);
  });

  test('start is idempotent', () async {
    await fake.start();
    await fake.start();
    expect(await fake.isRunning(), isTrue);
  });

  test('send records decoded commands in order', () async {
    await fake.start();
    await fake.send('{"cmd":"GET_INFO"}');
    await fake.send('{"cmd":"GET_STATUS"}');
    expect(fake.sent, [
      {'cmd': 'GET_INFO'},
      {'cmd': 'GET_STATUS'},
    ]);
  });

  test('autoApiLevel answers SET_API_LEVEL with API_LEVEL current n', () async {
    await fake.start();
    final next = fake.events.first;
    await fake.send('{"cmd":"SET_API_LEVEL","level":3}');
    final event = await next as TransportMessage;
    expect(event.json, '{"msg":"API_LEVEL","available":[1,2,3],"current":3}');
  });

  test('autoApiLevel echoes the requested level as current', () async {
    await fake.start();
    final next = fake.events.first;
    await fake.send('{"cmd":"SET_API_LEVEL","level":2}');
    final event = await next as TransportMessage;
    expect(event.json, contains('"current":2'));
  });

  test('autoApiLevel disabled does not answer', () async {
    final quiet = FakeAusweisAppTransport(autoApiLevel: false);
    await quiet.start();
    final received = <TransportEvent>[];
    final sub = quiet.events.listen(received.add);
    await quiet.send('{"cmd":"SET_API_LEVEL","level":3}');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(received, isEmpty);
    expect(quiet.sent, hasLength(1));
  });

  test('send before start throws AusweisAppNotRunningException', () async {
    final e = await captureError(() => fake.send('{"cmd":"GET_INFO"}'));
    expect(e, isA<AusweisAppNotRunningException>());
    expect(fake.sent, isEmpty);
  });

  test('send after stop throws AusweisAppNotRunningException', () async {
    await fake.start();
    await fake.stop();
    final e = await captureError(() => fake.send('{"cmd":"GET_INFO"}'));
    expect(e, isA<AusweisAppNotRunningException>());
  });

  test('emit delivers the message as encoded JSON', () async {
    await fake.start();
    final next = fake.events.first;
    fake.emit({'msg': 'INFO'});
    final event = await next as TransportMessage;
    expect(event.json, '{"msg":"INFO"}');
  });

  test('emitRaw delivers the text unchanged', () async {
    await fake.start();
    final next = fake.events.first;
    fake.emitRaw('not json');
    final event = await next as TransportMessage;
    expect(event.json, 'not json');
  });

  test('disconnect emits TransportDisconnected and stops running', () async {
    await fake.start();
    final next = fake.events.first;
    fake.disconnect();
    expect(await next, isA<TransportDisconnected>());
    expect(await fake.isRunning(), isFalse);
  });

  test('startError is thrown once by the next start', () async {
    fake.startError = const AusweisAppStartException('start_failed', 'nope');
    final e = await captureError(fake.start);
    expect(e, isA<AusweisAppStartException>());
    expect(await fake.isRunning(), isFalse);
    await fake.start();
    expect(await fake.isRunning(), isTrue);
  });

  test('sendError is thrown once by the next send', () async {
    await fake.start();
    fake.sendError = const AusweisAppTransportException('send_failed', 'x');
    final e = await captureError(() => fake.send('{"cmd":"GET_INFO"}'));
    expect(e, isA<AusweisAppTransportException>());
    await fake.send('{"cmd":"GET_INFO"}');
    expect(fake.sent, hasLength(1));
  });

  test('hangOnStart never completes start but stop still works', () async {
    fake.hangOnStart = true;
    var completed = false;
    unawaited(fake.start().then((_) => completed = true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(completed, isFalse);
    expect(await fake.isRunning(), isFalse);
    await fake.stop();
    expect(await fake.isRunning(), isFalse);
  });

  test('events is a broadcast stream', () {
    expect(fake.events.isBroadcast, isTrue);
  });
}
