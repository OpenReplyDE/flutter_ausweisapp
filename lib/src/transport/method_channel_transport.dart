/// Transport over a Flutter MethodChannel and EventChannel.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../errors.dart';
import 'transport.dart';

/// Talks to the native plugin code. Only strings cross the channel.
class MethodChannelAusweisAppTransport implements AusweisAppTransport {
  static const _methods = MethodChannel('flutter_ausweisapp/methods');
  static const _eventChannel = EventChannel('flutter_ausweisapp/events');

  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast();
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    if (_subscription != null) return;
    // Subscribe first so no early message is lost.
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: _onError,
    );
    try {
      await _invoke<void>('start');
    } catch (_) {
      await _release();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _invoke<void>('stop');
    } finally {
      await _release();
    }
  }

  @override
  Future<void> send(String json) => _invoke<void>('send', json);

  @override
  Future<bool> isRunning() async => await _invoke<bool>('isRunning') ?? false;

  Future<void> _release() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'message':
        final json = event['json'];
        if (json is String) _controller.add(TransportMessage(json));
      case 'disconnected':
        _controller.add(const TransportDisconnected());
    }
  }

  void _onError(Object error) {
    _controller.addError(_map(error));
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  AusweisAppException _map(Object error) {
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
