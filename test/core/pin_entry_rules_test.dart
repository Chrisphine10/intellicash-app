import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/meeting_unlock.dart';

/// Setting a PIN and entering one are different questions.
///
/// The unlock sheet ran one `isValidPin` guard for both. That demands exactly
/// four digits and refuses guessable values — right for choosing, wrong for
/// typing — so a member holding a six-digit PIN, or a four-digit one that
/// happened to be guessable, could not get in at all. The error even said "must
/// be exactly 6 digits" while the check demanded four.
///
/// These assert the two rules stay apart. There is no widget test over the
/// sheet itself, which is exactly why the contradiction shipped.
void main() {
  group('a PIN somebody already holds must remain enterable', () {
    test('even when it is six digits', () {
      expect(MeetingUnlock.isEnterablePin('048271'), isTrue);
      expect(MeetingUnlock.isValidPin('048271'), isFalse,
          reason: 'still cannot be CHOSEN');
    });

    test('even when it is guessable', () {
      for (final pin in ['1234', '0000', '4321']) {
        expect(MeetingUnlock.isEnterablePin(pin), isTrue, reason: pin);
        expect(MeetingUnlock.isValidPin(pin), isFalse, reason: pin);
      }
    });
  });

  group('a PIN being chosen is held to the stricter rule', () {
    test('four digits, not guessable', () {
      expect(MeetingUnlock.isValidPin('0427'), isTrue);
      expect(MeetingUnlock.isValidPin('042'), isFalse);
      expect(MeetingUnlock.isValidPin('04271'), isFalse);
    });
  });

  test('the two rules are not the same function', () {
    // If these ever collapse into one, the lockout returns.
    final divergent = ['048271', '1234', '0000'];
    for (final pin in divergent) {
      expect(MeetingUnlock.isEnterablePin(pin) == MeetingUnlock.isValidPin(pin),
          isFalse,
          reason: '$pin must be enterable but not choosable');
    }
  });
}
