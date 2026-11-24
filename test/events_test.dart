import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_test/flutter_test.dart';

AusweisAppEvent map(Message message) => AusweisAppEvent.fromMessage(message);

const nfc = Reader(
  name: 'NFC',
  insertable: false,
  attached: true,
  keypad: false,
  card: Card(inoperative: false, deactivated: false, retryCounter: 3),
);

void main() {
  group('AUTH', () {
    test('AUTH without result and error becomes AuthenticationStarted', () {
      expect(map(const AuthMessage()), isA<AuthenticationStarted>());
    });

    test('AUTH with error and without result becomes '
        'AuthenticationStartFailed', () {
      final event = map(const AuthMessage(error: 'bad url'));
      expect(
        event,
        isA<AuthenticationStartFailed>().having(
          (e) => e.error,
          'error',
          'bad url',
        ),
      );
    });

    test('AUTH with result becomes AuthenticationCompleted', () {
      final result = AuthResult(
        major: 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok',
        url: Uri.parse('https://a.example/refresh'),
      );
      final event = map(AuthMessage(result: result));
      expect(
        event,
        isA<AuthenticationCompleted>().having(
          (e) => e.result,
          'result',
          same(result),
        ),
      );
    });

    test('AUTH with result and error is still AuthenticationCompleted', () {
      const result = AuthResult(major: 'x#error');
      final event = map(const AuthMessage(error: 'late', result: result));
      expect(
        event,
        isA<AuthenticationCompleted>().having(
          (e) => e.result,
          'result',
          same(result),
        ),
      );
    });
  });

  test('ACCESS_RIGHTS becomes AccessRightsRequested with rights and error', () {
    const rights = AccessRights(
      effective: ['FamilyName'],
      optional: [],
      required: ['FamilyName'],
    );
    final event = map(
      const AccessRightsMessage(rights: rights, error: 'bad chat'),
    );
    expect(
      event,
      isA<AccessRightsRequested>()
          .having((e) => e.rights, 'rights', same(rights))
          .having((e) => e.error, 'error', 'bad chat'),
    );
  });

  test('INSERT_CARD becomes InsertCardRequested with error', () {
    expect(
      map(const InsertCardMessage(error: 'no card')),
      isA<InsertCardRequested>().having((e) => e.error, 'error', 'no card'),
    );
    expect(
      map(const InsertCardMessage()),
      isA<InsertCardRequested>().having((e) => e.error, 'error', isNull),
    );
  });

  group('ENTER_*', () {
    test('ENTER_PIN becomes PinRequested with reader and error', () {
      expect(
        map(const EnterPinMessage(reader: nfc, error: 'wrong')),
        isA<PinRequested>()
            .having((e) => e.reader, 'reader', same(nfc))
            .having((e) => e.error, 'error', 'wrong'),
      );
    });

    test('ENTER_CAN becomes CanRequested with reader and error', () {
      expect(
        map(const EnterCanMessage(reader: nfc, error: 'wrong')),
        isA<CanRequested>()
            .having((e) => e.reader, 'reader', same(nfc))
            .having((e) => e.error, 'error', 'wrong'),
      );
    });

    test('ENTER_PUK becomes PukRequested with reader and error', () {
      expect(
        map(const EnterPukMessage(reader: nfc)),
        isA<PukRequested>()
            .having((e) => e.reader, 'reader', same(nfc))
            .having((e) => e.error, 'error', isNull),
      );
    });

    test('ENTER_NEW_PIN becomes NewPinRequested with reader and error', () {
      expect(
        map(const EnterNewPinMessage(reader: nfc, error: 'too short')),
        isA<NewPinRequested>()
            .having((e) => e.reader, 'reader', same(nfc))
            .having((e) => e.error, 'error', 'too short'),
      );
    });
  });

  test('PAUSE becomes Paused with cause', () {
    expect(
      map(const PauseMessage(cause: PauseCause.badCardPosition)),
      isA<Paused>().having((e) => e.cause, 'cause', 'BadCardPosition'),
    );
  });

  group('CHANGE_PIN', () {
    test('CHANGE_PIN without success becomes ChangePinStarted', () {
      expect(map(const ChangePinMessage()), isA<ChangePinStarted>());
    });

    test('CHANGE_PIN with success becomes ChangePinCompleted', () {
      expect(
        map(const ChangePinMessage(success: false, reason: 'Card_Removed')),
        isA<ChangePinCompleted>()
            .having((e) => e.success, 'success', isFalse)
            .having((e) => e.reason, 'reason', 'Card_Removed'),
      );
      expect(
        map(const ChangePinMessage(success: true)),
        isA<ChangePinCompleted>()
            .having((e) => e.success, 'success', isTrue)
            .having((e) => e.reason, 'reason', isNull),
      );
    });
  });

  test('CERTIFICATE becomes CertificateReceived', () {
    const certificate = Certificate(subjectName: 'Governikus');
    expect(
      map(const CertificateMessage(certificate: certificate)),
      isA<CertificateReceived>().having(
        (e) => e.certificate,
        'certificate',
        same(certificate),
      ),
    );
  });

  test('READER becomes ReaderChanged', () {
    expect(
      map(const ReaderMessage(reader: nfc)),
      isA<ReaderChanged>().having((e) => e.reader, 'reader', same(nfc)),
    );
  });

  test('READER_LIST becomes ReaderListReceived', () {
    final event = map(const ReaderListMessage(readers: [nfc]));
    expect(
      event,
      isA<ReaderListReceived>().having(
        (e) => e.readers.single,
        'readers.single',
        same(nfc),
      ),
    );
  });

  test('STATUS becomes StatusChanged with workflow, progress and state', () {
    expect(
      map(
        const StatusMessage(
          workflow: 'AUTH',
          progress: 25,
          state: 'ACCESS_RIGHTS',
        ),
      ),
      isA<StatusChanged>()
          .having((e) => e.workflow, 'workflow', 'AUTH')
          .having((e) => e.progress, 'progress', 25)
          .having((e) => e.state, 'state', 'ACCESS_RIGHTS'),
    );
  });

  test('INFO becomes InfoReceived with versionInfo and ausweisApp', () {
    const info = VersionInfo(implementationVersion: '2.6.3');
    expect(
      map(const InfoMessage(versionInfo: info, ausweisApp: 'CONNECTED')),
      isA<InfoReceived>()
          .having((e) => e.versionInfo, 'versionInfo', same(info))
          .having((e) => e.ausweisApp, 'ausweisApp', 'CONNECTED'),
    );
  });

  test('API_LEVEL becomes ApiLevelReceived with available, current, error', () {
    expect(
      map(const ApiLevelMessage(available: [1, 2, 3], current: 2, error: 'x')),
      isA<ApiLevelReceived>()
          .having((e) => e.available, 'available', [1, 2, 3])
          .having((e) => e.current, 'current', 2)
          .having((e) => e.error, 'error', 'x'),
    );
  });

  test('BAD_STATE becomes BadState naming the command', () {
    expect(
      map(const BadStateMessage(error: 'GET_CERTIFICATE')),
      isA<BadState>().having((e) => e.command, 'command', 'GET_CERTIFICATE'),
    );
  });

  test('UNKNOWN_COMMAND becomes UnknownCommand naming the command', () {
    expect(
      map(const UnknownCommandMessage(error: 'get_INFo')),
      isA<UnknownCommand>().having((e) => e.command, 'command', 'get_INFo'),
    );
  });

  test('INTERNAL_ERROR becomes InternalError with error', () {
    expect(
      map(const InternalErrorMessage(error: 'Unexpected condition')),
      isA<InternalError>().having(
        (e) => e.error,
        'error',
        'Unexpected condition',
      ),
    );
  });

  test('INVALID becomes InvalidCommand with error', () {
    expect(
      map(const InvalidMessage(error: 'unterminated string (offset: 12)')),
      isA<InvalidCommand>().having(
        (e) => e.error,
        'error',
        'unterminated string (offset: 12)',
      ),
    );
  });

  test('UnknownMessage becomes UnknownMessageReceived with the raw text', () {
    expect(
      map(const UnknownMessage('{"msg":"FUTURE"}')),
      isA<UnknownMessageReceived>().having(
        (e) => e.raw,
        'raw',
        '{"msg":"FUTURE"}',
      ),
    );
  });

  test('TransportDisconnected becomes Disconnected', () async {
    final fake = FakeAusweisAppTransport();
    final eid = AusweisApp(transport: fake);
    addTearDown(eid.dispose);
    await eid.start();
    final next = eid.events.first;
    fake.disconnect();
    expect(await next, isA<Disconnected>());
  });

  test('the switch from the design compiles against the event fields', () {
    // Spec 5.3: the app-facing usage pattern.
    String handle(AusweisAppEvent event) => switch (event) {
      AuthenticationStarted() => 'progress',
      AccessRightsRequested(:final rights) => 'rights ${rights.required}',
      InsertCardRequested() => 'card hint',
      PinRequested(:final reader) => 'pin ${reader.card?.retryCounter}',
      CanRequested() => 'can',
      PukRequested() => 'puk',
      NewPinRequested() => 'new pin',
      Paused(:final cause) => 'reposition $cause',
      AuthenticationCompleted(:final result) => 'login ${result.url}',
      ChangePinCompleted(:final success) => 'pin changed $success',
      _ => 'other',
    };

    expect(handle(const AuthenticationStarted()), 'progress');
    expect(handle(const PinRequested(reader: nfc)), 'pin 3');
    expect(
      handle(
        AuthenticationCompleted(
          result: AuthResult(url: Uri.parse('https://a.example/r')),
        ),
      ),
      'login https://a.example/r',
    );
    expect(handle(const ChangePinCompleted(success: true)), 'pin changed true');
    expect(handle(const Disconnected()), 'other');
  });

  test('events form a closed set an app can switch over exhaustively', () {
    // Compiles only while AusweisAppEvent is sealed and has exactly these
    // subtypes.
    String name(AusweisAppEvent event) => switch (event) {
      AuthenticationStarted() => 'AuthenticationStarted',
      AuthenticationStartFailed() => 'AuthenticationStartFailed',
      AuthenticationCompleted() => 'AuthenticationCompleted',
      AccessRightsRequested() => 'AccessRightsRequested',
      InsertCardRequested() => 'InsertCardRequested',
      PinRequested() => 'PinRequested',
      CanRequested() => 'CanRequested',
      PukRequested() => 'PukRequested',
      NewPinRequested() => 'NewPinRequested',
      Paused() => 'Paused',
      ChangePinStarted() => 'ChangePinStarted',
      ChangePinCompleted() => 'ChangePinCompleted',
      CertificateReceived() => 'CertificateReceived',
      ReaderChanged() => 'ReaderChanged',
      ReaderListReceived() => 'ReaderListReceived',
      StatusChanged() => 'StatusChanged',
      InfoReceived() => 'InfoReceived',
      ApiLevelReceived() => 'ApiLevelReceived',
      BadState() => 'BadState',
      UnknownCommand() => 'UnknownCommand',
      InternalError() => 'InternalError',
      InvalidCommand() => 'InvalidCommand',
      UnknownMessageReceived() => 'UnknownMessageReceived',
      Disconnected() => 'Disconnected',
    };

    expect(name(const Disconnected()), 'Disconnected');
    expect(name(map(const ChangePinMessage())), 'ChangePinStarted');
  });

  test('list fields of events cannot be modified', () {
    final readers = map(const ReaderListMessage(readers: [nfc]));
    final level = map(const ApiLevelMessage(available: [3], current: 3));
    expect(
      () => (readers as ReaderListReceived).readers.add(nfc),
      throwsUnsupportedError,
    );
    expect(
      () => (level as ApiLevelReceived).available.add(4),
      throwsUnsupportedError,
    );
  });
}
