/// Transport over a Flutter MethodChannel and EventChannel.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../errors.dart';
import 'transport.dart';

/// Talks to the native plugin code. Only strings cross the channel.
///
/// The channels and the SDK exist once per process, so every instance shares
/// one event subscription and waits for a stop of any instance before it
/// starts. The instance that started last receives the events. A [stop] of
/// an instance that another instance has started after does not stop the
/// SDK of that newer instance.
class MethodChannelAusweisAppTransport implements AusweisAppTransport {
  static const _methods = MethodChannel('flutter_ausweisapp/methods');
  static const _eventChannel = EventChannel('flutter_ausweisapp/events');

  /// The one subscription to the event channel.
  static StreamSubscription<dynamic>? _subscription;

  /// The instance that started last. It receives the events, and only it may
  /// stop the SDK. Null once the subscription is released.
  static MethodChannelAusweisAppTransport? _owner;

  /// The native stop in flight, of any instance. Every later stop runs after
  /// it, so it always covers all stops in flight.
  static Future<void>? _stopping;

  /// Counts the starts and stops of all instances. A stop or failed start
  /// releases the subscription only if no later start or stop came after it.
  static int _calls = 0;

  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast();
  Future<void>? _starting;

  /// Counts the calls of [stop] on this instance, so that a start that is
  /// still waiting for an earlier stop gives up.
  int _stops = 0;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  Future<void> start() {
    // Concurrent callers share one in-flight start. Native start is itself
    // idempotent, so no "already started" state is kept here.
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final call = ++_calls;
    final stops = _stops;
    try {
      // A stop that is still in flight would end this start natively, and
      // its release would remove this start's event subscription. The last
      // check and the native start run without a gap, so no stop can slip
      // in between.
      for (var stopping = _stopping; stopping != null; stopping = _stopping) {
        try {
          await stopping;
        } on Object {
          // Reported to whoever called that stop.
        }
      }
      if (_stops != stops) {
        throw const AusweisAppStartException(
          'start_failed',
          'The start was cancelled by stop.',
        );
      }
      _owner = this;
      // Subscribe first so no early message is lost.
      _subscription ??= _eventChannel.receiveBroadcastStream().listen(
        _onEvent,
        onError: _onError,
      );
      await _invoke<void>('start');
    } catch (_) {
      if (call == _calls) await _release();
      rethrow;
    }
  }

  /// Stops the SDK, unless another instance has started it after this one;
  /// then it only ends a start of this instance that is still waiting.
  @override
  Future<void> stop() {
    _stops++;
    final owner = _owner;
    if (owner != null && !identical(owner, this)) return Future<void>.value();
    final call = ++_calls;
    final stopping = _stop(_stopping, call);
    _stopping = stopping;
    stopping.whenComplete(() {
      if (identical(_stopping, stopping)) _stopping = null;
    }).ignore();
    return stopping;
  }

  static Future<void> _stop(Future<void>? previous, int call) async {
    if (previous != null) {
      try {
        await previous;
      } on Object {
        // Reported to whoever called that stop.
      }
    }
    try {
      await _invoke<void>('stop');
    } finally {
      if (call == _calls) await _release();
    }
  }

  @override
  Future<void> send(String json) => _invoke<void>('send', json);

  @override
  Future<bool> isRunning() async => await _invoke<bool>('isRunning') ?? false;

  static Future<void> _release() async {
    _owner = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  static void _onEvent(dynamic event) {
    final owner = _owner;
    if (owner == null || event is! Map) return;
    switch (event['type']) {
      case 'message':
        final json = event['json'];
        if (json is String) owner._controller.add(TransportMessage(json));
      case 'disconnected':
        owner._controller.add(const TransportDisconnected());
        // The native side is gone; the next start subscribes again.
        unawaited(_release());
    }
  }

  static void _onError(Object error) {
    _owner?._controller.addError(_map(error));
  }

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  static AusweisAppException _map(Object error) {
    if (error is! PlatformException) {
      return const AusweisAppTransportException(
        'transport_error',
        'Unexpected transport error.',
      );
    }
    final message = error.message ?? '';
    return switch (error.code) {
      'not_running' => const AusweisAppNotRunningException(),
      'start_failed' ||
      'timeout' ||
      'api_level' => AusweisAppStartException(error.code, message),
      _ => AusweisAppTransportException(error.code, message),
    };
  }
}
