import '../../core/network/api_client.dart';
import '../models/remote/meeting_models.dart';
import 'remote_write_api.dart' show LedgerEntryInput;

/// The backend meeting-governance lifecycle (Phase 2c): create → 3-key
/// unlock → open → ordered steps → seal, plus the in-meeting money moves and
/// the ledger read that feeds the financial summary.
///
/// Every route here is reachable with a `MOBILE_CORE` key — the preset carries
/// `meetings:write`, `meeting-keys:write`, `ledger:read/write` (verified in
/// `apps/api/src/domain/api-keys.ts`).
class RemoteMeetingApi {
  RemoteMeetingApi(this._client);

  final ApiClient _client;

  /// `GET /groups/:id/meetings/:meetingId` — full detail (steps, attendance,
  /// key submissions).
  Future<RemoteMeetingDetail> getMeeting({
    required String groupId,
    required String meetingId,
  }) async {
    final data = await _client.getData('/groups/$groupId/meetings/$meetingId');
    return RemoteMeetingDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /groups/:id/meetings` — schedules a meeting (seeds the 8 steps
  /// server-side) and returns it in the `SCHEDULED` state.
  Future<RemoteMeetingDetail> createMeeting({
    required String groupId,
    required String title,
    required DateTime scheduledAt,
    bool gpsCompliant = false,
  }) async {
    final data = await _client.postData('/groups/$groupId/meetings', body: {
      'title': title,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'gpsCompliant': gpsCompliant,
    });
    return RemoteMeetingDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /groups/:id/meetings/:meetingId/key-submissions` — records one or
  /// more 6-digit member PINs and returns the live unlock evaluation
  /// (≥3 officials OR ≥5 active members).
  Future<MeetingUnlockResult> submitKeySubmissions({
    required String groupId,
    required String meetingId,
    required List<KeySubmissionInput> submissions,
  }) async {
    final data = await _client.postData(
      '/groups/$groupId/meetings/$meetingId/key-submissions',
      body: {'submissions': submissions.map((s) => s.toJson()).toList()},
    );
    return MeetingUnlockResult.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /groups/:id/meetings/:meetingId/open` — verifies the unlock policy
  /// and activates the meeting (`IN_PROGRESS`). Any additional PINs supplied
  /// are recorded before evaluation. Throws [ApiException]
  /// `MEETING_UNLOCK_INCOMPLETE` if the policy isn't met.
  Future<RemoteMeetingDetail> openMeeting({
    required String groupId,
    required String meetingId,
    bool gpsCompliant = false,
    List<KeySubmissionInput> keySubmissions = const [],
  }) async {
    final data = await _client.postData(
      '/groups/$groupId/meetings/$meetingId/open',
      body: {
        'gpsCompliant': gpsCompliant,
        'keySubmissions': keySubmissions.map((s) => s.toJson()).toList(),
      },
    );
    return RemoteMeetingDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /groups/:id/meetings/:meetingId/attendance` (upsert).
  Future<void> recordAttendance({
    required String groupId,
    required String meetingId,
    required String memberId,
    required String status, // PRESENT | ABSENT | LATE | EXCUSED
  }) async {
    await _client.postData(
      '/groups/$groupId/meetings/$meetingId/attendance',
      body: {'memberId': memberId, 'status': status},
    );
  }

  /// `POST /groups/:id/meetings/:meetingId/ledger/batch` — posts money moves
  /// (share purchase, social fund, loan repayment, loan disbursement). Each
  /// entry dedupes on `clientRequestId`.
  Future<void> postLedger({
    required String groupId,
    required String meetingId,
    required List<LedgerEntryInput> entries,
  }) async {
    await _client.postData(
      '/groups/$groupId/meetings/$meetingId/ledger/batch',
      body: {'entries': entries.map((e) => e.toJson()).toList()},
    );
  }

  /// `POST /groups/:id/meetings/:meetingId/steps/:step/complete` — advances
  /// the workflow. Steps must be completed in order.
  Future<void> completeStep({
    required String groupId,
    required String meetingId,
    required String step,
  }) async {
    await _client.postData(
      '/groups/$groupId/meetings/$meetingId/steps/$step/complete',
    );
  }

  /// `POST /groups/:id/meetings/:meetingId/seal` — locks the meeting into the
  /// permanent audit trail. Requires every step COMPLETED.
  Future<RemoteMeetingDetail> seal({
    required String groupId,
    required String meetingId,
    String? minutes,
  }) async {
    final data = await _client.postData(
      '/groups/$groupId/meetings/$meetingId/seal',
      body: {if (minutes != null && minutes.isNotEmpty) 'minutes': minutes},
    );
    return RemoteMeetingDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /groups/:id/ledger?meetingId=…` — the entries posted in this
  /// meeting, newest first, for the consolidated financial summary.
  Future<List<RemoteLedgerEntry>> ledgerForMeeting({
    required String groupId,
    required String meetingId,
  }) async {
    final list = await _client
        .getList('/groups/$groupId/ledger', query: {'meetingId': meetingId});
    return list
        .map((e) => RemoteLedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// One 3-key submission: a member's 6-digit PIN, optionally device-bound.
class KeySubmissionInput {
  const KeySubmissionInput({
    required this.memberId,
    required this.pin,
    this.deviceId,
  });

  final String memberId;
  final String pin; // 6 digits
  final String? deviceId;

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'pin': pin,
        if (deviceId != null && deviceId!.isNotEmpty) 'deviceId': deviceId,
      };
}
