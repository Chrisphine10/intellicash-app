import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/meeting_unlock.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/member.dart';

Member _member(String id, {MemberRole role = MemberRole.member, String? pin}) {
  return Member(
    id: id,
    groupId: 'g1',
    name: 'Member $id',
    role: role,
    pinHash: pin == null ? null : MeetingUnlock.hashPin(id, pin),
    joinedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('PIN hashing', () {
    test('same PIN hashes differently per member (salted)', () {
      expect(MeetingUnlock.hashPin('a', '123456'),
          isNot(MeetingUnlock.hashPin('b', '123456')));
    });

    test('verifyPin accepts the right PIN and rejects wrong ones', () {
      final member = _member('m1', pin: '123456');
      expect(MeetingUnlock.verifyPin(member, '123456'), isTrue);
      expect(MeetingUnlock.verifyPin(member, '654321'), isFalse);
      expect(MeetingUnlock.verifyPin(_member('m2'), '123456'), isFalse,
          reason: 'a member without a PIN can never verify');
    });

    test('a valid PIN is exactly 6 digits', () {
      expect(MeetingUnlock.isValidPin('123456'), isTrue);
      expect(MeetingUnlock.isValidPin('12345'), isFalse);
      expect(MeetingUnlock.isValidPin('1234567'), isFalse);
      expect(MeetingUnlock.isValidPin('12a456'), isFalse);
    });
  });

  group('unlock quorum', () {
    final officials = [
      _member('c', role: MemberRole.chairperson),
      _member('s', role: MemberRole.secretary),
      _member('t', role: MemberRole.treasurer),
    ];
    final plain = List.generate(7, (i) => _member('p$i'));

    test('3 officials unlock', () {
      final status = MeetingUnlock.evaluate(
        activeMembers: [...officials, ...plain],
        verifiedMemberIds: {'c', 's', 't'},
      );
      expect(status.satisfied, isTrue);
      expect(status.officialsVerified, 3);
    });

    test('2 officials are not enough', () {
      final status = MeetingUnlock.evaluate(
        activeMembers: [...officials, ...plain],
        verifiedMemberIds: {'c', 's'},
      );
      expect(status.satisfied, isFalse);
    });

    test('5 plain members unlock without any official', () {
      final status = MeetingUnlock.evaluate(
        activeMembers: [...officials, ...plain],
        verifiedMemberIds: {'p0', 'p1', 'p2', 'p3', 'p4'},
      );
      expect(status.satisfied, isTrue);
      expect(status.membersVerified, 5);
    });

    test('4 mixed members are not enough', () {
      final status = MeetingUnlock.evaluate(
        activeMembers: [...officials, ...plain],
        verifiedMemberIds: {'c', 'p0', 'p1', 'p2'},
      );
      expect(status.satisfied, isFalse);
    });

    test('a tiny group caps the member quorum at everyone', () {
      final tiny = [_member('a'), _member('b')];
      final unsatisfied = MeetingUnlock.evaluate(
        activeMembers: tiny,
        verifiedMemberIds: {'a'},
      );
      expect(unsatisfied.memberQuorum, 2);
      expect(unsatisfied.satisfied, isFalse);

      final satisfied = MeetingUnlock.evaluate(
        activeMembers: tiny,
        verifiedMemberIds: {'a', 'b'},
      );
      expect(satisfied.satisfied, isTrue);
    });

    test('an empty group can never unlock', () {
      final status = MeetingUnlock.evaluate(
        activeMembers: const [],
        verifiedMemberIds: const {},
      );
      expect(status.satisfied, isFalse);
    });
  });
}
