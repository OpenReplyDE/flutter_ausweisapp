import 'dart:io';

import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:flutter_ausweisapp/src/failure.dart' show failureKindsByReason;
import 'package:flutter_ausweisapp/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _error = 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error';
const _ok = 'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok';

/// The failure codes of the SDK documentation with the text that follows
/// each of them.
Map<String, String> _documentedCodes() {
  final lines = File(
    'AusweisApp-community/docs/failurecodes/failurecodes.rst',
  ).readAsLinesSync();
  final entry = RegExp(r'^\s*- \| \*\*(\w+)\*\*\s*$');
  final codes = <String, String>{};
  String? current;
  for (final line in lines) {
    final match = entry.firstMatch(line);
    if (match != null) {
      current = match.group(1)!;
      codes[current] = '';
    } else if (line.startsWith('.. _')) {
      current = null;
    } else if (current != null) {
      codes[current] = '${codes[current]}$line\n';
    }
  }
  return codes;
}

Set<String> _reasonsOf(FailureKind kind) => {
  for (final MapEntry(:key, :value) in failureKindsByReason.entries)
    if (value == kind) key,
};

void main() {
  group('FailureKind.fromReason', () {
    test('network: a network error while fetching the tcToken', () {
      expect(
        FailureKind.fromReason('Get_TcToken_Network_Error'),
        FailureKind.network,
      );
      expect(
        FailureKind.fromReason('Generic_Send_Receive_Network_Error'),
        FailureKind.network,
      );
    });

    test('timeout: the return address did not answer in time', () {
      expect(
        FailureKind.fromReason('Check_Refresh_Address_Service_Timeout'),
        FailureKind.timeout,
      );
      expect(
        FailureKind.fromReason('Change_Pin_Input_Timeout'),
        FailureKind.timeout,
      );
    });

    test('userCancelled: the user cancelled the workflow', () {
      expect(
        FailureKind.fromReason('User_Cancelled'),
        FailureKind.userCancelled,
      );
    });

    test('cardConnection: the card was removed or could not be reached', () {
      expect(
        FailureKind.fromReason('Card_Removed'),
        FailureKind.cardConnection,
      );
      // Reported on an iPhone when the card is pulled away while reading.
      expect(
        FailureKind.fromReason('Transmit_Card_Command_Failed'),
        FailureKind.cardConnection,
      );
      expect(
        FailureKind.fromReason('Did_Authenticate_Eac2_Card_Command_Failed'),
        FailureKind.cardConnection,
      );
    });

    test('other: a documented code outside the other kinds', () {
      expect(
        FailureKind.fromReason(
          'Process_Certificates_From_Eac2_Cvc_Chain_Missing',
        ),
        FailureKind.other,
      );
      expect(
        FailureKind.fromReason('Get_TcToken_ServiceUnavailable'),
        FailureKind.other,
      );
    });

    test('other: an unknown, empty or missing code', () {
      expect(FailureKind.fromReason('Not_A_Code'), FailureKind.other);
      expect(FailureKind.fromReason(''), FailureKind.other);
      expect(FailureKind.fromReason(null), FailureKind.other);
    });

    test('codes are matched exactly, including case', () {
      expect(FailureKind.fromReason('user_cancelled'), FailureKind.other);
    });
  });

  group('the mapping against the SDK documentation', () {
    final documented = _documentedCodes();

    test('the documentation is read', () {
      expect(documented, contains('User_Cancelled'));
      expect(documented.length, greaterThan(80));
    });

    test('every mapped code is a documented failure code', () {
      expect(documented.keys, containsAll(failureKindsByReason.keys));
    });

    test('no code is mapped to other; other is the fallback', () {
      expect(failureKindsByReason.values, isNot(contains(FailureKind.other)));
    });

    test('timeout holds the codes that name a timeout', () {
      expect(_reasonsOf(FailureKind.timeout), {
        for (final code in documented.keys)
          if (code.contains('Timeout')) code,
      });
    });

    test('network holds the codes whose solution is "Fix connection '
        'problems", except the timeout', () {
      expect(_reasonsOf(FailureKind.network), {
        for (final MapEntry(:key, :value) in documented.entries)
          if (value.contains('failure_code_fix_connections_problems') &&
              !key.contains('Timeout'))
            key,
      });
    });

    test('userCancelled holds the codes named after a cancellation', () {
      expect(_reasonsOf(FailureKind.userCancelled), {
        for (final code in documented.keys)
          if (code.endsWith('User_Cancelled')) code,
      });
    });

    test('cardConnection holds the codes whose solution is "Check ID card '
        'position"', () {
      expect(_reasonsOf(FailureKind.cardConnection), {
        for (final MapEntry(:key, :value) in documented.entries)
          if (value.contains('failure_code_card_position')) key,
      });
      expect(_reasonsOf(FailureKind.cardConnection), contains('Card_Removed'));
    });
  });

  group('AuthResult.failureKind', () {
    test('is null for a successful result', () {
      expect(const AuthResult(major: _ok).failureKind, isNull);
    });

    test('classifies the reason of a failed result', () {
      const result = AuthResult(
        major: _error,
        minor:
            'http://www.bsi.bund.de/ecard/api/1.1/resultminor/al/common#internalError',
        reason: 'Card_Removed',
      );
      expect(result.failureKind, FailureKind.cardConnection);
      expect(result.reason, 'Card_Removed');
    });

    test('goes by the reason, not by the minor code', () {
      // Observed on an iPhone: pulling the card away reports this pair.
      const result = AuthResult(
        major: _error,
        minor:
            'http://www.bsi.bund.de/ecard/api/1.1/resultminor/sal#cancellationByUser',
        reason: 'Did_Authenticate_Eac2_Card_Command_Failed',
      );
      expect(result.failureKind, FailureKind.cardConnection);
    });

    test('is other for a failed result without a reason', () {
      expect(const AuthResult(major: _error).failureKind, FailureKind.other);
      expect(const AuthResult().failureKind, FailureKind.other);
    });

    test('is set on the event built from an AUTH message', () {
      final event = AusweisAppEvent.fromMessage(
        Message.parse(
          '{"msg":"AUTH","result":{"major":"$_error",'
          '"reason":"Get_TcToken_Network_Error"},"url":"https://example.org/"}',
        ),
      );
      expect(
        (event as AuthenticationCompleted).result.failureKind,
        FailureKind.network,
      );
    });
  });

  group('ChangePinCompleted.failureKind', () {
    test('is null after a successful PIN change', () {
      expect(const ChangePinCompleted(success: true).failureKind, isNull);
    });

    test('classifies the reason of a failed PIN change', () {
      expect(
        const ChangePinCompleted(
          success: false,
          reason: 'User_Cancelled',
        ).failureKind,
        FailureKind.userCancelled,
      );
      expect(
        const ChangePinCompleted(success: false).failureKind,
        FailureKind.other,
      );
    });
  });

  group('AusweisAppException.failureKind', () {
    test('timeout: start() did not finish in time', () {
      const error = AusweisAppStartException('timeout', 'too slow');
      expect(error.failureKind, FailureKind.timeout);
      expect(error.code, 'timeout');
    });

    test('other: the remaining start errors', () {
      expect(
        const AusweisAppStartException('start_failed', '').failureKind,
        FailureKind.other,
      );
      expect(
        const AusweisAppStartException('api_level', '').failureKind,
        FailureKind.other,
      );
    });

    test('timeout: stop() did not finish in time', () {
      expect(
        const AusweisAppTransportException('timeout', '').failureKind,
        FailureKind.timeout,
      );
    });

    test('other: transport errors and a stopped SDK', () {
      expect(
        const AusweisAppTransportException('send_failed', '').failureKind,
        FailureKind.other,
      );
      expect(
        const AusweisAppNotRunningException().failureKind,
        FailureKind.other,
      );
    });

    test(
      'is timeout on the error that start() throws when it times out',
      () async {
        final eid = AusweisApp(
          transport: FakeAusweisAppTransport()..hangOnStart = true,
        );
        addTearDown(eid.dispose);
        try {
          await eid.start(timeout: const Duration(milliseconds: 10));
          fail('expected an error');
        } on AusweisAppException catch (error) {
          expect(error.code, 'timeout');
          expect(error.failureKind, FailureKind.timeout);
        }
      },
    );
  });
}
