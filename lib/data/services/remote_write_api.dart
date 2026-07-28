import '../../core/network/api_client.dart';

/// Typed wrappers for the backend WRITE endpoints a `MOBILE_CORE` key can
/// reach without the 3-key unlock or a registered offline device
/// (Phase 2a). All are idempotent server-side:
/// - meeting create is one-shot (we map the id and never re-create),
/// - attendance upserts on (meeting, member),
/// - ledger entries dedupe on `clientRequestId`.
class RemoteWriteApi {
  RemoteWriteApi(this._client);

  final ApiClient _client;

  /// `POST /groups/:groupId/meetings` — returns the new backend meeting id.
  Future<String> createMeeting({
    required String groupId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    final data = await _client.postData('/groups/$groupId/meetings', body: {
      'title': title,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    });
    return (data as Map<String, dynamic>)['id'] as String;
  }

  /// `POST /groups/:groupId/meetings/:meetingId/attendance` (upsert).
  Future<void> putAttendance({
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

  /// Posts a single meeting ledger entry through the batch endpoint (a
  /// one-item batch isolates failures per entry while keeping the
  /// `clientRequestId` idempotency). Returns nothing on success; throws
  /// [ApiException] on a real conflict (insufficient funds, bad member…).
  Future<void> postLedgerEntry({
    required String groupId,
    required String meetingId,
    required LedgerEntryInput entry,
  }) async {
    await _client.postData(
      '/groups/$groupId/meetings/$meetingId/ledger/batch',
      body: {
        'entries': [entry.toJson()],
      },
    );
  }

  /// `POST /groups/:groupId/members` — push a locally-created member.
  /// Requires a phone (backend min 7 chars). Returns the new backend id.
  Future<String> createMember({
    required String groupId,
    required String fullName,
    required String phone,
    String role = 'MEMBER',
  }) async {
    final data = await _client.postData('/groups/$groupId/members', body: {
      'fullName': fullName,
      'phone': phone,
      'role': role,
    });
    return (data as Map<String, dynamic>)['id'] as String;
  }
}

/// One meeting-ledger entry in backend vocabulary.
class LedgerEntryInput {
  const LedgerEntryInput({
    required this.memberId,
    required this.type,
    required this.amountCents,
    this.description,
    this.externalReference,
    required this.clientRequestId,
  });

  final String memberId;

  /// SHARE_PURCHASE | SOCIAL_CONTRIBUTION | LOAN_REPAYMENT |
  /// INTERNAL_LOAN_DISBURSEMENT | SHARE_OUT_PAYOUT
  final String type;
  final int amountCents;
  final String? description;
  final String? externalReference;
  final String clientRequestId;

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'type': type,
        'amountCents': amountCents,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (externalReference != null && externalReference!.isNotEmpty)
          'externalReference': externalReference,
        'clientRequestId': clientRequestId,
      };
}
