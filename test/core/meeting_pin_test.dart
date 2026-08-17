import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/meeting_unlock.dart';

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
}
