import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/services/member_matching.dart';

RemoteMember _member(String id, String? phone) => RemoteMember(
      id: id,
      fullName: 'Member $id',
      phone: phone,
      role: 'MEMBER',
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

void main() {
  group('normalisePhone', () {
    test('reads every way a Kenyan number gets written', () {
      // Each of these is one line. Letterheads print the fifth form and the
      // dialled international prefix produces the sixth.
      for (final written in [
        '0712345678',
        '+254712345678',
        '254712345678',
        '712345678',
        '2540712345678',
        '+254 (0)712 345 678',
        '00254712345678',
        '+254-0712-345-678',
      ]) {
        expect(normalisePhone(written), '254712345678', reason: written);
      }
    });

    test('does not invent a country code for a foreign number', () {
      // Mangling these would be worse than leaving them alone: two different
      // foreign lines must never collapse into one.
      expect(normalisePhone('+256712345678'), '256712345678');
      expect(normalisePhone('+255712345678'), '255712345678');
      expect(samePhone('+256712345678', '+255712345678'), isFalse);
    });

    test('leaves a too-short number alone rather than padding it', () {
      expect(normalisePhone('0712345'), '0712345');
      expect(samePhone('0712345678', '0712345'), isFalse);
    });

    test('ignores spaces and dashes people type', () {
      expect(normalisePhone('+254 712-345 678'), '254712345678');
    });

    test('an absent number normalises to nothing', () {
      expect(normalisePhone(null), '');
      expect(normalisePhone(''), '');
      expect(normalisePhone('   '), '');
    });
  });

  group('looksLikePhone', () {
    test('accepts the forms people actually type', () {
      // Rejecting these for their spacing tells a member their own number is
      // wrong, which is where sign-up quietly dies.
      for (final written in [
        '0712345678',
        '+254 712 345 678',
        '0712-345-678',
        '+254 (0)712 345 678',
        '00254712345678',
      ]) {
        expect(looksLikePhone(written), isTrue, reason: written);
      }
    });

    test('refuses what could not be a number', () {
      expect(looksLikePhone(null), isFalse);
      expect(looksLikePhone(''), isFalse);
      expect(looksLikePhone('0712345'), isFalse);
      expect(looksLikePhone('abcdefghij'), isFalse);
      // Longer than any real number — the server caps here too, so the app
      // must not accept what would then be turned away.
      expect(looksLikePhone('12345678901234567'), isFalse);
    });
  });

  group('matchRemoteMember', () {
    final roster = [
      _member('cmr-1', '+254700000201'),
      _member('cmr-2', '0700000202'),
      _member('cmr-3', null),
    ];

    test('matches across differing phone formats', () {
      expect(matchRemoteMember('0700000201', roster)?.id, 'cmr-1');
      expect(matchRemoteMember('+254700000202', roster)?.id, 'cmr-2');
      // The letterhead form must still find her savings.
      expect(matchRemoteMember('+254 (0)700 000 201', roster)?.id, 'cmr-1');
      expect(matchRemoteMember('00254700000202', roster)?.id, 'cmr-2');
    });

    test('refuses when the local member has no phone', () {
      // Without a number there is nothing to match on, and guessing would put
      // one member's money under another member's name.
      expect(matchRemoteMember(null, roster), isNull);
      expect(matchRemoteMember('', roster), isNull);
    });

    test('refuses when two people share a number', () {
      final shared = [
        _member('cmr-a', '0700000300'),
        _member('cmr-b', '254700000300'),
      ];
      expect(matchRemoteMember('0700000300', shared), isNull);
    });

    test('returns nothing when nobody on the server has that number', () {
      expect(matchRemoteMember('0799999999', roster), isNull);
    });

    test('does not match a member whose number is missing', () {
      expect(matchRemoteMember('', [_member('cmr-3', null)]), isNull);
    });
  });
}
