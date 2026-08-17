import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/meeting_unlock.dart';
import 'package:intellicash_mobile/data/models/member.dart';

/// The meeting PIN is now four digits, chosen by the member.
///
/// That is two weakenings at once: the space shrinks from a million to ten
/// thousand, and a chosen PIN clusters far harder than a generated one. The
/// rules below are what is left holding it up, so they are tested rather than
/// assumed — the first version of the all-same-digit check was a regex whose
/// escaped dollar matched a literal `$`, so it never fired and nothing said so.
void main() {
  group('setting a PIN', () {
    test('accepts four digits', () {
      for (final pin in ['0427', '9081', '5309', '2604']) {
        expect(MeetingUnlock.isValidPin(pin), isTrue, reason: pin);
      }
    });

    test('refuses anything that is not exactly four digits', () {
      for (final pin in ['', '1', '042', '04277', '123456', 'abcd', '04 7', '04a7']) {
        expect(MeetingUnlock.isValidPin(pin), isFalse, reason: '"$pin"');
      }
    });

    test('refuses the PINs everyone reaches for first', () {
      // All the same digit.
      for (final pin in ['0000', '1111', '5555', '9999']) {
        expect(MeetingUnlock.isValidPin(pin), isFalse, reason: pin);
        expect(MeetingUnlock.isGuessablePin(pin), isTrue, reason: pin);
      }
      // Runs, in both directions.
      for (final pin in ['1234', '0123', '6789', '4321', '9876']) {
        expect(MeetingUnlock.isValidPin(pin), isFalse, reason: pin);
        expect(MeetingUnlock.isGuessablePin(pin), isTrue, reason: pin);
      }
    });

    test('does not over-reach: near-runs and repeats are fine', () {
      // Three keys have to be memorable enough to actually be used. Only the
      // obvious patterns are refused, not everything with a repeated digit.
      for (final pin in ['1235', '1224', '1122', '2468', '1357', '0110']) {
        expect(MeetingUnlock.isValidPin(pin), isTrue, reason: pin);
      }
    });

    test('a six-digit PIN can no longer be set', () {
      expect(MeetingUnlock.isValidPin('048271'), isFalse);
    });
  });

  group('entering a PIN', () {
    test('still accepts the old six-digit length', () {
      // Every member who set a PIN before this change holds a six-digit one.
      // Refusing it here would lock every existing group out of its own
      // meetings the moment they updated the app.
      expect(MeetingUnlock.isEnterablePin('048271'), isTrue);
      expect(MeetingUnlock.isEnterablePin('0427'), isTrue);
    });

    test('accepts a guessable one, because it may already be someone\'s', () {
      // The guessable rule governs what may be CHOSEN. Applying it on entry
      // would strand anyone who chose badly before the rule existed.
      expect(MeetingUnlock.isEnterablePin('1234'), isTrue);
      expect(MeetingUnlock.isValidPin('1234'), isFalse);
    });

    test('refuses lengths that were never valid', () {
      for (final pin in ['12345', '123', '']) {
        expect(MeetingUnlock.isEnterablePin(pin), isFalse, reason: '"$pin"');
      }
    });
  });

  test('hashing is salted per member, so equal PINs do not hash equal', () {
    expect(
      MeetingUnlock.hashPin('member-a', '0427'),
      isNot(MeetingUnlock.hashPin('member-b', '0427')),
    );
  });

  group('PIN hashing', () {
    test('a new hash is PBKDF2, not a bare SHA-256', () {
      final hash = MeetingUnlock.hashPin('m1', '0427');
      expect(hash.startsWith('pbkdf2-sha256\$30000\$'), isTrue, reason: hash);
      // The old scheme was 64 hex characters and nothing else.
      expect(RegExp(r'^[0-9a-f]{64}\$').hasMatch(hash), isFalse);
    });

    test('salts randomly, so the same PIN never hashes the same twice', () {
      // The old scheme salted on member id alone, which is not secret and is
      // reused wherever the member appears — so it forced no extra work.
      expect(
        MeetingUnlock.hashPin('m1', '0427'),
        isNot(MeetingUnlock.hashPin('m1', '0427')),
      );
    });

    test('verifies a PIN it hashed', () {
      final member = _memberWithHash('m1', MeetingUnlock.hashPin('m1', '0427'));
      expect(MeetingUnlock.verifyPin(member, '0427'), isTrue);
      expect(MeetingUnlock.verifyPin(member, '0428'), isFalse);
    });

    test('will not verify another member PIN', () {
      final member = _memberWithHash('m2', MeetingUnlock.hashPin('m1', '0427'));
      expect(MeetingUnlock.verifyPin(member, '0427'), isFalse);
    });

    test('still verifies a PIN hashed the old way', () {
      // Every member who set a PIN before this holds a SHA-256 hash. Refusing
      // it would lock every existing group out of its own meetings.
      final legacy = MeetingUnlock.legacyHashPin('m1', '048271');
      final member = _memberWithHash('m1', legacy);
      expect(MeetingUnlock.verifyPin(member, '048271'), isTrue);
      expect(MeetingUnlock.verifyPin(member, '048272'), isFalse);
    });

    test('flags a legacy hash for upgrade, and a new one as done', () {
      expect(MeetingUnlock.needsRehash(MeetingUnlock.legacyHashPin('m1', '0427')), isTrue);
      expect(MeetingUnlock.needsRehash(MeetingUnlock.hashPin('m1', '0427')), isFalse);
      expect(MeetingUnlock.needsRehash(null), isFalse);
      expect(MeetingUnlock.needsRehash(''), isFalse);
    });

    test('refuses a malformed stored value instead of throwing', () {
      for (final broken in ['pbkdf2-sha256\$', 'pbkdf2-sha256\$x\$y\$z', 'pbkdf2-sha256\$0\$s\$h']) {
        final member = _memberWithHash('m1', broken);
        expect(MeetingUnlock.verifyPin(member, '0427'), isFalse, reason: broken);
      }
    });

    test('matches the published PBKDF2-HMAC-SHA256 vectors', () {
      // The KDF is hand-written, so it is checked against values produced by
      // other implementations. Comparing it only against itself would prove
      // nothing at all.
      expect(
        MeetingUnlock.pbkdf2Hex(password: 'password', salt: 'salt', iterations: 1),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        MeetingUnlock.pbkdf2Hex(password: 'password', salt: 'salt', iterations: 2),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });
  });

}

Member _memberWithHash(String id, String hash) => Member(
      id: id,
      groupId: 'g1',
      name: 'Test Member',
      joinedAt: DateTime(2026, 1, 1),
      pinHash: hash,
    );
