/// Exceptions thrown by the plugin. Their text never contains command
/// payloads (PIN, CAN, PUK, headers).
library;

/// Base class of all plugin exceptions.
sealed class AusweisAppException implements Exception {
  const AusweisAppException();

  /// Machine-readable error code.
  String get code;

  /// Human-readable description without any command payload.
  String get message;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// The SDK is not running, so commands cannot be sent.
final class AusweisAppNotRunningException extends AusweisAppException {
  const AusweisAppNotRunningException();

  @override
  String get code => 'not_running';

  @override
  String get message => 'The AusweisApp SDK is not running.';
}

/// The SDK could not be started (`start_failed`, `timeout`, `api_level`).
final class AusweisAppStartException extends AusweisAppException {
  const AusweisAppStartException(this.code, this.message);

  @override
  final String code;

  @override
  final String message;
}

/// A command could not be handed to the SDK (for example `send_failed`).
final class AusweisAppTransportException extends AusweisAppException {
  const AusweisAppTransportException(this.code, this.message);

  @override
  final String code;

  @override
  final String message;
}
