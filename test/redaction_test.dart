import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('value is redacted in every command', () {
    expect(
      redactCommand({'cmd': 'SET_PIN', 'value': '123456'}),
      '{"cmd":"SET_PIN","value":"***"}',
    );
    expect(
      redactCommand({'cmd': 'FUTURE', 'value': '99'}),
      isNot(contains('99')),
    );
  });

  test('header values are redacted, header names are kept', () {
    final line = redactCommand({
      'cmd': 'RUN_AUTH',
      'tcTokenURL': 'https://a.example/t',
      'header': {'Authorization': 'Bearer secret'},
    });
    expect(line, contains('Authorization'));
    expect(line, isNot(contains('secret')));
    expect(line, contains('"Authorization":"***"'));
  });

  test('other fields stay readable', () {
    expect(
      redactCommand({'cmd': 'SET_API_LEVEL', 'level': 3}),
      '{"cmd":"SET_API_LEVEL","level":3}',
    );
  });

  test('non-string value and header are redacted as the string ***', () {
    expect(
      redactCommand({'cmd': 'X', 'value': 123456}),
      '{"cmd":"X","value":"***"}',
    );
    expect(
      redactCommand({
        'cmd': 'X',
        'value': {'pin': '123456'},
      }),
      '{"cmd":"X","value":"***"}',
    );
    final line = redactCommand({
      'cmd': 'RUN_AUTH',
      'header': {
        'Authorization': 7777,
        'X-Nested': {'t': 'tok'},
      },
    });
    expect(line, isNot(contains('7777')));
    expect(line, isNot(contains('tok')));
    expect(line, contains('"X-Nested":"***"'));
    expect(
      redactCommand({'cmd': 'RUN_AUTH', 'header': 'Bearer abc'}),
      '{"cmd":"RUN_AUTH","header":"***"}',
    );
  });

  test('a null value stays null, as it asks a reader with keypad', () {
    expect(
      redactCommand({'cmd': 'SET_PIN', 'value': null}),
      '{"cmd":"SET_PIN","value":null}',
    );
  });

  test('redactCommand leaves its input unchanged', () {
    final header = {'Authorization': 'Bearer secret'};
    final command = <String, Object?>{
      'cmd': 'RUN_AUTH',
      'value': '123456',
      'header': header,
    };
    redactCommand(command);
    expect(command['value'], '123456');
    expect(command['header'], same(header));
    expect(header, {'Authorization': 'Bearer secret'});
  });
}
