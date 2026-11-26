/// Events delivered by `AusweisApp.events`, named by meaning rather than by
/// protocol message.
library;

import 'package:flutter/foundation.dart' show immutable;

import 'failure.dart';
import 'protocol/message.dart';
import 'protocol/models.dart';

/// Base class of all events. Sealed, so a `switch` over it can be exhaustive.
@immutable
sealed class AusweisAppEvent {
  const AusweisAppEvent();

  /// Maps an SDK [message] to the event it means.
  static AusweisAppEvent fromMessage(Message message) => switch (message) {
    AuthMessage(:final result?) => AuthenticationCompleted(result: result),
    AuthMessage(:final error?) => AuthenticationStartFailed(error: error),
    AuthMessage() => const AuthenticationStarted(),
    AccessRightsMessage(:final rights, :final error) => AccessRightsRequested(
      rights: rights,
      error: error,
    ),
    InsertCardMessage(:final error) => InsertCardRequested(error: error),
    EnterPinMessage(:final reader, :final error) => PinRequested(
      reader: reader,
      error: error,
    ),
    EnterCanMessage(:final reader, :final error) => CanRequested(
      reader: reader,
      error: error,
    ),
    EnterPukMessage(:final reader, :final error) => PukRequested(
      reader: reader,
      error: error,
    ),
    EnterNewPinMessage(:final reader, :final error) => NewPinRequested(
      reader: reader,
      error: error,
    ),
    PauseMessage(:final cause) => Paused(cause: cause),
    ChangePinMessage(:final success?, :final reason) => ChangePinCompleted(
      success: success,
      reason: reason,
    ),
    ChangePinMessage() => const ChangePinStarted(),
    CertificateMessage(:final certificate) => CertificateReceived(
      certificate: certificate,
    ),
    ReaderMessage(:final reader) => ReaderChanged(reader: reader),
    ReaderListMessage(:final readers) => ReaderListReceived(
      readers: List.unmodifiable(readers),
    ),
    StatusMessage(:final workflow, :final progress, :final state) =>
      StatusChanged(workflow: workflow, progress: progress, state: state),
    InfoMessage(:final versionInfo, :final ausweisApp) => InfoReceived(
      versionInfo: versionInfo,
      ausweisApp: ausweisApp,
    ),
    ApiLevelMessage(:final available, :final current, :final error) =>
      ApiLevelReceived(
        available: List.unmodifiable(available),
        current: current,
        error: error,
      ),
    BadStateMessage(:final error) => BadState(command: error),
    UnknownCommandMessage(:final error) => UnknownCommand(command: error),
    InternalErrorMessage(:final error) => InternalError(error: error),
    InvalidMessage(:final error) => InvalidCommand(error: error),
    UnknownMessage(:final raw) => UnknownMessageReceived(raw: raw),
  };
}

/// An authentication has started (`AUTH` without result).
final class AuthenticationStarted extends AusweisAppEvent {
  const AuthenticationStarted();
}

/// `RUN_AUTH` was rejected, for example because of an invalid `tcTokenURL`.
final class AuthenticationStartFailed extends AusweisAppEvent {
  const AuthenticationStartFailed({required this.error});

  final String error;
}

/// An authentication has ended, successfully or not. See
/// [AuthResult.isSuccess] and [AuthResult.url].
final class AuthenticationCompleted extends AusweisAppEvent {
  const AuthenticationCompleted({required this.result});

  final AuthResult result;
}

/// The service provider requests [rights]. Answer with `accept()`, change
/// them with `setAccessRights()` or abort with `cancel()`.
final class AccessRightsRequested extends AusweisAppEvent {
  const AccessRightsRequested({required this.rights, this.error});

  final AccessRights rights;

  /// Set if the previous `SET_ACCESS_RIGHTS` was invalid.
  final String? error;
}

/// A card is needed. Ask the user to place it on the reader.
final class InsertCardRequested extends AusweisAppEvent {
  const InsertCardRequested({this.error});

  final String? error;
}

/// The PIN is needed. Answer with `setPin()`.
final class PinRequested extends AusweisAppEvent {
  const PinRequested({required this.reader, this.error});

  /// The reader holding the card; [Reader.card] tells the retry counter.
  final Reader reader;

  /// Set if the previous `SET_PIN` was invalid.
  final String? error;
}

/// The CAN is needed. Answer with `setCan()`.
final class CanRequested extends AusweisAppEvent {
  const CanRequested({required this.reader, this.error});

  final Reader reader;

  /// Set if the previous `SET_CAN` was invalid.
  final String? error;
}

/// The PUK is needed. Answer with `setPuk()`.
final class PukRequested extends AusweisAppEvent {
  const PukRequested({required this.reader, this.error});

  final Reader reader;

  /// Set if the previous `SET_PUK` was invalid.
  final String? error;
}

/// The new PIN is needed during a PIN change. Answer with `setNewPin()`.
final class NewPinRequested extends AusweisAppEvent {
  const NewPinRequested({required this.reader, this.error});

  final Reader reader;

  /// Set if the previous `SET_NEW_PIN` was invalid.
  final String? error;
}

/// The workflow waits until [cause] is fixed. Resume with
/// `continueWorkflow()`.
final class Paused extends AusweisAppEvent {
  const Paused({required this.cause});

  /// See [PauseCause].
  final String cause;
}

/// A PIN change has started (`CHANGE_PIN` without success).
final class ChangePinStarted extends AusweisAppEvent {
  const ChangePinStarted();
}

/// A PIN change has ended.
final class ChangePinCompleted extends AusweisAppEvent {
  const ChangePinCompleted({required this.success, this.reason});

  final bool success;

  /// Failure code if [success] is false.
  final String? reason;

  /// What kind of failure [reason] stands for, or `null` if the PIN was
  /// changed. A failure without a known [reason] is [FailureKind.other].
  FailureKind? get failureKind =>
      success ? null : FailureKind.fromReason(reason);
}

/// Answer to `getCertificate()`.
final class CertificateReceived extends AusweisAppEvent {
  const CertificateReceived({required this.certificate});

  final Certificate certificate;
}

/// A reader or the card in it changed, or answer to `getReader()`.
final class ReaderChanged extends AusweisAppEvent {
  const ReaderChanged({required this.reader});

  final Reader reader;
}

/// Answer to `getReaderList()`.
final class ReaderListReceived extends AusweisAppEvent {
  const ReaderListReceived({required this.readers});

  final List<Reader> readers;
}

/// Progress of the running workflow, or answer to `getStatus()`.
final class StatusChanged extends AusweisAppEvent {
  const StatusChanged({this.workflow, this.progress, this.state});

  final String? workflow;
  final int? progress;
  final String? state;
}

/// Answer to `getInfo()`.
final class InfoReceived extends AusweisAppEvent {
  const InfoReceived({this.versionInfo, this.ausweisApp});

  final VersionInfo? versionInfo;

  /// Connection state of the integrated SDK (Android only).
  final String? ausweisApp;
}

/// Answer to `getApiLevel()` and `setApiLevel()`.
final class ApiLevelReceived extends AusweisAppEvent {
  const ApiLevelReceived({required this.available, this.current, this.error});

  final List<int> available;
  final int? current;
  final String? error;
}

/// The SDK refused [command] because it is not allowed in the current state.
final class BadState extends AusweisAppEvent {
  const BadState({this.command});

  /// Name of the refused command.
  final String? command;
}

/// The SDK does not know [command].
final class UnknownCommand extends AusweisAppEvent {
  const UnknownCommand({this.command});

  /// Name of the unknown command.
  final String? command;
}

/// The SDK reported an internal error.
final class InternalError extends AusweisAppEvent {
  const InternalError({this.error});

  final String? error;
}

/// The SDK could not read a command as JSON.
final class InvalidCommand extends AusweisAppEvent {
  const InvalidCommand({this.error});

  final String? error;
}

/// A message the plugin does not understand, kept as received.
final class UnknownMessageReceived extends AusweisAppEvent {
  const UnknownMessageReceived({required this.raw});

  /// The unmodified text received from the SDK.
  final String raw;
}

/// The connection to the SDK was lost. Call `start()` again to reconnect.
final class Disconnected extends AusweisAppEvent {
  const Disconnected();
}
