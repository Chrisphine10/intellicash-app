/// DTOs mirroring the IntelliCash Node/Express backend JSON responses.
///
/// These are deliberately separate from the app's local offline VSLA models —
/// the backend is a multi-tenant programme/group/ledger platform that stores
/// money as integer cents, while the local models are the offline field tool.
/// Keeping them apart means a backend shape change never silently corrupts
/// local records.
///
/// Shapes verified against the running API on 2026-07-17 (see docs/audit).
library;

double _centsToKes(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0) / 100;

int _toInt(Object? v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

DateTime? _toDate(Object? v) =>
    (v == null) ? null : DateTime.tryParse('$v')?.toLocal();

/// A fund sub-account on a group (`GET /groups/:id` → `fundAccounts[]`).
/// Types: SAVINGS, SOCIAL, INTERNAL_LOAN, EXTERNAL_LOAN, GRANT, VSLF.
class RemoteFundAccount {
  const RemoteFundAccount({required this.type, required this.balance});

  final String type;
  final double balance; // KES

  factory RemoteFundAccount.fromJson(Map<String, dynamic> j) {
    return RemoteFundAccount(
      type: '${j['type'] ?? ''}',
      balance: _centsToKes(j['balanceCents']),
    );
  }
}

/// `GET /groups` (list) and `GET /groups/:id` (detail, adds funds/score/counts).
class RemoteGroup {
  const RemoteGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.phase,
    required this.county,
    this.subCounty,
    this.meetingDay,
    required this.shareValue,
    required this.maxSharesPerMeeting,
    required this.cycleNumber,
    this.programmeName,
    this.funds = const [],
    this.creditScore,
    this.memberCount,
    this.meetingCount,
  });

  final String id;
  final String name;
  final String code;
  final String phase;
  final String county;
  final String? subCounty;
  final String? meetingDay;
  final double shareValue; // KES per share
  final int maxSharesPerMeeting;
  final int cycleNumber;
  final String? programmeName;

  // Detail-only enrichments
  final List<RemoteFundAccount> funds;
  final int? creditScore;
  final int? memberCount;
  final int? meetingCount;

  double _fund(String type) => funds
      .where((f) => f.type == type)
      .fold(0.0, (sum, f) => sum + f.balance);

  double get savingsBalance => _fund('SAVINGS');
  double get socialFundBalance => _fund('SOCIAL');
  double get internalLoanBalance => _fund('INTERNAL_LOAN');

  factory RemoteGroup.fromJson(Map<String, dynamic> j) {
    final programme = j['programme'];
    final funds = (j['fundAccounts'] as List?)
            ?.map((e) => RemoteFundAccount.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <RemoteFundAccount>[];
    final scores = j['creditScores'] as List?;
    final count = j['_count'] as Map<String, dynamic>?;

    return RemoteGroup(
      id: '${j['id']}',
      name: '${j['name'] ?? 'Group'}',
      code: '${j['code'] ?? ''}',
      phase: '${j['phase'] ?? ''}',
      county: '${j['county'] ?? ''}',
      subCounty: j['subCounty'] as String?,
      meetingDay: j['meetingDay'] as String?,
      shareValue: _centsToKes(j['shareValueCents']),
      maxSharesPerMeeting: _toInt(j['maxSharesPerMemberPerMeeting']),
      cycleNumber: _toInt(j['cycleNumber']),
      programmeName: programme is Map ? programme['name'] as String? : null,
      funds: funds,
      creditScore: (scores != null && scores.isNotEmpty)
          ? _toInt((scores.first as Map)['score'])
          : null,
      memberCount: count == null ? null : _toInt(count['members']),
      meetingCount: count == null ? null : _toInt(count['meetings']),
    );
  }
}

/// `GET /groups/:id/members`
class RemoteMember {
  const RemoteMember({
    required this.id,
    required this.fullName,
    this.phone,
    required this.role,
    required this.kycStatus,
    required this.status,
    this.joinedAt,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String role; // CHAIRPERSON, SECRETARY, TREASURER, MEMBER
  final String kycStatus; // VERIFIED, PENDING, …
  final String status; // ACTIVE, INACTIVE
  final DateTime? joinedAt;

  bool get isActive => status == 'ACTIVE';

  String get roleLabel {
    if (role.isEmpty) return 'Member';
    return role[0] + role.substring(1).toLowerCase().replaceAll('_', ' ');
  }

  factory RemoteMember.fromJson(Map<String, dynamic> j) {
    return RemoteMember(
      id: '${j['id']}',
      fullName: '${j['fullName'] ?? 'Member'}',
      phone: j['phone'] as String?,
      role: '${j['role'] ?? 'MEMBER'}',
      kycStatus: '${j['kycStatus'] ?? ''}',
      status: '${j['status'] ?? 'ACTIVE'}',
      joinedAt: _toDate(j['joinedAt']),
    );
  }
}

/// `GET /groups/:id/meetings`
class RemoteMeeting {
  const RemoteMeeting({
    required this.id,
    required this.title,
    required this.status,
    this.scheduledAt,
    this.openedAt,
    this.closedAt,
    required this.unlockStatus,
    required this.transactionTotal,
  });

  final String id;
  final String title;
  final String status; // SCHEDULED, OPEN, CLOSED
  final DateTime? scheduledAt;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String unlockStatus; // PENDING, UNLOCKED
  final double transactionTotal; // KES

  bool get isClosed => status == 'CLOSED' || closedAt != null;

  factory RemoteMeeting.fromJson(Map<String, dynamic> j) {
    return RemoteMeeting(
      id: '${j['id']}',
      title: '${j['title'] ?? 'Meeting'}',
      status: '${j['status'] ?? ''}',
      scheduledAt: _toDate(j['scheduledAt']),
      openedAt: _toDate(j['openedAt']),
      closedAt: _toDate(j['closedAt']),
      unlockStatus: '${j['unlockStatus'] ?? ''}',
      transactionTotal: _centsToKes(j['transactionTotal']),
    );
  }
}

/// `GET /notifications` — item plus the envelope's `meta.unreadCount`.
class RemoteNotification {
  const RemoteNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  factory RemoteNotification.fromJson(Map<String, dynamic> j) {
    return RemoteNotification(
      id: '${j['id']}',
      title: '${j['title'] ?? ''}',
      body: '${j['body'] ?? ''}',
      type: '${j['type'] ?? ''}',
      readAt: _toDate(j['readAt']),
      createdAt: _toDate(j['createdAt']),
    );
  }
}

/// The notifications feed with its unread badge count.
class RemoteNotifications {
  const RemoteNotifications({required this.items, required this.unreadCount});

  final List<RemoteNotification> items;
  final int unreadCount;
}

/// The signed-in backend user (`/auth/login`, `/auth/me`).
class RemoteUser {
  const RemoteUser({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    this.email,
    this.permissions = const [],
    this.groupId,
    this.memberId,
    this.villageAgentId,
    this.languagePreference,
  });

  final String id;
  final String name;
  final String role; // IWL_ADMIN, GROUP_ACCOUNT, MEMBER, VILLAGE_AGENT, …
  final String? phone;
  final String? email;
  final List<String> permissions;

  // Role bindings returned by /auth/login.
  final String? groupId;
  final String? memberId;
  final String? villageAgentId;

  /// The account's saved language (ENGLISH, KISWAHILI, …) — a phone with no
  /// language chosen yet adopts it on sign-in.
  final String? languagePreference;

  /// Village Agent, VA and CBT (Community-Based Trainer) are one job with one
  /// backend role, `VILLAGE_AGENT`. Different programmes use different words
  /// for the same person — do not add a second role for CBT.
  ///
  /// If the backend ever does gain another agent role, add it here: the root
  /// fails closed, so an agent whose role string is unrecognised lands on the
  /// sign-in screen rather than in someone's record book.
  bool get isAgent => role == 'VILLAGE_AGENT';
  bool get isMember => role == 'MEMBER';
  bool get isGroupAccount => role == 'GROUP_ACCOUNT';

  String get roleLabel {
    if (role == 'VILLAGE_AGENT') return 'Village Agent';
    return role
        .split('_')
        .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
        .join(' ');
  }

  factory RemoteUser.fromJson(Map<String, dynamic> j) {
    return RemoteUser(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      role: '${j['role'] ?? ''}',
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      permissions: (j['permissions'] as List?)?.map((e) => '$e').toList() ??
          const [],
      groupId: j['groupId'] as String?,
      memberId: j['memberId'] as String?,
      villageAgentId: j['villageAgentId'] as String?,
      languagePreference: j['languagePreference'] as String?,
    );
  }
}
