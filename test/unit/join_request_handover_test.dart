import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/network/api_exception.dart';
import 'package:intellicash_mobile/data/models/remote/membership.dart';

void main() {
  group('JoinRequest handover warning', () {
    test('flags a request that would take over existing records', () {
      // The server sets these when the phone is already on the roster. Nothing
      // verifies that phone at sign-up, so the official must be warned.
      final r = JoinRequest.fromJson(const {
        'id': 'req-1',
        'requestedName': 'Not Agnes',
        'phone': '254700000203',
        'willLinkToMemberId': 'member-agnes',
        'willLinkToMemberName': 'Agnes Muthoni',
      });
      expect(r.takesOverExistingRecords, isTrue);
      expect(r.willLinkToMemberName, 'Agnes Muthoni');
      expect(r.willLinkToMemberId, 'member-agnes');
    });

    test('a genuinely new person carries no warning', () {
      final r = JoinRequest.fromJson(const {
        'id': 'req-2',
        'requestedName': 'Peninah Cherono',
        'phone': '254733444555',
      });
      expect(r.takesOverExistingRecords, isFalse);
      expect(r.willLinkToMemberId, isNull);
    });

    test('an older server that sends neither field is treated as no match', () {
      // Failing open here would silently drop the warning, so absence must
      // mean "no handover", never "unknown, proceed".
      final r = JoinRequest.fromJson(const {
        'id': 'req-3',
        'requestedName': 'Someone',
        'phone': '254700000000',
        'willLinkToMemberName': null,
      });
      expect(r.takesOverExistingRecords, isFalse);
    });
  });

  group('ApiException carries the backend reason', () {
    test('keeps the code so one status can mean several things', () {
      // A 409 on a join decision is three different situations; without the
      // code the screen would tell officials the wrong one.
      const clash = ApiException('x', statusCode: 409, code: 'ALREADY_DECIDED');
      const stale = ApiException('x', statusCode: 409, code: 'CONFIRM_EXISTING_MEMBER');
      expect(clash.code, 'ALREADY_DECIDED');
      expect(stale.code, isNot(clash.code));
      expect(clash.statusCode, stale.statusCode);
    });

    test('is optional, so existing throw sites still compile and behave', () {
      const e = ApiException('offline', statusCode: 0);
      expect(e.code, isNull);
      expect(e.isNetworkError, isTrue);
    });
  });
}
