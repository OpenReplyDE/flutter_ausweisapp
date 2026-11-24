/// Abstraction of the channel to the AusweisApp SDK.
library;

/// Moves JSON strings between Dart and the native SDK.
///
/// `AusweisApp` relies on these guarantees of every implementation:
///
/// - [stop] always completes, also when nothing was started. A stop that
///   never completes holds every later start of `AusweisApp` back until that
///   start times out.
/// - [stop] ends a [start] that is still pending: that start fails with
///   `AusweisAppStartException` (code `start_failed`), and the SDK is not
///   left running.
/// - Failures of [start], [stop] and [send] are reported only through their
///   futures, never on [events]. An error on [events] would mean a fault of
///   the channel itself; the native plugins send none. `AusweisApp` passes
///   such an error on to its own events as a stream error.
abstract interface class AusweisAppTransport {
  /// Completes once the SDK accepts commands. Idempotent.
  Future<void> start();

  /// Stops the SDK and releases native resources. Always completes; ends a
  /// pending [start] with `start_failed`.
  Future<void> stop();

  /// Sends one JSON command to the SDK. Throws
  /// `AusweisAppNotRunningException` if the SDK is not running.
  Future<void> send(String json);

  /// Whether the SDK is currently running.
  Future<bool> isRunning();

  /// Events coming from the SDK. A broadcast stream.
  Stream<TransportEvent> get events;
}

/// Something that arrives from the SDK.
sealed class TransportEvent {
  const TransportEvent();
}

/// A JSON message from the SDK.
final class TransportMessage extends TransportEvent {
  const TransportMessage(this.json);

  final String json;
}

/// The connection to the SDK was lost.
final class TransportDisconnected extends TransportEvent {
  const TransportDisconnected();
}
