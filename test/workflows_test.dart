// Replays the workflows of AusweisApp-community/docs/sdk/workflow.rst.
// Every `msg` and `cmd` line is copied unchanged from that file.

import 'dart:convert';

import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fields the plugin always sends with RUN_AUTH and RUN_CHANGE_PIN.
const runAuthDefaults = {'developerMode': false, 'status': true};
const runChangePinDefaults = {'status': true};

void main() {
  late FakeAusweisAppTransport fake;
  late AusweisApp eid;
  late List<AusweisAppEvent> seen;

  setUp(() async {
    fake = FakeAusweisAppTransport();
    eid = AusweisApp(transport: fake);
    seen = [];
    final subscription = eid.events
        .where((e) => e is! ApiLevelReceived)
        .listen(seen.add);
    addTearDown(subscription.cancel);
    await eid.start();
  });

  tearDown(() => eid.dispose());

  /// Replays a `cmd` line: [call] must send exactly this one command.
  Future<void> cmd(
    Future<void> Function() call,
    String line, {
    Map<String, Object?> defaults = const {},
  }) async {
    final before = fake.sent.length;
    await call();
    expect(fake.sent, hasLength(before + 1));
    expect(fake.sent.last, {
      ...defaults,
      ...jsonDecode(line) as Map<String, Object?>,
    });
  }

  /// Replays a `msg` line unchanged.
  void msg(String line) => fake.emitRaw(line);

  Matcher pinRequested(int retryCounter) => isA<PinRequested>().having(
    (e) => e.reader.card!.retryCounter,
    'reader.card.retryCounter',
    retryCounter,
  );

  Matcher canRequested(int retryCounter) => isA<CanRequested>().having(
    (e) => e.reader.card!.retryCounter,
    'reader.card.retryCounter',
    retryCounter,
  );

  Matcher accessRights(int effective) => isA<AccessRightsRequested>().having(
    (e) => e.rights.effective,
    'rights.effective',
    hasLength(effective),
  );

  final cancelled = isA<AuthenticationCompleted>()
      .having((e) => e.result.isSuccess, 'result.isSuccess', isFalse)
      .having(
        (e) => e.result.minor,
        'result.minor',
        endsWith('#cancellationByUser'),
      );

  test('Minimal successful authentication', () async {
    await cmd(
      () => eid.startAuthentication(
        tcTokenUrl: Uri.parse(
          'https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request',
        ),
      ),
      r'''{"cmd": "RUN_AUTH", "tcTokenURL": "https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request"}''',
      defaults: runAuthDefaults,
    );
    msg(r'''{"msg": "AUTH"}''');
    msg(
      r'''{"msg": "ACCESS_RIGHTS", "chat": {"effective":["FamilyName","GivenNames","DocumentType"],"optional":["GivenNames"],"required":["FamilyName","DocumentType"]}}''',
    );
    await cmd(eid.accept, r'''{"cmd": "ACCEPT"}''');
    msg(
      r'''{"msg": "ENTER_PIN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":3},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setPin('123456'),
      r'''{"cmd": "SET_PIN", "value": "123456"}''',
    );
    msg(
      r'''{"msg": "AUTH","result": {"major":"http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok"},"url":"https://test.governikus-eid.de/Autent-DemoApplication/refresh-address?sessionId=123456789&ResultMajor=ok"}''',
    );
    await pumpEventQueue();

    expect(seen, [
      isA<AuthenticationStarted>(),
      accessRights(3),
      pinRequested(3),
      isA<AuthenticationCompleted>()
          .having((e) => e.result.isSuccess, 'result.isSuccess', isTrue)
          .having(
            (e) => e.result.url,
            'result.url',
            Uri.parse(
              'https://test.governikus-eid.de/Autent-DemoApplication/refresh-address?sessionId=123456789&ResultMajor=ok',
            ),
          ),
    ]);
  });

  test('Successful authentication with CAN', () async {
    await cmd(
      () => eid.startAuthentication(
        tcTokenUrl: Uri.parse('https://test.governikus-eid.de/DEMO'),
      ),
      r'''{"cmd": "RUN_AUTH", "tcTokenURL": "https://test.governikus-eid.de/DEMO"}''',
      defaults: runAuthDefaults,
    );
    msg(r'''{"msg": "AUTH"}''');
    msg(
      r'''{"msg": "ACCESS_RIGHTS", "chat": {"effective":["DocumentType"],"optional":[],"required":["DocumentType"]}}''',
    );
    await cmd(eid.accept, r'''{"cmd": "ACCEPT"}''');
    msg(r'''{"msg": "INSERT_CARD"}''');
    msg(
      r'''{"msg": "ENTER_PIN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":3},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setPin('000000'),
      r'''{"cmd": "SET_PIN", "value": "000000"}''',
    );
    msg(
      r'''{"msg": "ENTER_PIN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":2},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setPin('000001'),
      r'''{"cmd": "SET_PIN", "value": "000001"}''',
    );
    msg(
      r'''{"msg": "ENTER_CAN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":1},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setCan('000000'),
      r'''{"cmd": "SET_CAN", "value": "000000"}''',
    );
    msg(
      r'''{"msg": "ENTER_CAN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":1},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setCan('654321'),
      r'''{"cmd": "SET_CAN", "value": "654321"}''',
    );
    msg(
      r'''{"msg": "ENTER_PIN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":1},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setPin('123456'),
      r'''{"cmd": "SET_PIN", "value": "123456"}''',
    );
    msg(
      r'''{"msg": "AUTH","result": {"major":"http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok"},"url":"https://test.governikus-eid.de/DEMO/refresh-address?sessionId=123456789&ResultMajor=ok"}''',
    );
    await pumpEventQueue();

    expect(seen, [
      isA<AuthenticationStarted>(),
      isA<AccessRightsRequested>(),
      isA<InsertCardRequested>(),
      pinRequested(3),
      pinRequested(2),
      canRequested(1),
      canRequested(1),
      pinRequested(1),
      isA<AuthenticationCompleted>().having(
        (e) => e.result.isSuccess,
        'result.isSuccess',
        isTrue,
      ),
    ]);
  });

  test('Cancelled authentication', () async {
    await cmd(
      () => eid.startAuthentication(
        tcTokenUrl: Uri.parse('https://test.governikus-eid.de/DEMO'),
      ),
      r'''{"cmd": "RUN_AUTH", "tcTokenURL": "https://test.governikus-eid.de/DEMO"}''',
      defaults: runAuthDefaults,
    );
    msg(r'''{"msg": "AUTH"}''');
    msg(
      r'''{"msg": "ACCESS_RIGHTS", "chat": {"effective":["DocumentType"],"optional":[],"required":["DocumentType"]}}''',
    );
    await cmd(eid.cancel, r'''{"cmd": "CANCEL"}''');
    msg(
      r'''{"msg": "AUTH", "result": {"description":"The process has been cancelled.","language":"en","major":"http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error","message":"The process has been cancelled.","minor":"http://www.bsi.bund.de/ecard/api/1.1/resultminor/sal#cancellationByUser"},"url":"https://test.governikus-eid.de/DEMO/refresh-address?sessionId=123456789&ResultMajor=error&ResultMinor=cancellationByUser"}''',
    );
    await pumpEventQueue();

    expect(seen, [
      isA<AuthenticationStarted>(),
      isA<AccessRightsRequested>(),
      cancelled,
    ]);
  });

  test('Set some access rights', () async {
    await cmd(
      () => eid.startAuthentication(
        tcTokenUrl: Uri.parse('https://test.governikus-eid.de/DEMO'),
      ),
      r'''{"cmd": "RUN_AUTH", "tcTokenURL": "https://test.governikus-eid.de/DEMO"}''',
      defaults: runAuthDefaults,
    );
    msg(r'''{"msg": "AUTH"}''');
    msg(
      r'''{"msg": "ACCESS_RIGHTS", "chat": {"effective":["FamilyName","GivenNames","DocumentType"],"optional":["GivenNames"],"required":["FamilyName","DocumentType"]}}''',
    );
    await cmd(
      () => eid.setAccessRights([]),
      r'''{"cmd": "SET_ACCESS_RIGHTS", "chat": []}''',
    );
    msg(
      r'''{"msg": "ACCESS_RIGHTS", "chat": {"effective":["FamilyName","DocumentType"],"optional":["GivenNames"],"required":["FamilyName","DocumentType"]}}''',
    );
    await cmd(
      () => eid.setAccessRights(['GivenNames']),
      r'''{"cmd": "SET_ACCESS_RIGHTS", "chat": ["GivenNames"]}''',
    );
    msg(
      r'''{"msg": "ACCESS_RIGHTS", "chat": {"effective":["FamilyName","GivenNames","DocumentType"],"optional":["GivenNames"],"required":["FamilyName","DocumentType"]}}''',
    );
    await cmd(eid.cancel, r'''{"cmd": "CANCEL"}''');
    msg(
      r'''{"msg": "AUTH", "result": {"description":"The process has been cancelled.","language":"en","major":"http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error","message":"The process has been cancelled.","minor":"http://www.bsi.bund.de/ecard/api/1.1/resultminor/sal#cancellationByUser"},"url":"https://test.governikus-eid.de/DEMO/refresh-address?sessionId=123456789&ResultMajor=error&ResultMinor=cancellationByUser"}''',
    );
    await pumpEventQueue();

    expect(seen, [
      isA<AuthenticationStarted>(),
      accessRights(3),
      accessRights(2),
      accessRights(3),
      cancelled,
    ]);
  });

  test('Minimal successful PIN change', () async {
    await cmd(
      eid.startChangePin,
      r'''{"cmd": "RUN_CHANGE_PIN"}''',
      defaults: runChangePinDefaults,
    );
    msg(r'''{"msg": "CHANGE_PIN"}''');
    msg(
      r'''{"msg": "ENTER_PIN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":3},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setPin('123456'),
      r'''{"cmd": "SET_PIN", "value": "123456"}''',
    );
    msg(
      r'''{"msg": "ENTER_NEW_PIN", "reader": {"attached":true,"card":{"inoperative":false,"deactivated":false,"retryCounter":3},"keypad":false,"name":"NFC"}}''',
    );
    await cmd(
      () => eid.setNewPin('123456'),
      r'''{"cmd": "SET_NEW_PIN", "value": "123456"}''',
    );
    msg(r'''{"msg": "CHANGE_PIN", "success": true}''');
    await pumpEventQueue();

    expect(seen, [
      isA<ChangePinStarted>(),
      pinRequested(3),
      isA<NewPinRequested>(),
      isA<ChangePinCompleted>().having((e) => e.success, 'success', isTrue),
    ]);
  });
}
