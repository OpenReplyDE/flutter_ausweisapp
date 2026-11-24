import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final demo = Uri.parse('https://test.governikus-eid.de/DEMO');
  final cases = <(Command, Map<String, Object?>)>[
    (const GetInfo(), {'cmd': 'GET_INFO'}),
    (const GetStatus(), {'cmd': 'GET_STATUS'}),
    (const GetApiLevel(), {'cmd': 'GET_API_LEVEL'}),
    (const SetApiLevel(3), {'cmd': 'SET_API_LEVEL', 'level': 3}),
    (const GetReader('NFC'), {'cmd': 'GET_READER', 'name': 'NFC'}),
    (const GetReaderList(), {'cmd': 'GET_READER_LIST'}),
    (
      RunAuth(tcTokenUrl: demo),
      {
        'cmd': 'RUN_AUTH',
        'tcTokenURL': 'https://test.governikus-eid.de/DEMO',
        'developerMode': false,
        'status': true,
      },
    ),
    (
      RunAuth(
        tcTokenUrl: demo,
        headers: const {'Authorization': 'Bearer t'},
        developerMode: true,
        status: false,
        userInfoMessages: const UserInfoMessages(
          sessionStarted: 'a',
          sessionInProgress: 'b',
        ),
      ),
      {
        'cmd': 'RUN_AUTH',
        'tcTokenURL': 'https://test.governikus-eid.de/DEMO',
        'header': {'Authorization': 'Bearer t'},
        'developerMode': true,
        'status': false,
        'messages': {'sessionStarted': 'a', 'sessionInProgress': 'b'},
      },
    ),
    (const RunChangePin(), {'cmd': 'RUN_CHANGE_PIN', 'status': true}),
    (
      const RunChangePin(
        status: false,
        userInfoMessages: UserInfoMessages(sessionFailed: 'x'),
      ),
      {
        'cmd': 'RUN_CHANGE_PIN',
        'status': false,
        'messages': {'sessionFailed': 'x'},
      },
    ),
    (const GetAccessRights(), {'cmd': 'GET_ACCESS_RIGHTS'}),
    (
      const SetAccessRights([]),
      {'cmd': 'SET_ACCESS_RIGHTS', 'chat': <String>[]},
    ),
    (
      const SetAccessRights(['FamilyName']),
      {
        'cmd': 'SET_ACCESS_RIGHTS',
        'chat': ['FamilyName'],
      },
    ),
    (const SetCard('Simulator'), {'cmd': 'SET_CARD', 'name': 'Simulator'}),
    (
      const SetCard(
        'Simulator',
        simulator: SimulatorData(
          files: [
            SimulatorFile(
              fileId: '0101',
              shortFileId: '01',
              content: '610413024944',
            ),
          ],
          keys: [SimulatorKey(id: 1, content: 'ab')],
        ),
      ),
      {
        'cmd': 'SET_CARD',
        'name': 'Simulator',
        'simulator': {
          'files': [
            {'fileId': '0101', 'shortFileId': '01', 'content': '610413024944'},
          ],
          'keys': [
            {'id': 1, 'content': 'ab'},
          ],
        },
      },
    ),
    (const Continue(), {'cmd': 'CONTINUE'}),
    (const GetCertificate(), {'cmd': 'GET_CERTIFICATE'}),
    (const Cancel(), {'cmd': 'CANCEL'}),
    (const Accept(), {'cmd': 'ACCEPT'}),
    (const Interrupt(), {'cmd': 'INTERRUPT'}),
    (const SetPin('123456'), {'cmd': 'SET_PIN', 'value': '123456'}),
    (const SetPin(null), {'cmd': 'SET_PIN'}),
    (const SetNewPin('123456'), {'cmd': 'SET_NEW_PIN', 'value': '123456'}),
    (const SetCan('123456'), {'cmd': 'SET_CAN', 'value': '123456'}),
    (const SetPuk('1234567890'), {'cmd': 'SET_PUK', 'value': '1234567890'}),
  ];

  group('Command.toJson', () {
    for (final (command, json) in cases) {
      test('${command.runtimeType} ${json.length} keys', () {
        expect(command.toJson(), json);
      });
    }

    test('covers exactly 20 distinct cmd names', () {
      final names = cases.map((c) => c.$2['cmd']).toSet();
      expect(names, hasLength(20));
    });
  });
}
