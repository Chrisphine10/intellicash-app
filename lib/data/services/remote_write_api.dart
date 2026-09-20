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

  /// `POST /groups/:groupId/members/sync` — sends a member this phone knows
  /// about and returns their id on the server.
  ///
  /// Retry-safe: the server finds the member it already has (by phone, else by
  /// name in the group) rather than making a second. [phone] may be null — a
  /// group set up on the phone often enters members by name alone.
  Future<String> syncMember({
    required String groupId,
    required String fullName,
    String? phone,
    String? role,
  }) async {
    final data = await _client.postData('/groups/$groupId/members/sync', body: {
      'fullName': fullName,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (role != null) 'role': role,
    });
    return (data as Map<String, dynamic>)['id'] as String;
  }

  /// `POST /groups/:groupId/role-assignments` — sets a member's office on the
  /// server, keeping the office history. An answer of ALREADY_HOLDS_ROLE means
  /// the server already agrees, which the caller treats as done.
  Future<void> assignRole({
    required String groupId,
    required String memberId,
    required String role,
  }) async {
    await _client.postData('/groups/$groupId/role-assignments', body: {
      'memberId': memberId,
      'role': role,
    });
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

  /// `POST /groups/:groupId/share-outs` — sends a share-out done on this phone
  /// and lets the server close the cycle it ended, in one step. The server
  /// records what was paid as it was; it does not work it out again.
  ///
  /// Retry-safe: [shareOutId] is the phone's own id for this share-out, and
  /// sending it again answers with what was already recorded ([RecordedShareOut.replayed]).
  ///
  /// Refusals arrive as an [ApiException] whose `code` says why:
  /// `SHARE_OUT_CYCLE_CLOSED` (the server already closed that cycle - it was
  /// shared out elsewhere), `SHARE_OUT_CYCLE_AHEAD` (an earlier cycle has not
  /// arrived), `SHARE_OUT_OUT_OF_STEP` (the server's share purchases are not the
  /// phone's), `SHARE_OUT_FUND_SHORT`, `CYCLE_HAS_OPEN_MEETINGS`, or a plain 403
  /// for an account that may not end a cycle.
  Future<RecordedShareOut> recordShareOut({
    required String groupId,
    required String shareOutId,
    required int cycleNumber,
    required List<ShareOutLineInput> lines,
    bool force = false,
  }) async {
    final data = await _client.postData('/groups/$groupId/share-outs', body: {
      'shareOutId': shareOutId,
      'cycleNumber': cycleNumber,
      if (force) 'force': true,
      'lines': [for (final line in lines) line.toJson()],
    });
    final map = data as Map<String, dynamic>;
    return RecordedShareOut(
      replayed: map['replayed'] == true,
      closedCycleId: (map['closed'] as Map<String, dynamic>)['id'] as String,
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


/// One member's line of a share-out, in backend vocabulary (cents).
class ShareOutLineInput {
  const ShareOutLineInput({
    required this.memberId,
    required this.shareCents,
    required this.grossPayoutCents,
    required this.welfarePayoutCents,
    required this.loanOffsetCents,
    required this.netPayoutCents,
  });

  final String memberId;
  final int shareCents;
  final int grossPayoutCents;
  final int welfarePayoutCents;
  final int loanOffsetCents;

  /// Negative when the member owes the group more than they are owed.
  final int netPayoutCents;

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'shareCents': shareCents,
        'grossPayoutCents': grossPayoutCents,
        'welfarePayoutCents': welfarePayoutCents,
        'loanOffsetCents': loanOffsetCents,
        'netPayoutCents': netPayoutCents,
      };
}

/// What the server says about a share-out it accepted.
class RecordedShareOut {
  const RecordedShareOut({required this.replayed, required this.closedCycleId});

  /// True when this exact share-out had been recorded before and nothing new was
  /// written now.
  final bool replayed;

  /// The server cycle that the share-out closed.
  final String closedCycleId;
}
