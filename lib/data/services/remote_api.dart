import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/remote/agent_report.dart';
import '../models/remote/credit_rating.dart';
import '../models/remote/group_report.dart';
import '../models/remote/member_overview.dart';
import '../models/remote/member_passbook.dart';
import '../models/remote/membership.dart';
import '../models/remote/remote_models.dart';

/// Typed wrapper over the IntelliCash backend endpoints a `MOBILE_CORE` API
/// key is allowed to consume.
///
/// Only endpoints that actually exist in the Node/Express API and fall within
/// the MOBILE_CORE scopes (programmes:read, groups:read, members:read/write,
/// meetings:read/write, ledger:read/write, votes, store, notifications) are
/// exposed here. See docs/audit for the full inventory and the gap list.
class RemoteApi {
  RemoteApi(this._client);

  final ApiClient _client;

  // --- Connection ---

  /// Unauthenticated liveness probe: `GET /health` (server root).
  Future<bool> health() async {
    final body = await _client.getRoot('/health');
    final data = body['data'];
    return data is Map && data['status'] == 'ok';
  }

  // --- Auth ---

  /// Signs in with phone/email + password; returns the user and the session
  /// token to use as the bearer credential.
  Future<({RemoteUser user, String token})> login(
      String identifier, String password) async {
    final result =
        await _client.login(identifier: identifier, password: password);
    return (user: RemoteUser.fromJson(result.user), token: result.sessionToken);
  }

  /// `POST /auth/register` — creates a Group/Member/Agent account and signs
  /// straight in. Account first, everything else after.
  Future<({RemoteUser user, String token})> register({
    required String accountType,
    required String name,
    required String phone,
    required String password,
    String? email,
    String? county,
  }) async {
    final result = await _client.register(
      accountType: accountType,
      name: name,
      phone: phone,
      password: password,
      email: email,
      county: county,
    );
    return (user: RemoteUser.fromJson(result.user), token: result.sessionToken);
  }

  /// `POST /auth/logout` — ends the session on the SERVER.
  ///
  /// Clearing the token on the handset is not enough: without this the session
  /// stays valid until it expires, which matters because these phones get
  /// passed around a group. Best-effort — signing out must still work with no
  /// signal, so a failure here does not block it.
  Future<bool> logout() async {
    try {
      await _client.postData('/auth/logout', body: const {});
      return true;
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// `GET /auth/me` — the account behind the current credential (session or
  /// API key). Used to show who is connected.
  Future<RemoteUser> me() async {
    final data = await _client.getData('/auth/me');
    return RemoteUser.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /members/me` — the signed-in member's passbook, totalled by the
  /// server. Self-scoped: there is no id, so it can only ever return you.
  ///
  /// Returns null when the account isn't linked to a member (a group or
  /// agent login) or the server is older than this endpoint — the caller
  /// then falls back to adding up the ledger on the phone.
  Future<MemberPassbook?> myPassbook() async {
    try {
      final data = await _client.getData('/members/me');
      if (data is! Map<String, dynamic>) return null;
      return MemberPassbook.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  /// `GET /members/me/overview` — everything this person has saved, across
  /// every group they belong to, with per-group figures and a combined total.
  ///
  /// Self-scoped: no id in the path, so it can only ever return the caller's
  /// own position. Null for a group or agent login, or when offline.
  Future<MemberOverview?> myOverview() async {
    try {
      final data = await _client.getData('/members/me/overview');
      if (data is! Map<String, dynamic>) return null;
      return MemberOverview.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  /// `GET /reports/agent` — the signed-in agent's caseload in one request,
  /// with each group's credit band and whether it needs a visit.
  ///
  /// Null when offline or for a login that is not a village agent, so the
  /// caller falls back to fetching each group's rating separately.
  Future<AgentReport?> agentReport() async {
    try {
      final data = await _client.getData('/reports/agent');
      if (data is! Map<String, dynamic>) return null;
      return AgentReport.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  /// `GET /reports/member/:memberId` — a group's copy of one member's
  /// figures.
  ///
  /// The server builds this with the same aggregation as `/members/me`, so
  /// the group's view of a member and the member's own passbook always agree.
  /// Null when offline, or when this account may not view that member.
  Future<MemberPassbook?> memberReport(String memberId) async {
    try {
      final data = await _client.getData('/reports/member/$memberId');
      if (data is! Map<String, dynamic>) return null;
      return MemberPassbook.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  /// `GET /reports/group/:id` — the group's report as the server totals it.
  ///
  /// Returns null when the phone is offline or the account may not read this
  /// group, so the caller can fall back to the figures held on the phone.
  Future<GroupReport?> groupReport(String groupId) async {
    try {
      final data = await _client.getData('/reports/group/$groupId');
      if (data is! Map<String, dynamic>) return null;
      return GroupReport.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  // --- Groups a person belongs to ---

  /// `GET /members/me/memberships` — every group this account has been let
  /// into, and which one is currently in view.
  ///
  /// Empty for a group or agent login, and for a member who hasn't joined
  /// anywhere yet.
  Future<List<Membership>> memberships() async {
    try {
      final list = await _client.getList('/members/me/memberships');
      return list
          .whereType<Map<String, dynamic>>()
          .map(Membership.fromJson)
          .toList();
    } on ApiException {
      return const [];
    }
  }

  /// `POST /members/me/join-requests` — asks a group to add you, by the code
  /// printed on its records.
  ///
  /// This grants nothing on its own: an official of that group has to approve
  /// it before any of the group's money becomes visible.
  Future<String> requestToJoinGroup(String groupCode, {String? name}) async {
    final data = await _client.postData(
      '/members/me/join-requests',
      body: {
        'groupCode': groupCode.trim().toUpperCase(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );
    if (data is Map && data['groupName'] != null) return '${data['groupName']}';
    return 'the group';
  }

  /// `POST /members/me/active-membership` — switches which group the rest of
  /// the API reports on.
  Future<void> setActiveMembership(String groupId) async {
    await _client.postData(
      '/members/me/active-membership',
      body: {'groupId': groupId},
    );
  }

  /// `GET /groups/:id/join-requests` — people waiting for this group to let
  /// them in. Officials only.
  Future<List<JoinRequest>> joinRequests(String groupId,
      {bool all = false}) async {
    final list = await _client
        .getList('/groups/$groupId/join-requests${all ? '?status=ALL' : ''}');
    return list
        .whereType<Map<String, dynamic>>()
        .map(JoinRequest.fromJson)
        .toList();
  }

  /// `POST /groups/:id/join-requests/:reqId/decision` — approving is what
  /// actually opens the group's books to that person.
  Future<Map<String, dynamic>> decideJoinRequest(
    String groupId,
    String requestId, {
    required bool approve,
    String? notes,
    String? confirmMemberId,
  }) async {
    final data = await _client.postData(
      '/groups/$groupId/join-requests/$requestId/decision',
      body: {
        'decision': approve ? 'APPROVE' : 'REJECT',
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        // Echoes back the member the official was shown, so approving a
        // handover they never saw is refused by the server.
        if (approve && confirmMemberId != null) 'confirmMemberId': confirmMemberId,
      },
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  // --- Meeting security (3-key OTP when online) ---

  /// `POST /groups/:id/members/:mid/otp` — the server texts the member a
  /// fresh one-time code. Returns the masked phone it was sent to (or null).
  Future<String?> sendMemberOtp(String groupId, String memberId) async {
    final data = await _client
        .postData('/groups/$groupId/members/$memberId/otp', body: const {});
    if (data is Map) {
      final delivery = data['pinDelivery'];
      if (delivery is Map) return delivery['phone']?.toString();
    }
    return null;
  }

  /// `POST /groups/:id/members/:mid/verify-credential` — checks a one-time
  /// code (or the member's saved server PIN). True when the key turns.
  Future<bool> verifyMemberCredential(
    String groupId,
    String memberId,
    String secret,
  ) async {
    final data = await _client.postData(
      '/groups/$groupId/members/$memberId/verify-credential',
      body: {'secret': secret},
    );
    return data is Map && data['valid'] == true;
  }

  /// `POST /groups/:id/members/:mid/account` — the group creates a sign-in
  /// account for one of its members (optional, switched on in settings).
  Future<void> createMemberAccount(
    String groupId,
    String memberId, {
    required String password,
    String? email,
  }) async {
    await _client.postData(
      '/groups/$groupId/members/$memberId/account',
      body: {
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
  }

  // --- Groups (groups:read) ---

  /// `GET /groups` — every group the key's account can see.
  Future<List<RemoteGroup>> groups() async {
    final list = await _client.getList('/groups');
    return list
        .map((e) => RemoteGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /groups/:id` — group detail with fund balances, credit score and
  /// membership/meeting counts.
  Future<RemoteGroup> groupDetail(String groupId) async {
    final data = await _client.getData('/groups/$groupId');
    return RemoteGroup.fromJson(data as Map<String, dynamic>);
  }

  // --- Members (members:read) ---

  /// `GET /groups/:id/members` — the group roster.
  Future<List<RemoteMember>> groupMembers(String groupId) async {
    final list = await _client.getList('/groups/$groupId/members');
    return list
        .map((e) => RemoteMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Meetings (meetings:read) ---

  /// `GET /groups/:id/meetings` — the group's meeting history.
  Future<List<RemoteMeeting>> groupMeetings(String groupId) async {
    final list = await _client.getList('/groups/$groupId/meetings');
    return list
        .map((e) => RemoteMeeting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Credit rating (groups:read) ---

  /// `GET /groups/:id/credit-score` — the group's credit rating (governance +
  /// VSLA compliance), band and the credit terms it unlocks.
  Future<RemoteCreditRating> creditRating(String groupId) async {
    final data = await _client.getData('/groups/$groupId/credit-score');
    return RemoteCreditRating.fromJson(data as Map<String, dynamic>);
  }

  // --- Ledger (ledger:read) ---

  /// `GET /groups/:id/ledger` — for a MEMBER the backend scopes this to their
  /// own entries, which the passbook aggregates into a personal statement.
  Future<List<Map<String, dynamic>>> ledger(String groupId) async {
    final list = await _client.getList('/groups/$groupId/ledger');
    return list.whereType<Map<String, dynamic>>().toList();
  }

  // --- Notifications (auth-only) ---

  /// `GET /notifications` — latest items plus the unread badge count from
  /// `meta.unreadCount`.
  Future<RemoteNotifications> notifications() async {
    final env = await _client.getEnvelope('/notifications');
    final items = (env['data'] as List?)
            ?.map((e) => RemoteNotification.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <RemoteNotification>[];
    final meta = env['meta'] as Map<String, dynamic>?;
    final unread = (meta?['unreadCount'] as num?)?.toInt() ?? 0;
    return RemoteNotifications(items: items, unreadCount: unread);
  }
}
