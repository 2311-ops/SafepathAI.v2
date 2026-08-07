// Behavior under test (quick 260807-rk2):
// - SosSession.fromJson reads the sender's number when the wire carries it,
//   and yields null when the key is absent or explicitly null
// - sosDialUri returns a tel-scheme URI whose path is the sender's E.164
//   string when one is present
// - sosDialUri returns a tel-scheme URI with an empty path when the number
//   is null or blank, reproducing today's bare-dialler fallback exactly

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/sos/data/sos_models.dart';
import 'package:mobile/features/sos/presentation/responder_alert_screen.dart';

Map<String, dynamic> _sessionJson({String? phoneNumber}) {
  final json = <String, dynamic>{
    'sosSessionId': 'session-1',
    'familyId': 'family-1',
    'triggeredByUserId': 'ana-user-id',
    'status': 'Active',
    'triggeredAtUtc': DateTime.utc(2026, 1, 1).toIso8601String(),
    'receivedAtUtc': DateTime.utc(2026, 1, 1).toIso8601String(),
    'triggeredByPhoneNumberE164': phoneNumber,
  };
  return json;
}

void main() {
  group('SosSession.fromJson phone-number wire parsing', () {
    test("reads the sender's number when the wire carries it", () {
      final session = SosSession.fromJson(
        _sessionJson(phoneNumber: '+12025550173'),
      );

      expect(session.triggeredByPhoneNumberE164, '+12025550173');
    });

    test('yields null when the key is absent (pre-260807-rk2 server)', () {
      final json = _sessionJson()..remove('triggeredByPhoneNumberE164');

      final session = SosSession.fromJson(json);

      expect(session.triggeredByPhoneNumberE164, isNull);
    });

    test('yields null when the key is explicitly null', () {
      final session = SosSession.fromJson(_sessionJson(phoneNumber: null));

      expect(session.triggeredByPhoneNumberE164, isNull);
    });
  });

  group('sosDialUri', () {
    test('returns a tel-scheme URI whose path is the number when present', () {
      final uri = sosDialUri('+12025550173');

      expect(uri.scheme, 'tel');
      expect(uri.path, '+12025550173');
    });

    test(
      'returns a tel-scheme URI with an empty path when the number is null',
      () {
        final uri = sosDialUri(null);

        expect(uri.scheme, 'tel');
        expect(uri.path, '');
      },
    );

    test(
      'returns a tel-scheme URI with an empty path when the number is blank',
      () {
        final uri = sosDialUri('   ');

        expect(uri.scheme, 'tel');
        expect(uri.path, '');
      },
    );
  });
}
