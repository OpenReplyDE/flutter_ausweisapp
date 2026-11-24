import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';

/// A model of the native plugin side.
///
/// Like the platform thread, it handles calls in the order they arrive and
/// answers each one in a later event-loop turn. Messages go to the event sink
/// that the last `listen` set; `cancel` clears it, as the plugins do.
class NativeModel {
  NativeModel(this.delay);

  /// How long each answer takes.
  final Duration delay;

  final List<String> calls = [];
  MockStreamHandlerEventSink? sink;
  bool running = false;

  /// Counts stops, so that a start or a message can tell it was overtaken.
  int _stops = 0;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'start':
        final stops = _stops;
        await Future<void>.delayed(delay);
        if (_stops != stops) {
          throw PlatformException(
            code: 'start_failed',
            message: 'The start was cancelled by stop.',
          );
        }
        running = true;
        return null;
      case 'stop':
        _stops++;
        running = false;
        await Future<void>.delayed(delay);
        return null;
      case 'send':
        if (!running) {
          throw PlatformException(
            code: 'not_running',
            message: 'The AusweisApp SDK is not running.',
          );
        }
        _answer((jsonDecode(call.arguments as String) as Map).cast());
        return null;
      case 'isRunning':
        return running;
    }
    return null;
  }

  void _answer(Map<String, Object?> command) {
    final Map<String, Object?> message;
    switch (command['cmd']) {
      case 'SET_API_LEVEL':
        message = {
          'msg': 'API_LEVEL',
          'available': [1, 2, 3],
          'current': command['level'],
        };
      case 'GET_INFO':
        message = {
          'msg': 'INFO',
          'VersionInfo': {'Implementation-Version': '2.6.3'},
        };
      default:
        return;
    }
    final stops = _stops;
    Timer(delay, () {
      // The SDK sends nothing once it was stopped.
      if (_stops != stops) return;
      sink?.success({'type': 'message', 'json': jsonEncode(message)});
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('flutter_ausweisapp/methods');
  const events = EventChannel('flutter_ausweisapp/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Well below the 15 s default, so that a lost message fails fast.
  const startTimeout = Duration(seconds: 2);

  for (final delay in const [
    Duration(milliseconds: 1),
    Duration(milliseconds: 200),
  ]) {
    group('with native answers after ${delay.inMilliseconds} ms', () {
      late NativeModel native;

      setUp(() {
        native = NativeModel(delay);
        messenger.setMockMethodCallHandler(methods, native.handle);
        messenger.setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (arguments, sink) {
              native.calls.add('listen');
              native.sink = sink;
            },
            onCancel: (arguments) {
              native.calls.add('cancel');
              native.sink = null;
            },
          ),
        );
      });

      tearDown(() {
        messenger.setMockMethodCallHandler(methods, null);
        messenger.setMockStreamHandler(events, null);
      });

      /// A new controller on the default transport. It is stopped after the
      /// test, so that the next test finds the channel idle.
      AusweisApp create() {
        final app = AusweisApp();
        addTearDown(() async {
          await app.stop();
          await app.dispose();
        });
        return app;
      }

      Future<InfoReceived> nextInfo(AusweisApp app) => app.events
          .where((e) => e is InfoReceived)
          .cast<InfoReceived>()
          .first
          .timeout(startTimeout);

      test('a new instance starts and receives messages after await '
          'dispose() of the previous one', () async {
        final a = create();
        await a.start(timeout: startTimeout);
        await a.dispose();

        final b = create();
        await b.start(timeout: startTimeout);
        final info = nextInfo(b);
        await b.getInfo();
        expect((await info).versionInfo?.implementationVersion, '2.6.3');
        expect(b.isRunning, isTrue);
      });

      test('a new instance starts and receives messages after dispose() of '
          'the previous one without await', () async {
        final a = create();
        await a.start(timeout: startTimeout);
        unawaited(a.dispose());

        final b = create();
        await b.start(timeout: startTimeout);
        final info = nextInfo(b);
        await b.getInfo();
        expect((await info).versionInfo?.implementationVersion, '2.6.3');
        expect(b.isRunning, isTrue);
      });

      test('disposing an older instance that a newer one replaced keeps the '
          'newer one running', () async {
        final a = create();
        await a.start(timeout: startTimeout);
        final b = create();
        await b.start(timeout: startTimeout);

        await a.dispose();
        // Leave time for the stop the old instance might send.
        await Future<void>.delayed(delay * 3);

        final info = nextInfo(b);
        await b.getInfo();
        expect((await info).versionInfo?.implementationVersion, '2.6.3');
        expect(b.isRunning, isTrue);
        expect(native.running, isTrue);
      });
    });
  }
}
