import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('flutter_ausweisapp/methods');
  const events = EventChannel('flutter_ausweisapp/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelAusweisAppTransport transport;
  late List<String> calls;
  late List<Object?> arguments;
  MockStreamHandlerEventSink? sink;
  Future<Object?> Function(MethodCall call)? onCall;

  setUp(() {
    transport = MethodChannelAusweisAppTransport();
    calls = [];
    arguments = [];
    sink = null;
    onCall = null;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      arguments.add(call.arguments);
      return onCall == null ? null : onCall!(call);
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, eventSink) {
          calls.add('listen');
          sink = eventSink;
        },
        onCancel: (arguments) {
          calls.add('cancel');
          sink = null;
        },
      ),
    );
  });

  tearDown(() async {
    await transport.stop().catchError((_) {});
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  Future<Object> captureError(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      return e;
    }
    fail('expected an error');
  }

  test('start subscribes to events before invoking start', () async {
    await transport.start();
    expect(calls, ['listen', 'start']);
  });

  test(
    'sequential start subscribes once and re-invokes idempotent native start',
    () async {
      await transport.start();
      await transport.start();
      expect(calls, ['listen', 'start', 'start']);
    },
  );

  test('concurrent start shares one in-flight native start', () async {
    final gate = Completer<void>();
    onCall = (_) => gate.future.then((_) => null);
    var firstDone = false;
    var secondDone = false;
    final first = transport.start().then((_) => firstDone = true);
    final second = transport.start().then((_) => secondDone = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(firstDone, isFalse);
    expect(secondDone, isFalse);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, ['listen', 'start']);
  });

  test('start after disconnect subscribes and starts again', () async {
    await transport.start();
    final next = transport.events.first;
    sink!.success({'type': 'disconnected'});
    await next;
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['listen', 'start', 'cancel']);
    await transport.start();
    expect(calls, ['listen', 'start', 'cancel', 'listen', 'start']);
  });

  test('event channel error is forwarded as mapped exception', () async {
    await transport.start();
    final errors = <Object>[];
    final sub = transport.events.listen((_) {}, onError: errors.add);
    sink!.error(code: 'weird', message: 'native problem');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(errors, hasLength(1));
    final e = errors.single;
    expect(e, isA<AusweisAppTransportException>());
    expect((e as AusweisAppException).code, 'weird');
    expect(e.message, 'native problem');
  });

  test('stop invokes stop and releases the event subscription', () async {
    await transport.start();
    await transport.stop();
    expect(calls, ['listen', 'start', 'stop', 'cancel']);
  });

  test('failed start releases the event subscription', () async {
    onCall = (_) async =>
        throw PlatformException(code: 'start_failed', message: 'boom');
    await captureError(transport.start);
    expect(calls, ['listen', 'start', 'cancel']);
  });

  test('send passes the JSON string unchanged', () async {
    await transport.start();
    await transport.send('{"cmd":"GET_INFO"}');
    expect(calls.last, 'send');
    expect(arguments.last, '{"cmd":"GET_INFO"}');
  });

  test('message event becomes TransportMessage', () async {
    await transport.start();
    final next = transport.events.first;
    sink!.success({'type': 'message', 'json': '{"msg":"INFO"}'});
    final event = await next;
    expect(event, isA<TransportMessage>());
    expect((event as TransportMessage).json, '{"msg":"INFO"}');
  });

  test('disconnected event becomes TransportDisconnected', () async {
    await transport.start();
    final next = transport.events.first;
    sink!.success({'type': 'disconnected'});
    expect(await next, isA<TransportDisconnected>());
  });

  test('unknown event type is ignored', () async {
    await transport.start();
    final received = <TransportEvent>[];
    final errors = <Object>[];
    final sub = transport.events.listen(received.add, onError: errors.add);
    sink!.success({'type': 'x'});
    sink!.success({'type': 'disconnected'});
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(received, hasLength(1));
    expect(received.single, isA<TransportDisconnected>());
    expect(errors, isEmpty);
  });

  test('isRunning returns the native value', () async {
    onCall = (_) async => true;
    expect(await transport.isRunning(), isTrue);
    onCall = (_) async => false;
    expect(await transport.isRunning(), isFalse);
  });

  test('code not_running maps to AusweisAppNotRunningException', () async {
    await transport.start();
    onCall = (_) async => throw PlatformException(code: 'not_running');
    final e = await captureError(() => transport.send('{}'));
    expect(e, isA<AusweisAppNotRunningException>());
    expect((e as AusweisAppException).code, 'not_running');
  });

  test('code start_failed maps to AusweisAppStartException', () async {
    onCall = (_) async =>
        throw PlatformException(code: 'start_failed', message: 'no service');
    final e = await captureError(transport.start);
    expect(e, isA<AusweisAppStartException>());
    expect((e as AusweisAppException).code, 'start_failed');
    expect(e.message, 'no service');
  });

  test(
    'any other code maps to AusweisAppTransportException with that code',
    () async {
      await transport.start();
      onCall = (_) async =>
          throw PlatformException(code: 'weird', message: 'something');
      final e = await captureError(() => transport.send('{}'));
      expect(e, isA<AusweisAppTransportException>());
      expect((e as AusweisAppException).code, 'weird');
      expect(e.message, 'something');
    },
  );

  test('exception text never contains the command', () async {
    await transport.start();
    onCall = (_) async => throw PlatformException(
      code: 'send_failed',
      message: 'transmit returned false',
    );
    final e = await captureError(
      () => transport.send('{"cmd":"SET_PIN","value":"123456"}'),
    );
    expect(e, isA<AusweisAppTransportException>());
    expect(e.toString(), isNot(contains('123456')));
    expect(e.toString(), contains('send_failed'));
  });

  test('events is a broadcast stream', () {
    expect(transport.events.isBroadcast, isTrue);
  });
}
