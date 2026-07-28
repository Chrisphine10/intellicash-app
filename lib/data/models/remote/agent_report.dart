/// One group on an agent's caseload, as the server sees it.
class AgentReportGroup {
  const AgentReportGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.needsSupport,
    this.code,
    this.county,
    this.band,
    this.score = 0,
    this.rated = false,
  });

  final String id;
  final String name;
  final String? code;
  final String? county;
  final int memberCount;

  /// Credit band A-D, or null when the group has never been rated.
  final String? band;
  final int score;
  final bool rated;

  /// Decided by the server so every surface agrees on who needs a visit.
  ///
  /// Note this counts a group with no rating at all as needing support: a
  /// group nobody has assessed is precisely one an agent should look at.
  final bool needsSupport;

  factory AgentReportGroup.fromJson(Map<String, dynamic> json) {
    final rating = json['creditRating'];
    return AgentReportGroup(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Group'}',
      code: json['code']?.toString(),
      county: json['county']?.toString(),
      memberCount: ((json['memberCount'] as num?) ?? 0).toInt(),
      band: rating is Map ? rating['band']?.toString() : null,
      score: rating is Map ? ((rating['score'] as num?) ?? 0).toInt() : 0,
      rated: rating is Map && rating['rated'] == true,
      needsSupport: json['needsSupport'] == true,
    );
  }
}

/// An agent's caseload report (`GET /reports/agent`).
///
/// Replaces one credit-rating call per group with a single request, and moves
/// the "needs support" decision to the server so the app and the back office
/// cannot disagree about which groups need a visit.
class AgentReport {
  const AgentReport({
    required this.generatedAt,
    required this.groups,
    required this.groupCount,
    required this.ratedCount,
    required this.needSupportCount,
    required this.totalMembers,
    this.agentName,
  });

  final DateTime? generatedAt;
  final List<AgentReportGroup> groups;
  final int groupCount;
  final int ratedCount;
  final int needSupportCount;
  final int totalMembers;
  final String? agentName;

  factory AgentReport.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final agent = json['agent'];
    int count(String key) => ((summary[key] as num?) ?? 0).toInt();
    return AgentReport(
      generatedAt: DateTime.tryParse('${json['generatedAt']}'),
      groups: ((json['groups'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AgentReportGroup.fromJson)
          .toList(),
      groupCount: count('groups'),
      ratedCount: count('rated'),
      needSupportCount: count('needSupport'),
      totalMembers: count('totalMembers'),
      agentName: agent is Map ? agent['name']?.toString() : null,
    );
  }
}
