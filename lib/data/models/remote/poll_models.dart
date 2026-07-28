/// DTOs for Voting / Polls — the group's votes, taken in a meeting.
///
/// Two shapes share one model: a `ROLE_ELECTION` (members stand for an office
/// and the group elects one) and a `DECISION` (a motion, usually Yes / No).
/// Counts are plain integers on the wire — no money is involved here.
///
/// Shapes follow the `{ data, meta }` envelope of `GET /groups/:id/polls`,
/// `GET /polls/:id`, `POST /polls/:id/vote` and `POST /polls/:id/close`.
library;

int _toInt(Object? v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

bool _toBool(Object? v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// `CHAIRPERSON` -> `Chairperson`, `MONEY_COUNTER` -> `Money counter`.
String _roleLabel(String role) {
  if (role.isEmpty) return '';
  final clean = role.replaceAll('_', ' ').toLowerCase();
  return clean[0].toUpperCase() + clean.substring(1);
}

/// One choice on the ballot — a candidate in an election, or an answer
/// ("Yes", "No", "Buy a water tank") in a decision.
class RemotePollOption {
  const RemotePollOption({
    required this.id,
    required this.label,
    this.memberId,
    required this.position,
    required this.voteCount,
    this.memberName,
    this.memberRole,
  });

  final String id;
  final String label;

  /// Set when this option is a member standing for office.
  final String? memberId;
  final int position;
  final int voteCount;
  final String? memberName;
  final String? memberRole;

  /// The office this candidate currently holds, e.g. `Chairperson`.
  String? get memberRoleLabel =>
      memberRole == null ? null : _roleLabel(memberRole!);

  factory RemotePollOption.fromJson(Map<String, dynamic> j) {
    final member = j['member'];
    return RemotePollOption(
      id: '${j['id']}',
      label: '${j['label'] ?? ''}',
      memberId: j['memberId'] as String?,
      position: _toInt(j['position']),
      voteCount: _toInt(j['voteCount']),
      memberName: member is Map ? member['fullName'] as String? : null,
      memberRole: member is Map ? member['role'] as String? : null,
    );
  }
}

/// A vote the group has opened (`GET /groups/:id/polls`).
class RemotePoll {
  const RemotePoll({
    required this.id,
    required this.groupId,
    this.meetingId,
    required this.type,
    required this.title,
    this.description,
    this.targetRole,
    required this.status,
    required this.secretBallot,
    this.closesAt,
    this.closedAt,
    this.resultSummary,
    this.createdAt,
    this.meetingTitle,
    required this.options,
    required this.totalVotes,
    this.myVote,
    required this.hasVoted,
  });

  final String id;
  final String groupId;
  final String? meetingId;

  /// `ROLE_ELECTION` | `DECISION`
  final String type;
  final String title;
  final String? description;

  /// The office being filled, when [isElection].
  final String? targetRole;

  /// `OPEN` | `CLOSED`
  final String status;

  /// A secret ballot hides who voted for what; the tally is still public.
  final bool secretBallot;
  final DateTime? closesAt;
  final DateTime? closedAt;

  /// Plain-language outcome, written when the vote is closed.
  final String? resultSummary;
  final DateTime? createdAt;
  final String? meetingTitle;
  final List<RemotePollOption> options;
  final int totalVotes;

  /// The caller's own choice — always null for a secret ballot.
  final String? myVote;

  /// Whether the caller has already voted (the one thing a secret ballot
  /// must still reveal, or the app cannot tell them they have voted).
  final bool hasVoted;

  bool get isElection => type == 'ROLE_ELECTION';
  bool get isOpen => status == 'OPEN';
  bool get isClosed => !isOpen;

  /// `Election` / `Decision` — the chip on the list row.
  String get typeLabel => isElection ? 'Election' : 'Decision';

  /// `Open` / `Closed`.
  String get statusLabel => isOpen ? 'Open' : 'Closed';

  /// `Chairperson`, `Treasurer`, … for an election.
  String? get targetRoleLabel =>
      targetRole == null ? null : _roleLabel(targetRole!);

  /// Highest vote count on the ballot (0 when nobody has voted yet).
  int get leadingCount =>
      options.fold<int>(0, (best, o) => o.voteCount > best ? o.voteCount : best);

  /// True when more than one option shares the lead — the group must vote
  /// again rather than have the app pick a winner.
  bool get isTie =>
      totalVotes > 0 &&
      options.where((o) => o.voteCount == leadingCount).length > 1;

  /// The single winning option, or null when there is a tie or no votes.
  RemotePollOption? get winner {
    if (totalVotes == 0 || isTie) return null;
    for (final option in options) {
      if (option.voteCount == leadingCount) return option;
    }
    return null;
  }

  /// True when [option] is the clear leader — drives the highlighted row.
  bool isWinning(RemotePollOption option) => winner?.id == option.id;

  /// [option]'s share of the votes cast, `0.0`–`1.0`, for the tally bar.
  double share(RemotePollOption option) =>
      totalVotes == 0 ? 0 : option.voteCount / totalVotes;

  factory RemotePoll.fromJson(Map<String, dynamic> j) {
    final meeting = j['meeting'];
    final options = (j['options'] as List?) ?? const [];
    return RemotePoll(
      id: '${j['id']}',
      groupId: '${j['groupId'] ?? ''}',
      meetingId: j['meetingId'] as String?,
      type: '${j['type'] ?? 'DECISION'}',
      title: '${j['title'] ?? 'Vote'}',
      description: j['description'] as String?,
      targetRole: j['targetRole'] as String?,
      status: '${j['status'] ?? 'OPEN'}',
      secretBallot: _toBool(j['secretBallot']),
      closesAt: _date(j['closesAt']),
      closedAt: _date(j['closedAt']),
      resultSummary: j['resultSummary'] as String?,
      createdAt: _date(j['createdAt']),
      meetingTitle: meeting is Map ? meeting['title'] as String? : null,
      options: options
          .map((e) => RemotePollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalVotes: _toInt(j['totalVotes']),
      myVote: j['myVote'] as String?,
      hasVoted: _toBool(j['hasVoted']),
    );
  }
}
