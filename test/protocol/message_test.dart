import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/sdk_examples.dart' as ex;

void main() {
  group('SDK examples', () {
    test('ACCESS_RIGHTS with all fields', () {
      final m = Message.parse(ex.accessRightsFull) as AccessRightsMessage;
      expect(m.error, 'some optional error message');
      expect(m.rights.effective, [
        'Address',
        'FamilyName',
        'GivenNames',
        'AgeVerification',
        'CanAllowed',
      ]);
      expect(m.rights.optional, [
        'GivenNames',
        'AgeVerification',
        'CanAllowed',
      ]);
      expect(m.rights.required, ['Address', 'FamilyName']);
      expect(m.rights.transactionInfo, 'this is an example');
      expect(m.rights.aux!.ageVerificationDate, DateTime(1999, 7, 20));
      expect(m.rights.aux!.requiredAge, 18);
      expect(m.rights.aux!.validityDate, DateTime(2017, 7, 20));
      expect(m.rights.aux!.communityId, '02760400110000');
    });

    test('ACCESS_RIGHTS minimal has no error and no aux', () {
      final m = Message.parse(ex.accessRightsMinimal) as AccessRightsMessage;
      expect(m.error, isNull);
      expect(m.rights.aux, isNull);
      expect(m.rights.required, ['Address', 'FamilyName']);
    });

    test('API_LEVEL lists available and current level', () {
      final m = Message.parse(ex.apiLevel) as ApiLevelMessage;
      expect(m.available, [1, 2, 3]);
      expect(m.current, 3);
      expect(m.error, isNotNull);
    });

    test('AUTH with error has no result', () {
      final m = Message.parse(ex.authError) as AuthMessage;
      expect(m.error, 'error message if RUN_AUTH failed');
      expect(m.result, isNull);
    });

    test('AUTH ok is a success and carries the url', () {
      final m = Message.parse(ex.authOk) as AuthMessage;
      expect(m.result!.isSuccess, isTrue);
      expect(
        m.result!.url,
        Uri.parse(
          'https://test.governikus-eid.de/Autent-DemoApplication/refresh-address?sessionId=123456789&ResultMajor=ok',
        ),
      );
    });

    test('AUTH failed is not a success and carries reason and language', () {
      final m = Message.parse(ex.authFailed) as AuthMessage;
      expect(m.result!.isSuccess, isFalse);
      expect(m.result!.reason, 'Card_Removed');
      expect(m.result!.language, 'en');
      expect(m.result!.minor, isNotNull);
    });

    test('BAD_STATE names the offending command', () {
      final m = Message.parse(ex.badState) as BadStateMessage;
      expect(m.error, 'NAME_OF_YOUR_COMMAND');
    });

    test('CERTIFICATE exposes description and validity', () {
      final m = Message.parse(ex.certificate) as CertificateMessage;
      expect(m.certificate.subjectName, 'Governikus Service GmbH');
      expect(m.certificate.purpose, 'Demonstration des eID-Service');
      expect(m.certificate.issuerName, 'Governikus Test DVCA');
      expect(m.certificate.effectiveDate, DateTime(2016, 7, 31));
      expect(m.certificate.expirationDate, DateTime(2016, 8, 30));
    });

    test('CHANGE_PIN success', () {
      final m = Message.parse(ex.changePinOk) as ChangePinMessage;
      expect(m.success, isTrue);
      expect(m.reason, isNull);
    });

    test('CHANGE_PIN failure carries the reason', () {
      final m = Message.parse(ex.changePinFailed) as ChangePinMessage;
      expect(m.success, isFalse);
      expect(m.reason, 'Card_Removed');
    });

    test('ENTER_CAN carries error and reader', () {
      final m = Message.parse(ex.enterCan) as EnterCanMessage;
      expect(m.error, 'You must provide 6 digits');
      expect(m.reader.name, 'NFC');
      expect(m.reader.card!.retryCounter, 1);
    });

    test('ENTER_PIN carries reader with retry counter 3', () {
      final m = Message.parse(ex.enterPin) as EnterPinMessage;
      expect(m.reader.card!.retryCounter, 3);
    });

    test('ENTER_NEW_PIN carries reader', () {
      final m = Message.parse(ex.enterNewPin) as EnterNewPinMessage;
      expect(m.error, 'You must provide 6 digits');
      expect(m.reader.name, 'NFC');
    });

    test('ENTER_PUK carries error and retry counter 0', () {
      final m = Message.parse(ex.enterPuk) as EnterPukMessage;
      expect(m.error, 'You must provide 10 digits');
      expect(m.reader.card!.retryCounter, 0);
    });

    test('INFO exposes version info and AusweisApp state', () {
      final m = Message.parse(ex.info) as InfoMessage;
      expect(m.versionInfo!.name, 'AusweisApp2');
      expect(m.versionInfo!.implementationVersion, '2.0.0');
      expect(m.versionInfo!.specificationTitle, 'TR-03124-1');
      expect(m.ausweisApp, 'CONNECTED');
    });

    test('INSERT_CARD carries error', () {
      final m = Message.parse(ex.insertCard) as InsertCardMessage;
      expect(m.error, 'Name cannot be undefined');
    });

    test('INTERNAL_ERROR carries error', () {
      final m = Message.parse(ex.internalError) as InternalErrorMessage;
      expect(m.error, 'Unexpected condition');
    });

    test('INVALID carries error', () {
      final m = Message.parse(ex.invalid) as InvalidMessage;
      expect(m.error, 'unterminated string (offset: 12)');
    });

    test('READER with eID card', () {
      final m = Message.parse(ex.readerEid) as ReaderMessage;
      expect(m.reader.card!.retryCounter, 3);
      expect(m.reader.card!.isUnknown, isFalse);
      expect(m.reader.keypad, isFalse);
      expect(m.reader.attached, isTrue);
      expect(m.reader.insertable, isFalse);
    });

    test('READER with unknown card has an empty card object', () {
      final m = Message.parse(ex.readerUnknownCard) as ReaderMessage;
      expect(m.reader.card, isNotNull);
      expect(m.reader.card!.isUnknown, isTrue);
    });

    test('READER without card has card == null', () {
      final m = Message.parse(ex.readerNoCard) as ReaderMessage;
      expect(m.reader.card, isNull);
    });

    test('READER_LIST has two readers', () {
      final m = Message.parse(ex.readerList) as ReaderListMessage;
      expect(m.readers, hasLength(2));
      expect(m.readers.first.keypad, isTrue);
      expect(m.readers.first.card, isNull);
      expect(m.readers.last.name, 'NFC');
    });

    test('STATUS carries workflow, progress and state', () {
      final m = Message.parse(ex.status) as StatusMessage;
      expect(m.workflow, 'AUTH');
      expect(m.progress, 25);
      expect(m.state, 'ACCESS_RIGHTS');
    });

    test('PAUSE carries the cause', () {
      final m = Message.parse(ex.pause) as PauseMessage;
      expect(m.cause, PauseCause.badCardPosition);
    });

    test('UNKNOWN_COMMAND names the unknown command', () {
      final m = Message.parse(ex.unknownCommand) as UnknownCommandMessage;
      expect(m.error, 'get_INFo');
    });
  });

  group('robustness', () {
    test(
      'reader without insertable (workflow.rst) parses with insertable == false',
      () {
        final m = Message.parse(
          '{"msg":"ENTER_PIN","reader":{"attached":true,"card":'
          '{"inoperative":false,"deactivated":false,"retryCounter":3},"keypad":false,"name":"NFC"}}',
        );
        expect((m as EnterPinMessage).reader.insertable, isFalse);
      },
    );

    test('unknown fields are ignored', () {
      expect(
        Message.parse(
          '{"msg":"PAUSE","cause":"BadCardPosition","new":{"a":1}}',
        ),
        isA<PauseMessage>(),
      );
    });

    test('unknown pause cause is kept as text', () {
      expect(
        (Message.parse('{"msg":"PAUSE","cause":"Later"}') as PauseMessage)
            .cause,
        'Later',
      );
    });

    test('requiredAge accepts a number', () {
      final m =
          Message.parse(
                '{"msg":"ACCESS_RIGHTS","chat":{"effective":[],"optional":[],"required":[]},'
                '"aux":{"requiredAge":21}}',
              )
              as AccessRightsMessage;
      expect(m.rights.aux!.requiredAge, 21);
    });

    for (final raw in [
      '',
      'not json',
      '[]',
      '42',
      '{}',
      '{"msg":7}',
      '{"msg":"FUTURE_MSG","x":1}',
      '{"msg":"ENTER_PIN"}',
      '{"msg":"READER","name":5}',
      '{"msg":"API_LEVEL","available":"3"}',
    ]) {
      test('"$raw" becomes UnknownMessage with the raw text', () {
        expect((Message.parse(raw) as UnknownMessage).raw, raw);
      });
    }

    test('STATUS with null fields parses', () {
      final m =
          Message.parse(
                '{"msg":"STATUS","workflow":null,"progress":null,"state":null}',
              )
              as StatusMessage;
      expect([m.workflow, m.progress, m.state], [null, null, null]);
    });
  });
}
