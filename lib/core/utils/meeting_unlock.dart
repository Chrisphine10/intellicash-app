import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../data/models/member.dart';

/// The 3-key meeting unlock, mirrored from the backend's rule: a meeting
/// opens when **3 officials** (chairperson / secretary / treasurer) or
/// **5 members** have each confirmed their secret PIN. Groups smaller than
/// five can't reach the member quorum, so it caps at "everyone".
abstract final class MeetingUnlock {
  static const int officialsRequired = 3;
  static const int membersRequired = 5;

  /// Hashes a PIN with a per-member salt so equal PINs don't hash equal.
  static String hashPin(String memberId, String pin) {
    return sha256.convert(utf8.encode('$memberId:${pin.trim()}')).toString();
  }

  static bool verifyPin(Member member, String pin) {
    final stored = member.pinHash;
    if (stored == null || stored.isEmpty) return false;
    return stored == hashPin(member.id, pin);
  }

  /// A valid meeting PIN is exactly 6 digits.
  static bool isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin.trim());

  static MeetingUnlockStatus evaluate({
    required List<Member> activeMembers,
    required Set<String> verifiedMemberIds,
  }) {
    final verified =
        activeMembers.where((m) => verifiedMemberIds.contains(m.id)).toList();
    final officialsVerified = verified.where((m) => m.isOfficial).length;
    final membersVerified = verified.length;
    final memberQuorum =
        activeMembers.length < membersRequired ? activeMembers.length : membersRequired;
    final satisfied = officialsVerified >= officialsRequired ||
        (memberQuorum > 0 && membersVerified >= memberQuorum);
    return MeetingUnlockStatus(
      officialsVerified: officialsVerified,
      membersVerified: membersVerified,
      officialsRequired: officialsRequired,
      memberQuorum: memberQuorum,
      satisfied: satisfied,
    );
  }
}

class MeetingUnlockStatus {
  const MeetingUnlockStatus({
    required this.officialsVerified,
    required this.membersVerified,
    required this.officialsRequired,
    required this.memberQuorum,
    required this.satisfied,
  });

  final int officialsVerified;
  final int membersVerified;
  final int officialsRequired;

  /// 5, or the whole group when it has fewer than 5 active members.
  final int memberQuorum;
  final bool satisfied;

  String get progressLabel =>
      '$officialsVerified of $officialsRequired officials · '
      '$membersVerified of $memberQuorum members';
}
