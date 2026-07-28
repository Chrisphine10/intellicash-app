import 'enums.dart';

class Member {
  const Member({
    required this.id,
    required this.groupId,
    required this.name,
    this.phone,
    this.role = MemberRole.member,
    this.isActive = true,
    this.pinHash,
    required this.joinedAt,
  });

  final String id;
  final String groupId;
  final String name;
  final String? phone;
  final MemberRole role;
  final bool isActive;

  /// Salted hash of the member's secret 6-digit meeting PIN, or null when
  /// the member hasn't set one yet. The PIN itself is never stored.
  final String? pinHash;

  final DateTime joinedAt;

  /// Officials hold the group's "keys": three of them together unlock a
  /// meeting (or most members, when officials aren't available).
  bool get isOfficial => role != MemberRole.member;

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  Member copyWith({
    String? name,
    String? phone,
    MemberRole? role,
    bool? isActive,
  }) {
    return Member(
      id: id,
      groupId: groupId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      pinHash: pinHash,
      joinedAt: joinedAt,
    );
  }

  factory Member.fromMap(Map<String, Object?> map) {
    return Member(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      role: enumFromName(
          MemberRole.values, map['role'] as String, MemberRole.member),
      isActive: (map['is_active'] as int) == 1,
      pinHash: map['pin_hash'] as String?,
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
      'phone': phone,
      'role': role.name,
      'is_active': isActive ? 1 : 0,
      'pin_hash': pinHash,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

/// A member joined with their live financial position — what the
/// directory, eligibility card and member detail screens show.
class MemberFinancials {
  const MemberFinancials({
    required this.member,
    required this.totalSavings,
    required this.totalShares,
    required this.activeLoanBalance,
    required this.hasDefaultedLoan,
  });

  final Member member;
  final double totalSavings;
  final int totalShares;
  final double activeLoanBalance;
  final bool hasDefaultedLoan;

  bool get hasActiveLoan => activeLoanBalance > 0;
}
