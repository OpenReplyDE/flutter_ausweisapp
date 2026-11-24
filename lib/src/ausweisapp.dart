/// The app-facing controller of the AusweisApp SDK.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import 'errors.dart';
import 'events.dart';
import 'protocol/command.dart';
import 'protocol/message.dart';
import 'redaction.dart';
import 'transport/method_channel_transport.dart';
import 'transport/transport.dart';

/// Controls the AusweisApp SDK.
///
/// Subscribe to [events] before calling [start]. Every SDK command has a
/// method; it returns once the command is handed to the SDK. Answers arrive
/// only as [events].
class AusweisApp {
  /// Pass [logger] to write every command and message as one line: `-> ` and
  /// the command, `<- ` and the message. Off by default. PIN, CAN, PUK and
  /// HTTP header values are replaced by `***`; see [redactCommand]. An error
  /// of [logger] is ignored.
  AusweisApp({AusweisAppTransport? transport, AusweisAppLogger? logger})
    : _logger = logger,
      _transport = transport ?? MethodChannelAusweisAppTransport() {
    _subscription = _transport.events.listen(
      _onTransportEvent,
      onError: _events.addError,
    );
  }

  /// The API level the plugin speaks. [start] switches the SDK to it.
  static const int apiLevel = 3;

  /// How long [stop] waits for the transport to stop.
  static const Duration _stopTimeout = Duration(seconds: 15);

  final AusweisAppTransport _transport;
  final AusweisAppLogger? _logger;
  final StreamController<AusweisAppEvent> _events =
      StreamController<AusweisAppEvent>.broadcast();
  final StreamController<String> _rawMessages =
      StreamController<String>.broadcast();
  late final StreamSubscription<TransportEvent> _subscription;

  _StartAttempt? _attempt;
  Future<void>? _stopping;
  bool _running = false;
  bool _disposed = false;

  /// Events of the SDK, named by meaning. A broadcast stream; subscribe
  /// before [start] to see every event.
  ///
  /// Malformed or unknown messages arrive as [UnknownMessageReceived]. Errors
  /// of the transport itself arrive as stream errors; the stream keeps
  /// running.
  Stream<AusweisAppEvent> get events => _events.stream;

  /// Every message of the SDK as received, before parsing. A broadcast
  /// stream.
  Stream<String> get rawMessages => _rawMessages.stream;

  /// Whether commands can be sent: true once [start] completed, until [stop],
  /// [dispose] or [Disconnected].
  bool get isRunning => _running;

  /// Starts the SDK and switches it to [apiLevel].
  ///
  /// One [timeout] covers both the transport start and the `API_LEVEL`
  /// answer. Concurrent calls share one start; a call while running returns
  /// at once. Throws [AusweisAppStartException] with code `start_failed`,
  /// `timeout` or `api_level`; the transport is stopped again then, and the
  /// next start waits for that stop within its own [timeout].
  /// Throws [StateError] after [dispose].
  Future<void> start({Duration timeout = const Duration(seconds: 15)}) {
    if (_disposed) {
      return Future<void>.error(StateError('AusweisApp was disposed.'));
    }
    if (_running) return Future<void>.value();
    final pending = _attempt;
    if (pending != null) return pending.future;

    final attempt = _StartAttempt();
    _attempt = attempt;
    attempt.timer = Timer(timeout, () {
      unawaited(
        _fail(
          attempt,
          AusweisAppStartException(
            'timeout',
            'The AusweisApp SDK did not start within '
                '${timeout.inMilliseconds} ms.',
          ),
        ),
      );
    });
    unawaited(_runStart(attempt));
    return attempt.future;
  }

  /// Stops the SDK. Does nothing if it is neither running nor starting.
  ///
  /// A pending [start] fails at once with `start_failed`. Waits at most 15 s
  /// for the SDK to stop, then throws [AusweisAppTransportException] with
  /// code `timeout`; a later [start] waits for that stop within its own
  /// timeout.
  Future<void> stop() async {
    final stopping = _beginStop();
    if (stopping == null) return;
    await stopping.timeout(
      _stopTimeout,
      onTimeout: () => throw AusweisAppTransportException(
        'timeout',
        'The AusweisApp SDK did not stop within '
            '${_stopTimeout.inMilliseconds} ms.',
      ),
    );
  }

  /// Stops the SDK and closes [events] and [rawMessages]. Never throws.
  ///
  /// Issues the stop but does not wait for it, so a hanging SDK cannot keep
  /// dispose from completing. A pending [start] fails with `start_failed`.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    unawaited(_beginStop());
    await _subscription.cancel();
    await _events.close();
    await _rawMessages.close();
  }

  /// Sends [command]. Throws [AusweisAppNotRunningException] if the SDK is
  /// not running.
  Future<void> send(Command command) => _send(command.toJson());

  /// Sends [command] unchanged, for commands the typed API does not know.
  /// Throws [AusweisAppNotRunningException] if the SDK is not running.
  Future<void> sendRaw(Map<String, Object?> command) => _send(command);

  /// Asks for [InfoReceived].
  Future<void> getInfo() => send(const GetInfo());

  /// Asks for [StatusChanged].
  Future<void> getStatus() => send(const GetStatus());

  /// Asks for [ApiLevelReceived].
  Future<void> getApiLevel() => send(const GetApiLevel());

  /// Switches the API level. The plugin expects [apiLevel]; [start] sets it.
  Future<void> setApiLevel(int level) => send(SetApiLevel(level));

  /// Asks for [ReaderChanged] of the reader [name].
  Future<void> getReader(String name) => send(GetReader(name));

  /// Asks for [ReaderListReceived].
  Future<void> getReaderList() => send(const GetReaderList());

  /// Starts an authentication against [tcTokenUrl].
  ///
  /// [userInfoMessages] are the texts of the iOS NFC dialog; Android ignores
  /// them.
  Future<void> startAuthentication({
    required Uri tcTokenUrl,
    Map<String, String>? headers,
    bool developerMode = false,
    bool status = true,
    UserInfoMessages? userInfoMessages,
  }) => send(
    RunAuth(
      tcTokenUrl: tcTokenUrl,
      headers: headers ?? const {},
      developerMode: developerMode,
      status: status,
      userInfoMessages: userInfoMessages,
    ),
  );

  /// Starts a PIN change.
  ///
  /// [userInfoMessages] are the texts of the iOS NFC dialog; Android ignores
  /// them.
  Future<void> startChangePin({
    bool status = true,
    UserInfoMessages? userInfoMessages,
  }) => send(RunChangePin(status: status, userInfoMessages: userInfoMessages));

  /// Asks for [AccessRightsRequested].
  Future<void> getAccessRights() => send(const GetAccessRights());

  /// Enables exactly [optionalRights] out of the optional rights.
  Future<void> setAccessRights(List<String> optionalRights) =>
      send(SetAccessRights(optionalRights));

  /// Inserts a card into the reader [readerName], for example the simulator.
  Future<void> setCard(String readerName, {SimulatorData? simulator}) =>
      send(SetCard(readerName, simulator: simulator));

  /// Resumes a workflow after [Paused].
  Future<void> continueWorkflow() => send(const Continue());

  /// Asks for [CertificateReceived].
  Future<void> getCertificate() => send(const GetCertificate());

  /// Cancels the running workflow.
  Future<void> cancel() => send(const Cancel());

  /// Accepts the requested access rights.
  Future<void> accept() => send(const Accept());

  /// Closes the iOS NFC dialog. Sends nothing on other platforms.
  Future<void> interrupt() async {
    if (!_running) throw const AusweisAppNotRunningException();
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await send(const Interrupt());
  }

  /// Answers [PinRequested]. `null` lets a reader with keypad ask for it.
  Future<void> setPin(String? pin) => send(SetPin(pin));

  /// Answers [NewPinRequested]. `null` lets a reader with keypad ask for it.
  Future<void> setNewPin(String? pin) => send(SetNewPin(pin));

  /// Answers [CanRequested]. `null` lets a reader with keypad ask for it.
  Future<void> setCan(String? can) => send(SetCan(can));

  /// Answers [PukRequested]. `null` lets a reader with keypad ask for it.
  Future<void> setPuk(String? puk) => send(SetPuk(puk));

  Future<void> _send(Map<String, Object?> command) async {
    if (!_running) throw const AusweisAppNotRunningException();
    await _transmit(command);
  }

  /// The single path by which commands reach the transport.
  Future<void> _transmit(Map<String, Object?> command) {
    _log(() => '-> ${redactCommand(command)}');
    return _transport.send(jsonEncode(command));
  }

  void _log(String Function() line) {
    final logger = _logger;
    if (logger == null) return;
    try {
      logger(line());
    } on Object {
      // A broken logger must not break the SDK.
    }
  }

  Future<void> _runStart(_StartAttempt attempt) async {
    try {
      // A pending stop must finish before the transport starts again. The
      // attempt's timer bounds this wait.
      final stopping = _stopping;
      if (stopping != null) {
        try {
          await stopping;
        } on Object {
          // Reported to whoever awaited the stop.
        }
      }
      if (attempt.settled) return;
      await _transport.start();
      if (attempt.settled) return;
      attempt.awaitingApiLevel = true;
      await _transmit(const SetApiLevel(apiLevel).toJson());
    } on Object catch (error) {
      unawaited(_fail(attempt, _asStartException(error)));
    }
  }

  void _onTransportEvent(TransportEvent event) {
    switch (event) {
      case TransportMessage(:final json):
        _log(() => '<- $json');
        _rawMessages.add(json);
        final message = Message.parse(json);
        _events.add(AusweisAppEvent.fromMessage(message));
        if (message is ApiLevelMessage) _onApiLevel(message);
      case TransportDisconnected():
        _running = false;
        final attempt = _attempt;
        if (attempt != null) {
          unawaited(
            _fail(
              attempt,
              const AusweisAppStartException(
                'start_failed',
                'The connection to the AusweisApp SDK was lost.',
              ),
            ),
          );
        }
        _events.add(const Disconnected());
    }
  }

  void _onApiLevel(ApiLevelMessage message) {
    final attempt = _attempt;
    if (attempt == null || !attempt.awaitingApiLevel) return;
    if (message.current == apiLevel) {
      _succeed(attempt);
    } else {
      unawaited(
        _fail(
          attempt,
          AusweisAppStartException(
            'api_level',
            'The AusweisApp SDK did not switch to API level $apiLevel '
                '(current: ${message.current}).',
          ),
        ),
      );
    }
  }

  void _succeed(_StartAttempt attempt) {
    if (attempt.settled) return;
    attempt.settled = true;
    attempt.timer.cancel();
    _attempt = null;
    _running = true;
    attempt.completer.complete();
  }

  /// Cancels a pending start or stops a running SDK. Returns the transport
  /// stop, or null if there is nothing to stop. Errors of the returned
  /// future are never reported as unhandled.
  Future<void>? _beginStop() {
    final attempt = _attempt;
    if (attempt != null) {
      // Callers of start() still get the error. It was asked for, so it is
      // not reported as unhandled when none of them listens.
      attempt.future.ignore();
      return _fail(
        attempt,
        const AusweisAppStartException(
          'start_failed',
          'The start was cancelled by stop() or dispose().',
        ),
      );
    }
    if (!_running) return null;
    _running = false;
    return _stopTransport();
  }

  /// Ends [attempt] with [error] at once and stops the transport.
  ///
  /// Does not wait for the stop, so a hanging stop cannot delay the error.
  /// Returns that stop. [stop] waits for it at most 15 s; the next start
  /// waits for it within its own timeout.
  Future<void> _fail(_StartAttempt attempt, AusweisAppStartException error) {
    if (attempt.settled) return Future<void>.value();
    attempt.settled = true;
    attempt.timer.cancel();
    _attempt = null;
    final stopping = _stopTransport();
    attempt.completer.completeError(error);
    return stopping;
  }

  /// Stops the transport and keeps the stop in [_stopping] until it is done,
  /// so that the next start does not overlap it.
  ///
  /// While a stop is still in flight, returns that stop instead of issuing
  /// another one; [_stopping] then always covers every stop in flight. This
  /// is enough: a stop is only issued for a running SDK, which needs a start
  /// that got past its wait for [_stopping], or by a failing start. A start
  /// that fails while [_stopping] is pending is still waiting for it and has
  /// never started the transport.
  ///
  /// Errors of the stop reach only whoever awaits the returned future; they
  /// are never reported as unhandled.
  Future<void> _stopTransport() {
    final pending = _stopping;
    if (pending != null) return pending;
    final stopping = Future<void>.sync(_transport.stop);
    _stopping = stopping;
    stopping.whenComplete(() {
      if (identical(_stopping, stopping)) _stopping = null;
    }).ignore();
    return stopping;
  }

  static AusweisAppStartException _asStartException(Object error) =>
      switch (error) {
        AusweisAppStartException() => error,
        AusweisAppException(:final message) => AusweisAppStartException(
          'start_failed',
          message,
        ),
        _ => const AusweisAppStartException(
          'start_failed',
          'The AusweisApp SDK could not be started.',
        ),
      };
}

/// One run of [AusweisApp.start], shared by concurrent callers.
class _StartAttempt {
  final Completer<void> completer = Completer<void>();
  late final Timer timer;

  /// Set once SET_API_LEVEL is about to be sent.
  bool awaitingApiLevel = false;

  /// Set once the attempt succeeded or failed.
  bool settled = false;

  Future<void> get future => completer.future;
}
