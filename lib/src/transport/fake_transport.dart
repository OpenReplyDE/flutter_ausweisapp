/// In-memory transport for tests.
library;

import 'dart:async';
import 'dart:convert';

import '../errors.dart';
import 'transport.dart';

/// A scriptable [AusweisAppTransport] that never touches native code.
class FakeAusweisAppTransport implements AusweisAppTransport {
  FakeAusweisAppTransport({this.autoApiLevel = true});

  /// Answers `SET_API_LEVEL n` with `API_LEVEL` where `current` is `n`.
  final bool autoApiLevel;

  /// Decoded commands in the order they were sent.
  final List<Map<String, Object?>> sent = [];

  /// When true, [start] does not return until [stop] ends it with
  /// [AusweisAppStartException] (code `start_failed`).
  bool hangOnStart = false;

  /// Thrown by the next [start], then cleared.
  AusweisAppException? startError;

  /// Thrown by the next [send], then cleared.
  AusweisAppException? sendError;

  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast();
  bool _running = false;

  /// Held by starts that [hangOnStart] keeps pending.
  Completer<void>? _pendingStart;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    final error = startError;
    if (error != null) {
      startError = null;
      throw error;
    }
    if (hangOnStart) {
      await (_pendingStart ??= Completer<void>()).future;
    }
    _running = true;
  }

  /// Stops at once. A start that [hangOnStart] keeps pending fails with
  /// [AusweisAppStartException] (code `start_failed`).
  @override
  Future<void> stop() async {
    _running = false;
    final pending = _pendingStart;
    _pendingStart = null;
    pending?.completeError(
      const AusweisAppStartException(
        'start_failed',
        'The start was cancelled by stop.',
      ),
    );
  }

  @override
  Future<bool> isRunning() async => _running;

  @override
  Future<void> send(String json) async {
    if (!_running) throw const AusweisAppNotRunningException();
    final error = sendError;
    if (error != null) {
      sendError = null;
      throw error;
    }
    final command = (jsonDecode(json) as Map).cast<String, Object?>();
    sent.add(command);
    if (autoApiLevel && command['cmd'] == 'SET_API_LEVEL') {
      emit({
        'msg': 'API_LEVEL',
        'available': [1, 2, 3],
        'current': command['level'],
      });
    }
  }

  /// Delivers [message] to listeners, encoded as JSON.
  void emit(Map<String, Object?> message) => emitRaw(jsonEncode(message));

  /// Delivers [text] to listeners unchanged.
  void emitRaw(String text) => _controller.add(TransportMessage(text));

  /// Simulates a lost connection.
  void disconnect() {
    _running = false;
    _controller.add(const TransportDisconnected());
  }
}
