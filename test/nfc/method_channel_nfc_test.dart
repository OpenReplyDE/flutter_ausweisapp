import 'package:flutter/services.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('flutter_ausweisapp/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelAusweisAppNfc nfc;
  late List<String> calls;
  Future<Object?> Function(MethodCall call)? onCall;

  setUp(() {
    nfc = MethodChannelAusweisAppNfc();
    calls = [];
    onCall = null;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      return onCall == null ? null : onCall!(call);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  Future<Object> captureError(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      return e;
    }
    fail('expected an error');
  }

  group('status', () {
    for (final (answer, status) in [
      ('unsupported', NfcStatus.unsupported),
      ('disabled', NfcStatus.disabled),
      ('available', NfcStatus.available),
    ]) {
      test('maps "$answer" to $status', () async {
        onCall = (_) async => answer;
        expect(await nfc.status(), status);
        expect(calls, ['nfcStatus']);
      });
    }

    test('needs no start: it is the only call on the channel', () async {
      onCall = (_) async => 'available';
      await nfc.status();
      expect(calls, isNot(contains('start')));
    });

    test('throws AusweisAppTransportException for an unknown answer', () async {
      onCall = (_) async => 'maybe';
      final error = await captureError(nfc.status);
      expect(error, isA<AusweisAppTransportException>());
      expect((error as AusweisAppTransportException).code, 'nfc_status');
    });

    test('throws AusweisAppTransportException for no answer', () async {
      final error = await captureError(nfc.status);
      expect(error, isA<AusweisAppTransportException>());
    });

    test('maps a PlatformException to AusweisAppTransportException', () async {
      onCall = (_) async =>
          throw PlatformException(code: 'nfc_failed', message: 'broken');
      final error = await captureError(nfc.status);
      expect(error, isA<AusweisAppTransportException>());
      expect((error as AusweisAppTransportException).code, 'nfc_failed');
      expect(error.message, 'broken');
    });
  });

  group('openSettings', () {
    test('returns true when the platform opened the settings', () async {
      onCall = (_) async => true;
      expect(await nfc.openSettings(), isTrue);
      expect(calls, ['openNfcSettings']);
    });

    test('returns false when the platform has no NFC settings', () async {
      onCall = (_) async => false;
      expect(await nfc.openSettings(), isFalse);
    });

    test('returns false for no answer', () async {
      expect(await nfc.openSettings(), isFalse);
    });

    test('maps a PlatformException to AusweisAppTransportException', () async {
      onCall = (_) async => throw PlatformException(code: 'nfc_failed');
      final error = await captureError(nfc.openSettings);
      expect(error, isA<AusweisAppTransportException>());
      expect((error as AusweisAppTransportException).code, 'nfc_failed');
    });
  });
}
