/// Abstraction of the channel to the AusweisApp SDK.
library;

/// Moves JSON strings between Dart and the native SDK.
abstract interface class AusweisAppTransport {
  /// Completes once the SDK accepts commands. Idempotent.
  Future<void> start();

  /// Stops the SDK and releases native resources.
  Future<void> stop();

  /// Sends one JSON command to the SDK.
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
