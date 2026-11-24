/// Messages received from the AusweisApp SDK, parsed from JSON.
library;

import 'dart:convert';

import 'models.dart';

/// Base class of all SDK messages.
sealed class Message {
  const Message();

  /// Parses an SDK message. Never throws: unknown messages, broken JSON and
  /// messages with missing or mistyped required fields become
  /// [UnknownMessage].
  static Message parse(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) return UnknownMessage(json);
      return _parse(decoded) ?? UnknownMessage(json);
    } on Object {
      return UnknownMessage(json);
    }
  }
}

/// `ACCESS_RIGHTS`: the rights requested by the service provider.
class AccessRightsMessage extends Message {
  const AccessRightsMessage({this.error, required this.rights});
  final String? error;
  final AccessRights rights;
}

/// `API_LEVEL`: available and current API levels.
class ApiLevelMessage extends Message {
  const ApiLevelMessage({this.error, required this.available, this.current});
  final String? error;
  final List<int> available;
  final int? current;
}

/// `AUTH`: start or end of an authentication.
class AuthMessage extends Message {
  const AuthMessage({this.error, this.result});
  final String? error;
  final AuthResult? result;
}

/// `BAD_STATE`: the previous command was sent in an invalid state.
class BadStateMessage extends Message {
  const BadStateMessage({this.error});
  final String? error;
}

/// `CERTIFICATE`: the certificate of the service provider.
class CertificateMessage extends Message {
  const CertificateMessage({required this.certificate});
  final Certificate certificate;
}

/// `CHANGE_PIN`: start or end of a PIN change.
class ChangePinMessage extends Message {
  const ChangePinMessage({this.success, this.reason});
  final bool? success;
  final String? reason;
}

/// `ENTER_CAN`: a CAN is required.
class EnterCanMessage extends Message {
  const EnterCanMessage({this.error, required this.reader});
  final String? error;
  final Reader reader;
}

/// `ENTER_PIN`: a PIN is required.
class EnterPinMessage extends Message {
  const EnterPinMessage({this.error, required this.reader});
  final String? error;
  final Reader reader;
}

/// `ENTER_NEW_PIN`: a new PIN is required.
class EnterNewPinMessage extends Message {
  const EnterNewPinMessage({this.error, required this.reader});
  final String? error;
  final Reader reader;
}

/// `ENTER_PUK`: a PUK is required.
class EnterPukMessage extends Message {
  const EnterPukMessage({this.error, required this.reader});
  final String? error;
  final Reader reader;
}

/// `INFO`: version information of the AusweisApp.
class InfoMessage extends Message {
  const InfoMessage({this.versionInfo, this.ausweisApp});
  final VersionInfo? versionInfo;

  /// Connection state of the integrated SDK (Android only).
  final String? ausweisApp;
}

/// `INSERT_CARD`: a card is required.
class InsertCardMessage extends Message {
  const InsertCardMessage({this.error});
  final String? error;
}

/// `INTERNAL_ERROR`: an internal error occurred.
class InternalErrorMessage extends Message {
  const InternalErrorMessage({this.error});
  final String? error;
}

/// `INVALID`: a command was not valid JSON.
class InvalidMessage extends Message {
  const InvalidMessage({this.error});
  final String? error;
}

/// `UNKNOWN_COMMAND`: the command type is unknown.
class UnknownCommandMessage extends Message {
  const UnknownCommandMessage({this.error});
  final String? error;
}

/// `READER`: a card reader changed.
class ReaderMessage extends Message {
  const ReaderMessage({required this.reader});
  final Reader reader;
}

/// `READER_LIST`: all connected card readers.
class ReaderListMessage extends Message {
  const ReaderListMessage({required this.readers});
  final List<Reader> readers;
}

/// `STATUS`: current workflow and state.
class StatusMessage extends Message {
  const StatusMessage({this.workflow, this.progress, this.state});
  final String? workflow;
  final int? progress;
  final String? state;
}

/// `PAUSE`: the SDK waits for a condition to be fixed.
class PauseMessage extends Message {
  const PauseMessage({required this.cause});

  /// See [PauseCause]; unknown causes are kept as text.
  final String cause;
}

/// Fallback for anything that is not a known, well-formed message.
class UnknownMessage extends Message {
  const UnknownMessage(this.raw);

  /// The unmodified text received from the SDK.
  final String raw;
}

// Parsing. Helpers throw on mistyped values; [Message.parse] catches that.

Message? _parse(Map<String, Object?> j) {
  switch (j['msg']) {
    case 'ACCESS_RIGHTS':
      final chat = _obj(j, 'chat');
      final aux = _obj(j, 'aux');
      return AccessRightsMessage(
        error: _str(j, 'error'),
        rights: AccessRights(
          effective: _strList(chat, 'effective'),
          optional: _strList(chat, 'optional'),
          required: _strList(chat, 'required'),
          transactionInfo: _str(j, 'transactionInfo'),
          aux: aux == null
              ? null
              : AuxiliaryData(
                  ageVerificationDate: _date(aux, 'ageVerificationDate'),
                  requiredAge: _age(aux['requiredAge']),
                  validityDate: _date(aux, 'validityDate'),
                  communityId: _str(aux, 'communityId'),
                ),
        ),
      );
    case 'API_LEVEL':
      final available = j['available'];
      if (available != null && available is! List) return null;
      return ApiLevelMessage(
        error: _str(j, 'error'),
        available: [for (final v in (available as List?) ?? const []) v as int],
        current: _int(j, 'current'),
      );
    case 'AUTH':
      final result = _obj(j, 'result');
      final url = _str(j, 'url');
      return AuthMessage(
        error: _str(j, 'error'),
        result: result == null
            ? null
            : AuthResult(
                major: _str(result, 'major'),
                minor: _str(result, 'minor'),
                language: _str(result, 'language'),
                description: _str(result, 'description'),
                message: _str(result, 'message'),
                reason: _str(result, 'reason'),
                url: url == null ? null : Uri.tryParse(url),
              ),
      );
    case 'BAD_STATE':
      return BadStateMessage(error: _str(j, 'error'));
    case 'CERTIFICATE':
      final d = _obj(j, 'description');
      final v = _obj(j, 'validity');
      return CertificateMessage(
        certificate: Certificate(
          issuerName: _str(d, 'issuerName'),
          issuerUrl: _str(d, 'issuerUrl'),
          subjectName: _str(d, 'subjectName'),
          subjectUrl: _str(d, 'subjectUrl'),
          termsOfUsage: _str(d, 'termsOfUsage'),
          purpose: _str(d, 'purpose'),
          effectiveDate: _date(v, 'effectiveDate'),
          expirationDate: _date(v, 'expirationDate'),
        ),
      );
    case 'CHANGE_PIN':
      return ChangePinMessage(
        success: _bool(j, 'success'),
        reason: _str(j, 'reason'),
      );
    case 'ENTER_CAN':
      return EnterCanMessage(
        error: _str(j, 'error'),
        reader: _reader(_req(j, 'reader')),
      );
    case 'ENTER_PIN':
      return EnterPinMessage(
        error: _str(j, 'error'),
        reader: _reader(_req(j, 'reader')),
      );
    case 'ENTER_NEW_PIN':
      return EnterNewPinMessage(
        error: _str(j, 'error'),
        reader: _reader(_req(j, 'reader')),
      );
    case 'ENTER_PUK':
      return EnterPukMessage(
        error: _str(j, 'error'),
        reader: _reader(_req(j, 'reader')),
      );
    case 'INFO':
      final vi = _obj(j, 'VersionInfo');
      return InfoMessage(
        versionInfo: vi == null
            ? null
            : VersionInfo(
                name: _str(vi, 'Name'),
                implementationTitle: _str(vi, 'Implementation-Title'),
                implementationVendor: _str(vi, 'Implementation-Vendor'),
                implementationVersion: _str(vi, 'Implementation-Version'),
                specificationTitle: _str(vi, 'Specification-Title'),
                specificationVendor: _str(vi, 'Specification-Vendor'),
                specificationVersion: _str(vi, 'Specification-Version'),
              ),
        ausweisApp: _str(j, 'AusweisApp'),
      );
    case 'INSERT_CARD':
      return InsertCardMessage(error: _str(j, 'error'));
    case 'INTERNAL_ERROR':
      return InternalErrorMessage(error: _str(j, 'error'));
    case 'INVALID':
      return InvalidMessage(error: _str(j, 'error'));
    case 'UNKNOWN_COMMAND':
      return UnknownCommandMessage(error: _str(j, 'error'));
    case 'READER':
      return ReaderMessage(reader: _reader(j));
    case 'READER_LIST':
      final readers = j['readers'];
      if (readers != null && readers is! List) return null;
      return ReaderListMessage(
        readers: [
          for (final r in (readers as List?) ?? const [])
            _reader(r as Map<String, Object?>),
        ],
      );
    case 'STATUS':
      return StatusMessage(
        workflow: _str(j, 'workflow'),
        progress: _int(j, 'progress'),
        state: _str(j, 'state'),
      );
    case 'PAUSE':
      final cause = _str(j, 'cause');
      return cause == null ? null : PauseMessage(cause: cause);
    default:
      return null;
  }
}

Reader _reader(Map<String, Object?> j) {
  final name = _str(j, 'name');
  if (name == null) throw const FormatException('reader without name');
  final card = j['card'];
  return Reader(
    name: name,
    insertable: _bool(j, 'insertable') ?? false,
    attached: _bool(j, 'attached') ?? false,
    keypad: _bool(j, 'keypad'),
    card: card == null
        ? null
        : Card(
            inoperative: _bool(card as Map<String, Object?>, 'inoperative'),
            deactivated: _bool(card, 'deactivated'),
            retryCounter: _int(card, 'retryCounter'),
          ),
  );
}

Map<String, Object?> _req(Map<String, Object?> j, String key) =>
    _obj(j, key) ?? (throw FormatException('missing $key'));

Map<String, Object?>? _obj(Map<String, Object?>? j, String key) =>
    j?[key] as Map<String, Object?>?;

String? _str(Map<String, Object?>? j, String key) => j?[key] as String?;

bool? _bool(Map<String, Object?>? j, String key) => j?[key] as bool?;

int? _int(Map<String, Object?>? j, String key) => j?[key] as int?;

DateTime? _date(Map<String, Object?>? j, String key) {
  final s = _str(j, key);
  return s == null ? null : DateTime.tryParse(s);
}

List<String> _strList(Map<String, Object?>? j, String key) => [
  for (final v in (j?[key] as List?) ?? const []) v as String,
];

int? _age(Object? v) => switch (v) {
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};
