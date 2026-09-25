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

import 'dart:convert';

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
/// Which optional modules a group can use: Intelli-Store and Voting are
/// switched on per programme by an IWL admin, and both start off.
class GroupModules {
  const GroupModules({this.store = false, this.voting = false});

  factory GroupModules.fromJson(Map<String, dynamic> j) =>
      GroupModules(store: j['store'] == true, voting: j['voting'] == true);

  final bool store;
  final bool voting;

  Map<String, dynamic> toJson() => {'store': store, 'voting': voting};
}

class RemoteGroup {
  const RemoteGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.phase,
    required this.county,
    this.subCounty,
    this.meetingDay,
    this.meetingFrequency,
    this.meetingDays,
    this.meetingTime,
    this.remindersEnabled = true,
    required this.shareValue,
    required this.maxSharesPerMeeting,
    required this.cycleNumber,
    this.programmeName,
    this.funds = const [],
    this.creditScore,
    this.memberCount,
    this.meetingCount,
    this.championName,
    this.championPhone,
    this.totalSavingsCents,
    this.totalSocialFundCents,
    this.modules,
  });

  final String id;
  final String name;
  final String code;
  final String phase;
  final String county;
  final String? subCounty;
  final String? meetingDay;

  /// The structured schedule the server reminds members by: WEEKLY, BIWEEKLY
  /// or MONTHLY; ISO weekdays (1 = Monday); "HH:mm". Null until someone sets
  /// one, on the console or on a phone.
  final String? meetingFrequency;
  final List<int>? meetingDays;
  final String? meetingTime;
  final bool remindersEnabled;
  final double shareValue; // KES per share
  final int maxSharesPerMeeting;
  final int cycleNumber;
  final String? programmeName;

  // Detail-only enrichments
  final List<RemoteFundAccount> funds;
  final int? creditScore;
  final int? memberCount;
  final int? meetingCount;

  /// The group's digital champion — the person whose phone opens the group's
  /// account — as recorded on the server.
  final String? championName;
  final String? championPhone;

  /// Server-computed totals (from GET /groups/:id). When present, these are the
  /// authoritative figures and should be preferred over local calculations.
  final double? totalSavingsCents;
  final double? totalSocialFundCents;

  /// Optional modules switched on for this group's programmes, or null when
  /// the server did not say (an older server, or a list row rather than the
  /// group's own detail). Null is treated as "off" by [ModuleSwitches].
  final GroupModules? modules;

    double _fund(String type) => funds
        .where((f) => f.type == type)
        .fold(0.0, (sum, f) => sum + f.balance);

    /// The backend uses INTERNAL_LOAN for share purchases (no SAVINGS fund type exists).
    /// See packages/shared/src/index.ts fundTypes enum.
    double get savingsBalance => _fund('INTERNAL_LOAN');
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
      meetingFrequency: j['meetingFrequency'] as String?,
      meetingDays: _scheduleDays(j['meetingDays']),
      meetingTime: j['meetingTime'] as String?,
      remindersEnabled: j['remindersEnabled'] as bool? ?? true,
      shareValue: _centsToKes(j['shareValueCents']),
      maxSharesPerMeeting: _toInt(j['maxSharesPerMemberPerMeeting']),
      cycleNumber: _toInt(j['cycleNumber']),
      programmeName: programme is Map ? programme['name'] as String? : null,
      funds: funds,
      creditScore: (scores != null && scores.isNotEmpty)
          ? _toInt((scores.first as Map)['score'])
          : null,
      championName: (j['contactPersonName'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['contactPersonName'] as String).trim(),
      championPhone: (j['contactPhone'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['contactPhone'] as String).trim(),
      memberCount: count == null ? null : _toInt(count['members']),
      meetingCount: count == null ? null : _toInt(count['meetings']),
      totalSavingsCents: j['totalSavingsCents'] != null ? (j['totalSavingsCents'] as num).toDouble() : null,
      totalSocialFundCents: j['totalSocialFundCents'] != null ? (j['totalSocialFundCents'] as num).toDouble() : null,
      modules: j['modules'] is Map<String, dynamic>
          ? GroupModules.fromJson(j['modules'] as Map<String, dynamic>)
          : null,
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
    this.source = 'MANUAL',
    this.cancelReason,
  });

  final String id;
  final String title;

  /// SCHEDULED, KEY_UNLOCK_PENDING, IN_PROGRESS, SEALED, SYNC_CONFLICT or
  /// CANCELLED. A person moves a meeting out of SCHEDULED; the clock never does.
  final String status;
  final DateTime? scheduledAt;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String unlockStatus; // PENDING, UNLOCKED
  final double transactionTotal; // KES

  /// MANUAL (scheduled on the console), AUTO_SCHEDULE (planned from the
  /// group's meeting days, for reminders) or PHONE (held on a phone).
  final String source;
  final String? cancelReason;

  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isNotStarted =>
      status == 'SCHEDULED' || status == 'KEY_UNLOCK_PENDING';
  bool get isCancelled => status == 'CANCELLED';
  bool get isClosed =>
      status == 'SEALED' || status == 'CLOSED' || isCancelled || closedAt != null;

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
      source: '${j['source'] ?? 'MANUAL'}',
      cancelReason: j['cancelReason'] as String?,
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

/// `Group.meetingDays` is stored as JSON text ("[4,5]"); some responses send
/// the list itself.
List<int>? _scheduleDays(Object? value) {
  Object? raw = value;
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  if (raw is! List) return null;
  final days = raw.whereType<num>().map((d) => d.toInt()).where((d) => d >= 1 && d <= 7).toList()
    ..sort();
  return days.isEmpty ? null : days;
}
