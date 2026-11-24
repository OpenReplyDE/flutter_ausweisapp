import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const setApiLevel3 = {'cmd': 'SET_API_LEVEL', 'level': 3};
const short = Duration(milliseconds: 50);

Matcher throwsStart(String code) => throwsA(
  isA<AusweisAppStartException>().having((e) => e.code, 'code', code),
);

final throwsNotRunning = throwsA(isA<AusweisAppNotRunningException>());

/// A fake whose [start] waits for [gate] before it starts.
class GatedTransport extends FakeAusweisAppTransport {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> start() async {
    await gate.future;
    await super.start();
  }
}

/// A fake that never answers SET_API_LEVEL and whose [stop] always fails.
class FailingStopTransport extends FakeAusweisAppTransport {
  FailingStopTransport() : super(autoApiLevel: false);

  int stops = 0;

  @override
  Future<void> stop() async {
    stops++;
    await super.stop();
    throw const AusweisAppTransportException('stop_failed', 'stop failed');
  }
}

/// A fake whose [start] fails with an error that is not a plugin exception.
class CrashingStartTransport extends FakeAusweisAppTransport {
  @override
  Future<void> start() async => throw StateError('no plugin');
}

/// A fake that records calls to [start] and [stop]; [stop] waits for
/// [stopGate] if set.
class RecordingTransport extends FakeAusweisAppTransport {
  final List<String> calls = [];
  Completer<void>? stopGate;

  @override
  Future<void> start() async {
    calls.add('start');
    await super.start();
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    await stopGate?.future;
    await super.stop();
  }
}

/// A fake whose [stop] never completes.
class HangingStopTransport extends FakeAusweisAppTransport {
  HangingStopTransport({super.autoApiLevel});

  int stops = 0;

  @override
  Future<void> stop() {
    stops++;
    return Completer<void>().future;
  }
}

/// Records how a future settles, without awaiting it.
class Outcome {
  Outcome(Future<void> future) {
    future.then<void>(
      (_) => done = true,
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
  }

  bool done = false;
  Object? error;
}

/// A fake whose event stream is driven directly by [controller].
class ScriptedEventsTransport extends FakeAusweisAppTransport {
  final StreamController<TransportEvent> controller =
      StreamController<TransportEvent>.broadcast();

  @override
  Stream<TransportEvent> get events => controller.stream;
}

void main() {
  late FakeAusweisAppTransport fake;
  late AusweisApp eid;

  AusweisApp withTransport(AusweisAppTransport transport) {
    final app = AusweisApp(transport: transport);
    addTearDown(app.dispose);
    return app;
  }

  List<AusweisAppEvent> record(AusweisApp app) {
    final events = <AusweisAppEvent>[];
    final subscription = app.events.listen(events.add);
    addTearDown(subscription.cancel);
    return events;
  }

  setUp(() {
    fake = FakeAusweisAppTransport();
    eid = AusweisApp(transport: fake);
  });

  tearDown(() => eid.dispose());

  test('apiLevel is fixed at 3', () {
    expect(AusweisApp.apiLevel, 3);
  });

  test('events and rawMessages are broadcast streams', () {
    expect(eid.events.isBroadcast, isTrue);
    expect(eid.rawMessages.isBroadcast, isTrue);
  });

  group('start', () {
    test(
      'start sends SET_API_LEVEL 3 and completes on API_LEVEL current 3',
      () async {
        await eid.start();
        expect(fake.sent, [
          {'cmd': 'SET_API_LEVEL', 'level': 3},
        ]);
        expect(eid.isRunning, isTrue);
      },
    );

    test(
      'start fails with code api_level when the SDK does not switch to 3',
      () async {
        final quiet = FakeAusweisAppTransport(autoApiLevel: false);
        final app = withTransport(quiet);
        final starting = app.start();
        await pumpEventQueue();
        expect(quiet.sent, [setApiLevel3]);
        quiet.emit({
          'msg': 'API_LEVEL',
          'error': 'x',
          'available': [1, 2],
          'current': 2,
        });
        await expectLater(starting, throwsStart('api_level'));
        expect(app.isRunning, isFalse);
        expect(await quiet.isRunning(), isFalse);
      },
    );

    test(
      'start times out with code timeout when the transport hangs',
      () async {
        fake.hangOnStart = true;
        await expectLater(eid.start(timeout: short), throwsStart('timeout'));
        expect(eid.isRunning, isFalse);
        expect(fake.sent, isEmpty);
      },
    );

    test(
      'start times out with code timeout when API_LEVEL never arrives',
      () async {
        final quiet = FakeAusweisAppTransport(autoApiLevel: false);
        final app = withTransport(quiet);
        await expectLater(app.start(timeout: short), throwsStart('timeout'));
        expect(quiet.sent, [setApiLevel3]);
        expect(app.isRunning, isFalse);
        expect(await quiet.isRunning(), isFalse);
      },
    );

    test('second start while running sends nothing', () async {
      await eid.start();
      await eid.start();
      expect(fake.sent, hasLength(1));
      expect(eid.isRunning, isTrue);
    });

    test('concurrent start calls share one start', () async {
      final first = eid.start();
      final second = eid.start();
      expect(identical(first, second), isTrue);
      await Future.wait([first, second]);
      expect(fake.sent, hasLength(1));
      expect(eid.isRunning, isTrue);
    });

    test('events between start and API_LEVEL are still delivered', () async {
      final quiet = FakeAusweisAppTransport(autoApiLevel: false);
      final app = withTransport(quiet);
      final events = record(app);
      final starting = app.start();
      await pumpEventQueue();
      quiet.emit({'msg': 'READER', 'name': 'NFC', 'attached': true});
      quiet.emit({
        'msg': 'API_LEVEL',
        'available': [1, 2, 3],
        'current': 3,
      });
      await starting;
      await pumpEventQueue();
      expect(app.isRunning, isTrue);
      expect(events, [
        isA<ReaderChanged>().having((e) => e.reader.name, 'name', 'NFC'),
        isA<ApiLevelReceived>().having((e) => e.current, 'current', 3),
      ]);
    });

    test('start passes on start_failed from the transport', () async {
      fake.startError = const AusweisAppStartException(
        'start_failed',
        'bind failed',
      );
      await expectLater(
        eid.start(),
        throwsA(
          isA<AusweisAppStartException>()
              .having((e) => e.code, 'code', 'start_failed')
              .having((e) => e.message, 'message', 'bind failed'),
        ),
      );
      expect(eid.isRunning, isFalse);
      expect(fake.sent, isEmpty);
    });

    test(
      'start reports other plugin errors of the transport as start_failed',
      () async {
        fake.startError = const AusweisAppTransportException(
          'channel_error',
          'channel broke',
        );
        await expectLater(
          eid.start(),
          throwsA(
            isA<AusweisAppStartException>()
                .having((e) => e.code, 'code', 'start_failed')
                .having((e) => e.message, 'message', 'channel broke'),
          ),
        );
      },
    );

    test(
      'start reports unexpected errors of the transport as start_failed',
      () async {
        final app = withTransport(CrashingStartTransport());
        await expectLater(app.start(), throwsStart('start_failed'));
        expect(app.isRunning, isFalse);
      },
    );

    test('start fails with start_failed and stops the transport when '
        'SET_API_LEVEL cannot be sent', () async {
      fake.sendError = const AusweisAppTransportException('send_failed', 'x');
      await expectLater(eid.start(), throwsStart('start_failed'));
      expect(eid.isRunning, isFalse);
      expect(await fake.isRunning(), isFalse);
    });

    test('a failing transport stop does not replace the start error', () async {
      final transport = FailingStopTransport();
      final app = withTransport(transport);
      await expectLater(app.start(timeout: short), throwsStart('timeout'));
      expect(transport.stops, 1);
      expect(app.isRunning, isFalse);
    });

    test('start can be retried after a failed start', () async {
      fake.startError = const AusweisAppStartException('start_failed', 'x');
      await expectLater(eid.start(), throwsStart('start_failed'));
      await eid.start();
      expect(eid.isRunning, isTrue);
      expect(fake.sent, [setApiLevel3]);
    });

    test('a late API_LEVEL after a timed-out start does not mark the SDK '
        'running', () async {
      final quiet = FakeAusweisAppTransport(autoApiLevel: false);
      final app = withTransport(quiet);
      await expectLater(app.start(timeout: short), throwsStart('timeout'));
      quiet.emit({
        'msg': 'API_LEVEL',
        'available': [1, 2, 3],
        'current': 3,
      });
      await pumpEventQueue();
      expect(app.isRunning, isFalse);
    });

    test('an API_LEVEL before SET_API_LEVEL was sent does not complete the '
        'start', () async {
      final gated = GatedTransport();
      final app = withTransport(gated);
      final starting = app.start();
      gated.emit({
        'msg': 'API_LEVEL',
        'available': [1, 2, 3],
        'current': 3,
      });
      await pumpEventQueue();
      expect(app.isRunning, isFalse);
      gated.gate.complete();
      await starting;
      expect(app.isRunning, isTrue);
      expect(gated.sent, [setApiLevel3]);
    });

    test(
      'a transport start that finishes after the timeout sends nothing',
      () async {
        final gated = GatedTransport();
        final app = withTransport(gated);
        await expectLater(app.start(timeout: short), throwsStart('timeout'));
        gated.gate.complete();
        await pumpEventQueue();
        expect(gated.sent, isEmpty);
        expect(app.isRunning, isFalse);
      },
    );

    test(
      'stop during start fails the pending start and stops the transport',
      () async {
        fake.hangOnStart = true;
        final starting = eid.start();
        await eid.stop();
        await expectLater(starting, throwsStart('start_failed'));
        expect(eid.isRunning, isFalse);
        expect(await fake.isRunning(), isFalse);
      },
    );

    test('stop while waiting for API_LEVEL fails the start and a late '
        'API_LEVEL is ignored', () async {
      final quiet = FakeAusweisAppTransport(autoApiLevel: false);
      final app = withTransport(quiet);
      final starting = app.start();
      await pumpEventQueue();
      await app.stop();
      await expectLater(starting, throwsStart('start_failed'));
      expect(await quiet.isRunning(), isFalse);
      quiet.emit({
        'msg': 'API_LEVEL',
        'available': [1, 2, 3],
        'current': 3,
      });
      await pumpEventQueue();
      expect(app.isRunning, isFalse);
    });

    test('disconnect during start fails the start without waiting for the '
        'timeout', () async {
      final quiet = FakeAusweisAppTransport(autoApiLevel: false);
      final app = withTransport(quiet);
      final events = record(app);
      final starting = app.start(timeout: const Duration(seconds: 5));
      await pumpEventQueue();
      quiet.disconnect();
      await expectLater(starting, throwsStart('start_failed'));
      await pumpEventQueue();
      expect(events, [isA<Disconnected>()]);
      expect(app.isRunning, isFalse);
    });

    test('start works again after a disconnect', () async {
      await eid.start();
      fake.disconnect();
      await pumpEventQueue();
      expect(eid.isRunning, isFalse);
      await eid.start();
      expect(eid.isRunning, isTrue);
      expect(fake.sent, [setApiLevel3, setApiLevel3]);
    });
  });

  group('stop', () {
    test('stop stops the transport', () async {
      await eid.start();
      await eid.stop();
      expect(eid.isRunning, isFalse);
      expect(await fake.isRunning(), isFalse);
    });

    test('stop when not running does not touch the transport', () async {
      final transport = FailingStopTransport();
      final app = withTransport(transport);
      await app.stop();
      expect(transport.stops, 0);
      expect(app.isRunning, isFalse);
    });

    test('start works again after stop', () async {
      await eid.start();
      await eid.stop();
      await eid.start();
      expect(eid.isRunning, isTrue);
      expect(fake.sent, [setApiLevel3, setApiLevel3]);
    });

    test(
      'start waits for a pending stop before starting the transport',
      () async {
        final transport = RecordingTransport();
        final app = withTransport(transport);
        await app.start();
        final gate = transport.stopGate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        final stopping = app.stop();
        final starting = app.start();
        await pumpEventQueue();
        expect(transport.calls, ['start', 'stop']);
        gate.complete();
        await stopping;
        await starting;
        expect(transport.calls, ['start', 'stop', 'start']);
        expect(app.isRunning, isTrue);
      },
    );
  });

  group('commands', () {
    test('command before start throws AusweisAppNotRunningException', () async {
      // The transport accepts commands, so only AusweisApp can refuse them.
      await fake.start();
      await expectLater(eid.getInfo(), throwsNotRunning);
      await expectLater(eid.send(const GetInfo()), throwsNotRunning);
      await expectLater(eid.sendRaw({'cmd': 'GET_INFO'}), throwsNotRunning);
      expect(fake.sent, isEmpty);
    });

    test('command after stop throws AusweisAppNotRunningException', () async {
      await eid.start();
      await eid.stop();
      await fake.start();
      await expectLater(eid.getStatus(), throwsNotRunning);
      expect(fake.sent, [setApiLevel3]);
    });

    test('disconnect emits Disconnected and later commands throw', () async {
      await eid.start();
      final next = eid.events.first;
      fake.disconnect();
      expect(await next, isA<Disconnected>());
      expect(eid.isRunning, isFalse);
      await fake.start();
      await expectLater(eid.getInfo(), throwsNotRunning);
      expect(fake.sent, [setApiLevel3]);
    });

    test('send serializes a typed command', () async {
      await eid.start();
      await eid.send(const GetReader('NFC'));
      expect(fake.sent.last, {'cmd': 'GET_READER', 'name': 'NFC'});
    });

    test('sendRaw sends the map unchanged', () async {
      await eid.start();
      await eid.sendRaw({'cmd': 'FUTURE_CMD', 'x': 1});
      expect(fake.sent.last, {'cmd': 'FUTURE_CMD', 'x': 1});
    });

    test('send errors of the transport reach the caller', () async {
      await eid.start();
      fake.sendError = const AusweisAppTransportException('send_failed', 'x');
      await expectLater(
        eid.accept(),
        throwsA(
          isA<AusweisAppTransportException>().having(
            (e) => e.code,
            'code',
            'send_failed',
          ),
        ),
      );
      expect(eid.isRunning, isTrue);
    });

    test('interrupt sends INTERRUPT on iOS and nothing on Android', () async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await eid.start();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await eid.interrupt();
      expect(fake.sent, [setApiLevel3]);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await eid.interrupt();
      expect(fake.sent, [
        setApiLevel3,
        {'cmd': 'INTERRUPT'},
      ]);
    });

    test('interrupt before start throws on Android too', () async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await expectLater(eid.interrupt(), throwsNotRunning);
    });
  });

  group('typed methods send exactly their command', () {
    final demo = Uri.parse('https://test.governikus-eid.de/DEMO');
    final cases =
        <(String, Future<void> Function(AusweisApp), Map<String, Object?>)>[
          ('getInfo sends GET_INFO', (a) => a.getInfo(), {'cmd': 'GET_INFO'}),
          (
            'getStatus sends GET_STATUS',
            (a) => a.getStatus(),
            {'cmd': 'GET_STATUS'},
          ),
          (
            'getApiLevel sends GET_API_LEVEL',
            (a) => a.getApiLevel(),
            {'cmd': 'GET_API_LEVEL'},
          ),
          (
            'setApiLevel sends SET_API_LEVEL with the level',
            (a) => a.setApiLevel(2),
            {'cmd': 'SET_API_LEVEL', 'level': 2},
          ),
          (
            'getReader sends GET_READER with the name',
            (a) => a.getReader('NFC'),
            {'cmd': 'GET_READER', 'name': 'NFC'},
          ),
          (
            'getReaderList sends GET_READER_LIST',
            (a) => a.getReaderList(),
            {'cmd': 'GET_READER_LIST'},
          ),
          (
            'startAuthentication sends RUN_AUTH with defaults',
            (a) => a.startAuthentication(tcTokenUrl: demo),
            {
              'cmd': 'RUN_AUTH',
              'tcTokenURL': 'https://test.governikus-eid.de/DEMO',
              'developerMode': false,
              'status': true,
            },
          ),
          (
            'startAuthentication sends RUN_AUTH with headers, developerMode, '
                'status and messages',
            (a) => a.startAuthentication(
              tcTokenUrl: demo,
              headers: const {'Authorization': 'Bearer t'},
              developerMode: true,
              status: false,
              userInfoMessages: const UserInfoMessages(sessionStarted: 'a'),
            ),
            {
              'cmd': 'RUN_AUTH',
              'tcTokenURL': 'https://test.governikus-eid.de/DEMO',
              'header': {'Authorization': 'Bearer t'},
              'developerMode': true,
              'status': false,
              'messages': {'sessionStarted': 'a'},
            },
          ),
          (
            'startChangePin sends RUN_CHANGE_PIN with defaults',
            (a) => a.startChangePin(),
            {'cmd': 'RUN_CHANGE_PIN', 'status': true},
          ),
          (
            'startChangePin sends RUN_CHANGE_PIN with status and messages',
            (a) => a.startChangePin(
              status: false,
              userInfoMessages: const UserInfoMessages(sessionFailed: 'x'),
            ),
            {
              'cmd': 'RUN_CHANGE_PIN',
              'status': false,
              'messages': {'sessionFailed': 'x'},
            },
          ),
          (
            'getAccessRights sends GET_ACCESS_RIGHTS',
            (a) => a.getAccessRights(),
            {'cmd': 'GET_ACCESS_RIGHTS'},
          ),
          (
            'setAccessRights sends SET_ACCESS_RIGHTS with the chat',
            (a) => a.setAccessRights(['GivenNames']),
            {
              'cmd': 'SET_ACCESS_RIGHTS',
              'chat': ['GivenNames'],
            },
          ),
          (
            'setCard sends SET_CARD with the reader name',
            (a) => a.setCard('Simulator'),
            {'cmd': 'SET_CARD', 'name': 'Simulator'},
          ),
          (
            'setCard sends SET_CARD with simulator data',
            (a) => a.setCard(
              'Simulator',
              simulator: const SimulatorData(
                files: [
                  SimulatorFile(
                    fileId: '0101',
                    shortFileId: '01',
                    content: '61',
                  ),
                ],
              ),
            ),
            {
              'cmd': 'SET_CARD',
              'name': 'Simulator',
              'simulator': {
                'files': [
                  {'fileId': '0101', 'shortFileId': '01', 'content': '61'},
                ],
              },
            },
          ),
          (
            'continueWorkflow sends CONTINUE',
            (a) => a.continueWorkflow(),
            {'cmd': 'CONTINUE'},
          ),
          (
            'getCertificate sends GET_CERTIFICATE',
            (a) => a.getCertificate(),
            {'cmd': 'GET_CERTIFICATE'},
          ),
          ('cancel sends CANCEL', (a) => a.cancel(), {'cmd': 'CANCEL'}),
          ('accept sends ACCEPT', (a) => a.accept(), {'cmd': 'ACCEPT'}),
          (
            'setPin sends SET_PIN with the value',
            (a) => a.setPin('123456'),
            {'cmd': 'SET_PIN', 'value': '123456'},
          ),
          (
            'setPin with null sends SET_PIN without value',
            (a) => a.setPin(null),
            {'cmd': 'SET_PIN'},
          ),
          (
            'setNewPin sends SET_NEW_PIN with the value',
            (a) => a.setNewPin('654321'),
            {'cmd': 'SET_NEW_PIN', 'value': '654321'},
          ),
          (
            'setCan sends SET_CAN with the value',
            (a) => a.setCan('123456'),
            {'cmd': 'SET_CAN', 'value': '123456'},
          ),
          (
            'setPuk sends SET_PUK with the value',
            (a) => a.setPuk('1234567890'),
            {'cmd': 'SET_PUK', 'value': '1234567890'},
          ),
        ];

    for (final (name, call, json) in cases) {
      test(name, () async {
        await eid.start();
        await call(eid);
        expect(fake.sent, [setApiLevel3, json]);
      });
    }
  });

  group('messages', () {
    test('garbage from the transport becomes UnknownMessageReceived and the '
        'stream continues', () async {
      final events = record(eid);
      fake.emitRaw('not json');
      fake.emit({'msg': 'INSERT_CARD'});
      await pumpEventQueue();
      expect(events, [
        isA<UnknownMessageReceived>().having((e) => e.raw, 'raw', 'not json'),
        isA<InsertCardRequested>(),
      ]);
    });

    test(
      'empty, non-object and msg-less input become UnknownMessageReceived',
      () async {
        final events = record(eid);
        for (final raw in ['', '[1]', '{"x":1}', '{"msg":"READER"}']) {
          fake.emitRaw(raw);
        }
        fake.emit({'msg': 'INSERT_CARD'});
        await pumpEventQueue();
        expect(events, [
          isA<UnknownMessageReceived>().having((e) => e.raw, 'raw', ''),
          isA<UnknownMessageReceived>().having((e) => e.raw, 'raw', '[1]'),
          isA<UnknownMessageReceived>().having((e) => e.raw, 'raw', '{"x":1}'),
          isA<UnknownMessageReceived>().having(
            (e) => e.raw,
            'raw',
            '{"msg":"READER"}',
          ),
          isA<InsertCardRequested>(),
        ]);
      },
    );

    test('rawMessages delivers every message as received', () async {
      final raw = <String>[];
      final subscription = eid.rawMessages.listen(raw.add);
      addTearDown(subscription.cancel);
      await eid.start();
      fake.emitRaw('not json');
      fake.emitRaw('{"msg": "INSERT_CARD"}');
      await pumpEventQueue();
      expect(raw, [
        '{"msg":"API_LEVEL","available":[1,2,3],"current":3}',
        'not json',
        '{"msg": "INSERT_CARD"}',
      ]);
    });

    test(
      'transport stream errors reach events and the stream continues',
      () async {
        final transport = ScriptedEventsTransport();
        final app = withTransport(transport);
        final errors = <Object>[];
        final events = <AusweisAppEvent>[];
        final subscription = app.events.listen(events.add, onError: errors.add);
        addTearDown(subscription.cancel);
        transport.controller.addError(
          const AusweisAppTransportException('event_error', 'boom'),
        );
        transport.controller.add(
          const TransportMessage('{"msg":"INSERT_CARD"}'),
        );
        await pumpEventQueue();
        expect(errors, [isA<AusweisAppTransportException>()]);
        expect(events, [isA<InsertCardRequested>()]);
      },
    );
  });

  group('dispose', () {
    test('dispose closes events and rawMessages', () async {
      final eventsDone = expectLater(eid.events, emitsDone);
      final rawDone = expectLater(eid.rawMessages, emitsDone);
      await eid.dispose();
      await eventsDone;
      await rawDone;
    });

    test('dispose stops a running SDK', () async {
      await eid.start();
      await eid.dispose();
      expect(eid.isRunning, isFalse);
      expect(await fake.isRunning(), isFalse);
    });

    test('dispose during start fails the start', () async {
      fake.hangOnStart = true;
      final starting = eid.start();
      await eid.dispose();
      await expectLater(starting, throwsStart('start_failed'));
    });

    test('dispose twice is harmless', () async {
      await eid.dispose();
      await eid.dispose();
    });

    test('messages after dispose are dropped', () async {
      await eid.dispose();
      fake.emit({'msg': 'INSERT_CARD'});
      fake.disconnect();
      await pumpEventQueue();
    });

    test('start after dispose throws StateError', () async {
      await eid.dispose();
      await expectLater(eid.start(), throwsStateError);
    });
  });

  group('hanging transport stop', () {
    // A future that does not settle within [guard] fails the test at once
    // instead of blocking the suite.
    const guard = Duration(seconds: 2);

    AusweisApp withHangingStop(HangingStopTransport transport) {
      final app = AusweisApp(transport: transport);
      addTearDown(() => app.dispose().timeout(guard, onTimeout: () {}));
      return app;
    }

    test('start still times out, and so does a later start, when the '
        'transport stop hangs', () async {
      final transport = HangingStopTransport(autoApiLevel: false);
      final app = withHangingStop(transport);
      await expectLater(
        app.start(timeout: short).timeout(guard),
        throwsStart('timeout'),
      );
      expect(transport.stops, 1);
      expect(app.isRunning, isFalse);
      // The pending stop holds the next transport start back, but only until
      // the deadline of that start.
      await expectLater(
        app.start(timeout: short).timeout(guard),
        throwsStart('timeout'),
      );
      expect(transport.sent, [setApiLevel3]);
      await app.stop().timeout(guard);
      await app.dispose().timeout(guard);
    });

    test('disconnect during start fails the start when the transport stop '
        'hangs', () async {
      final transport = HangingStopTransport(autoApiLevel: false);
      final app = withHangingStop(transport);
      final starting = app.start(timeout: const Duration(seconds: 5));
      await pumpEventQueue();
      transport.disconnect();
      await expectLater(starting.timeout(guard), throwsStart('start_failed'));
      await app.dispose().timeout(guard);
    });

    test('dispose completes at once when the transport stop hangs while '
        'running', () async {
      final transport = HangingStopTransport();
      final app = withHangingStop(transport);
      await app.start();
      var closed = false;
      app.events.listen(null, onDone: () => closed = true);
      await app.dispose().timeout(guard);
      expect(transport.stops, 1);
      expect(app.isRunning, isFalse);
      expect(closed, isTrue);
    });

    test('dispose during start completes at once and fails the start when '
        'the transport stop hangs', () async {
      final transport = HangingStopTransport()..hangOnStart = true;
      final app = withHangingStop(transport);
      final starting = app.start();
      await app.dispose().timeout(guard);
      await expectLater(starting.timeout(guard), throwsStart('start_failed'));
      expect(transport.stops, 1);
    });

    // Fake time: these tests never await a future of the plugin directly,
    // only pump and inspect [Outcome]s.
    testWidgets('stop gives up after 15 s when the transport stop hangs', (
      tester,
    ) async {
      final app = AusweisApp(transport: HangingStopTransport());
      final start = Outcome(app.start());
      await tester.pump();
      expect(start.done, isTrue);
      expect(app.isRunning, isTrue);
      final stop = Outcome(app.stop());
      await tester.pump(const Duration(seconds: 14));
      expect(stop.done, isFalse);
      expect(app.isRunning, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(stop.done, isTrue);
      expect(
        stop.error,
        isA<AusweisAppTransportException>().having(
          (e) => e.code,
          'code',
          'timeout',
        ),
      );
    });

    testWidgets('stop during start fails the start at once and gives up '
        'after 15 s when the transport stop hangs', (tester) async {
      final transport = HangingStopTransport()..hangOnStart = true;
      final app = AusweisApp(transport: transport);
      final start = Outcome(app.start());
      final stop = Outcome(app.stop());
      await tester.pump();
      expect(
        start.error,
        isA<AusweisAppStartException>().having(
          (e) => e.code,
          'code',
          'start_failed',
        ),
      );
      expect(transport.stops, 1);
      expect(stop.done, isFalse);
      await tester.pump(const Duration(seconds: 16));
      expect(
        stop.error,
        isA<AusweisAppTransportException>().having(
          (e) => e.code,
          'code',
          'timeout',
        ),
      );
    });
  });
}
