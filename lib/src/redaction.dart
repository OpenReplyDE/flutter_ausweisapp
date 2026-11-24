/// Redaction of secrets for the opt-in log of [AusweisApp].
library;

import 'dart:convert';

/// Receives one log line per command or message. See `AusweisApp.logger`.
typedef AusweisAppLogger = void Function(String line);

const String _redacted = '***';

/// Returns [command] as JSON text with its secrets replaced by `***`.
///
/// Redaction goes by key, not by command name, so commands this plugin does
/// not know are covered too: the value of `value` (PIN, CAN, PUK) and every
/// value under `header` (bearer tokens). Header names stay. A `null` value
/// stays `null`; it holds no secret. [command] is not changed.
String redactCommand(Map<String, Object?> command) {
  final redacted = <String, Object?>{
    for (final entry in command.entries)
      entry.key: switch (entry.key) {
        'value' => entry.value == null ? null : _redacted,
        'header' => _redactHeader(entry.value),
        _ => entry.value,
      },
  };
  return jsonEncode(redacted);
}

Object? _redactHeader(Object? header) => switch (header) {
  null => null,
  Map() => {for (final name in header.keys) '$name': _redacted},
  _ => _redacted,
};
