/// Commands sent to the AusweisApp SDK, serialized as JSON objects.
library;

/// Base class of all SDK commands.
sealed class Command {
  const Command();

  /// The JSON representation sent to the SDK.
  Map<String, Object?> toJson();
}

/// Texts shown by the system NFC dialog (iOS).
class UserInfoMessages {
  const UserInfoMessages({
    this.sessionStarted,
    this.sessionFailed,
    this.sessionSucceeded,
    this.sessionInProgress,
  });

  final String? sessionStarted;
  final String? sessionFailed;
  final String? sessionSucceeded;
  final String? sessionInProgress;

  Map<String, Object?> toJson() => {
    if (sessionStarted != null) 'sessionStarted': sessionStarted,
    if (sessionFailed != null) 'sessionFailed': sessionFailed,
    if (sessionSucceeded != null) 'sessionSucceeded': sessionSucceeded,
    if (sessionInProgress != null) 'sessionInProgress': sessionInProgress,
  };
}

/// A file of a simulated card.
class SimulatorFile {
  const SimulatorFile({
    required this.fileId,
    required this.shortFileId,
    required this.content,
  });

  final String fileId;
  final String shortFileId;
  final String content;

  Map<String, Object?> toJson() => {
    'fileId': fileId,
    'shortFileId': shortFileId,
    'content': content,
  };
}

/// A key of a simulated card.
class SimulatorKey {
  const SimulatorKey({required this.id, required this.content});

  final int id;
  final String content;

  Map<String, Object?> toJson() => {'id': id, 'content': content};
}

/// Data of a simulated card for [SetCard].
class SimulatorData {
  const SimulatorData({required this.files, this.keys});

  final List<SimulatorFile> files;
  final List<SimulatorKey>? keys;

  Map<String, Object?> toJson() => {
    'files': [for (final f in files) f.toJson()],
    if (keys != null) 'keys': [for (final k in keys!) k.toJson()],
  };
}

class GetInfo extends Command {
  const GetInfo();

  @override
  Map<String, Object?> toJson() => {'cmd': 'GET_INFO'};
}

class GetStatus extends Command {
  const GetStatus();

  @override
  Map<String, Object?> toJson() => {'cmd': 'GET_STATUS'};
}

class GetApiLevel extends Command {
  const GetApiLevel();

  @override
  Map<String, Object?> toJson() => {'cmd': 'GET_API_LEVEL'};
}

class SetApiLevel extends Command {
  const SetApiLevel(this.level);

  final int level;

  @override
  Map<String, Object?> toJson() => {'cmd': 'SET_API_LEVEL', 'level': level};
}

class GetReader extends Command {
  const GetReader(this.name);

  final String name;

  @override
  Map<String, Object?> toJson() => {'cmd': 'GET_READER', 'name': name};
}

class GetReaderList extends Command {
  const GetReaderList();

  @override
  Map<String, Object?> toJson() => {'cmd': 'GET_READER_LIST'};
}

class RunAuth extends Command {
  const RunAuth({
    required this.tcTokenUrl,
    this.headers = const {},
    this.developerMode = false,
    this.status = true,
    this.userInfoMessages,
  });

  final Uri tcTokenUrl;
  final Map<String, String> headers;
  final bool developerMode;
  final bool status;
  final UserInfoMessages? userInfoMessages;

  @override
  Map<String, Object?> toJson() => {
    'cmd': 'RUN_AUTH',
    'tcTokenURL': tcTokenUrl.toString(),
    if (headers.isNotEmpty) 'header': headers,
    'developerMode': developerMode,
    'status': status,
    if (userInfoMessages != null) 'messages': userInfoMessages!.toJson(),
  };
}

class RunChangePin extends Command {
  const RunChangePin({this.status = true, this.userInfoMessages});

  final bool status;
  final UserInfoMessages? userInfoMessages;

  @override
  Map<String, Object?> toJson() => {
    'cmd': 'RUN_CHANGE_PIN',
    'status': status,
    if (userInfoMessages != null) 'messages': userInfoMessages!.toJson(),
  };
}

class GetAccessRights extends Command {
  const GetAccessRights();

  @override
  Map<String, Object?> toJson() => {'cmd': 'GET_ACCESS_RIGHTS'};
}

class SetAccessRights extends Command {
  const SetAccessRights(this.chat);

  final List<String> chat;

  @override
  Map<String, Object?> toJson() => {'cmd': 'SET_ACCESS_RIGHTS', 'chat': chat};
}

class SetCard extends Command {
  const SetCard(this.name, {this.simulator});

  final String name;
  final SimulatorData? simulator;

  @override
  Map<String, Object?> toJson() => {
    'cmd': 'SET_CARD',
    'name': name,
    if (simulator != null) 'simulator': simulator!.toJson(),
  };
}

class Continue extends Command {
  const Continue();

  @override
  Map<String, Object?> toJson() => {'cmd': 'CONTINUE'};
}

class GetCertificate extends Command {
  const GetCertificate();

  @override
  Map<String, Object?> toJson() => {'cmd': 'GET_CERTIFICATE'};
}

class Cancel extends Command {
  const Cancel();

  @override
  Map<String, Object?> toJson() => {'cmd': 'CANCEL'};
}

class Accept extends Command {
  const Accept();

  @override
  Map<String, Object?> toJson() => {'cmd': 'ACCEPT'};
}

class Interrupt extends Command {
  const Interrupt();

  @override
  Map<String, Object?> toJson() => {'cmd': 'INTERRUPT'};
}

class SetPin extends Command {
  const SetPin(this.value);

  /// The PIN, or null to let the SDK ask the (external) reader.
  final String? value;

  @override
  Map<String, Object?> toJson() => {
    'cmd': 'SET_PIN',
    if (value != null) 'value': value,
  };
}

class SetNewPin extends Command {
  const SetNewPin(this.value);

  final String? value;

  @override
  Map<String, Object?> toJson() => {
    'cmd': 'SET_NEW_PIN',
    if (value != null) 'value': value,
  };
}

class SetCan extends Command {
  const SetCan(this.value);

  final String? value;

  @override
  Map<String, Object?> toJson() => {
    'cmd': 'SET_CAN',
    if (value != null) 'value': value,
  };
}

class SetPuk extends Command {
  const SetPuk(this.value);

  final String? value;

  @override
  Map<String, Object?> toJson() => {
    'cmd': 'SET_PUK',
    if (value != null) 'value': value,
  };
}
