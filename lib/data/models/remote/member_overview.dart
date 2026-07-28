import 'member_passbook.dart';

/// One person's savings across every group they belong to
/// (`GET /members/me/overview`).
///
/// Money arrives in integer cents and is turned into KES once, here, so no
/// screen has to remember to divide.
class MemberOverview {
  const MemberOverview({
    required this.memberName,
    required this.groups,
    required this.shares,
    required this.social,
    required this.fines,
    required this.totalPaidIn,
    required this.loansReceived,
    required this.loansRepaid,
    required this.loanOutstanding,
    this.generatedAt,
  });

  final String memberName;

  /// One entry per group, each with that group's own figures.
  final List<MemberGroupPosition> groups;

  // Combined across every group.
  final double shares;
  final double social;
  final double fines;
  final double totalPaidIn;
  final double loansReceived;
  final double loansRepaid;

  /// Summed per group, each already floored at zero — overpaying in one group
  /// must never cancel a real debt in another.
  final double loanOutstanding;

  final DateTime? generatedAt;

  int get groupCount => groups.length;

  /// The group currently in view, if any.
  MemberGroupPosition? get active {
    for (final g in groups) {
      if (g.isActive) return g;
    }
    return null;
  }

  factory MemberOverview.fromJson(Map<String, dynamic> json) {
    final combined = (json['combined'] as Map<String, dynamic>?) ?? const {};
    double cents(String key) => ((combined[key] as num?) ?? 0) / 100;
    final member = (json['member'] as Map<String, dynamic>?) ?? const {};

    return MemberOverview(
      memberName: '${member['name'] ?? 'Member'}',
      groups: ((json['groups'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MemberGroupPosition.fromJson)
          .toList(),
      shares: cents('sharesCents'),
      social: cents('socialCents'),
      fines: cents('finesCents'),
      totalPaidIn: cents('totalPaidInCents'),
      loansReceived: cents('loansReceivedCents'),
      loansRepaid: cents('loansRepaidCents'),
      loanOutstanding: cents('loanOutstandingCents'),
      generatedAt: DateTime.tryParse('${json['generatedAt']}'),
    );
  }
}

/// What one member holds in one particular group.
class MemberGroupPosition {
  const MemberGroupPosition({
    required this.groupName,
    required this.passbook,
    required this.isActive,
    this.groupCode,
  });

  final String groupName;
  final String? groupCode;

  /// The same shape the single-group passbook uses, from the same builder on
  /// the server — so this and the passbook screen can never disagree.
  final MemberPassbook passbook;

  /// Whether this is the group the app is currently showing.
  final bool isActive;

  factory MemberGroupPosition.fromJson(Map<String, dynamic> json) {
    final passbook = MemberPassbook.fromJson(json);
    return MemberGroupPosition(
      groupName: passbook.groupName ?? 'Group',
      groupCode: ((json['member'] as Map<String, dynamic>?)?['group']
          as Map<String, dynamic>?)?['code'] as String?,
      passbook: passbook,
      isActive: json['isActive'] == true,
    );
  }
}
