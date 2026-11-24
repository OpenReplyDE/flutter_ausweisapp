import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAusweisAppTransport transport;
  late List<String> lines;

  setUp(() {
    transport = FakeAusweisAppTransport();
    lines = [];
  });

  AusweisApp create({AusweisAppLogger? logger}) {
    final eid = AusweisApp(transport: transport, logger: logger);
    addTearDown(eid.dispose);
    return eid;
  }

  test('without a logger nothing is written', () async {
    final eid = create();
    await eid.start();
    await eid.getInfo();
    transport.emit({'msg': 'INFO'});
    await pumpEventQueue();
    expect(lines, isEmpty);
  });

  test('logger receives "-> " lines for commands and "<- " lines for '
      'messages', () async {
    final eid = create(logger: lines.add);
    await eid.start();
    lines.clear();
    await eid.getStatus();
    transport.emitRaw('{"msg":"STATUS", "workflow":null}');
    await pumpEventQueue();
    expect(lines, [
      '-> {"cmd":"GET_STATUS"}',
      '<- {"msg":"STATUS", "workflow":null}',
    ]);
  });

  test(
    'the SET_API_LEVEL sent by start is logged, followed by the answer',
    () async {
      final eid = create(logger: lines.add);
      await eid.start();
      expect(lines.first, '-> {"cmd":"SET_API_LEVEL","level":3}');
      expect(lines[1], startsWith('<- '));
      expect(lines[1], contains('API_LEVEL'));
    },
  );

  test('PIN, CAN, PUK and new PIN never reach the logger', () async {
    final eid = create(logger: lines.add);
    await eid.start();
    await eid.setPin('111111');
    await eid.setCan('222222');
    await eid.setPuk('3333333333');
    await eid.setNewPin('444444');
    await eid.sendRaw({'cmd': 'SET_PIN', 'value': '555555'});
    expect(lines.where((l) => l.contains('SET_')).length, 6);
    expect(
      lines.join('\n'),
      isNot(matches(RegExp('111111|222222|3333333333|444444|555555'))),
    );
  });

  test('header values never reach the logger', () async {
    final eid = create(logger: lines.add);
    await eid.start();
    await eid.startAuthentication(
      tcTokenUrl: Uri.parse('https://a.example/t'),
      headers: {'Authorization': 'Bearer secret'},
    );
    expect(lines.join('\n'), contains('Authorization'));
    expect(lines.join('\n'), isNot(contains('secret')));
  });

  test(
    'a command rejected because the SDK is not running is not logged',
    () async {
      final eid = create(logger: lines.add);
      await expectLater(
        eid.setPin('111111'),
        throwsA(isA<AusweisAppNotRunningException>()),
      );
      expect(lines, isEmpty);
    },
  );

  test(
    'a throwing logger does not break sending or the event stream',
    () async {
      final eid = create(logger: (_) => throw StateError('log failed'));
      final events = <AusweisAppEvent>[];
      eid.events.listen(events.add);
      await eid.start();
      await eid.getInfo();
      transport.emit({'msg': 'INFO'});
      await pumpEventQueue();
      expect(transport.sent.last, {'cmd': 'GET_INFO'});
      expect(events, isNotEmpty);
      expect(events.last, isA<InfoReceived>());
    },
  );
}
