/// NFC state over the plugin's MethodChannel.
library;

import 'package:flutter/services.dart';

import '../errors.dart';
import 'nfc.dart';

/// Asks the native plugin code. Uses the method channel of the plugin, which
/// answers from the moment the Flutter engine runs, also while the SDK is
/// stopped.
///
/// A failure of the platform call is thrown as
/// [AusweisAppTransportException].
class MethodChannelAusweisAppNfc implements AusweisAppNfc {
  const MethodChannelAusweisAppNfc();

  static const _methods = MethodChannel('flutter_ausweisapp/methods');

  @override
  Future<NfcStatus> status() async {
    final answer = await _invoke<String>('nfcStatus');
    return switch (answer) {
      'unsupported' => NfcStatus.unsupported,
      'disabled' => NfcStatus.disabled,
      'available' => NfcStatus.available,
      _ => throw const AusweisAppTransportException(
        'nfc_status',
        'The platform reported no known NFC status.',
      ),
    };
  }

  @override
  Future<bool> openSettings() async =>
      await _invoke<bool>('openNfcSettings') ?? false;

  static Future<T?> _invoke<T>(String method) async {
    try {
      return await _methods.invokeMethod<T>(method);
    } on PlatformException catch (e) {
      throw AusweisAppTransportException(e.code, e.message ?? '');
    }
  }
}
