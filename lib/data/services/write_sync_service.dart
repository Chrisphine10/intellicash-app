import '../../core/database/app_database.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/app_logger.dart';
import '../models/enums.dart';
import '../models/loan.dart';
import '../models/meeting.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/meeting_schedule_repository.dart';
import 'remote_write_api.dart';

/// Outcome of syncing one local meeting to the backend.
class MeetingSyncResult {
  const MeetingSyncResult({
    required this.remoteMeetingId,
    required this.syncedCount,
    required this.conflicts,
    required this.skippedFines,
  });

  final String remoteMeetingId;
  final int syncedCount;
  final List<SyncConflict> conflicts;

  /// Retained for API compatibility. Fines now sync as `FINE_COLLECTION`
  /// (Gap 3, credits the SOCIAL fund), so this is 0 — a fine that can't sync
  /// surfaces as a conflict instead.
  final int skippedFines;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Phase 2a write-path sync: pushes a local meeting's attendance and ledger
/// (shares, social fund, fines, loan disbursements, repayments) to the backend
/// using the no-unlock, no-device endpoints. Idempotent — safe to re-run.
///
/// Requires the local group to be bound to a backend group and the
/// participating members to be mapped (see [IdMapRepository]).
class WriteSyncService {
  WriteSyncService({
    required AppDatabase db,
    required IdMapRepository idMap,
    required RemoteWriteApi writeApi,
    MeetingScheduleRepository? schedule,
  })  : _db = db,
        _idMap = idMap,
        _writeApi = writeApi,
        _schedule = schedule;

  final AppDatabase _db;
  final IdMapRepository _idMap;
  final RemoteWriteApi _writeApi;

  /// Optional: when present, a meeting started from a plan reuses the plan's
  /// server meeting rather than asking the server to find it by date.
  final MeetingScheduleRepository? _schedule;

  static int _cents(num shillings) => (shillings * 100).round();

  /// The backend counterpart of a local meeting — created and mapped if it does
  /// not exist yet. Idempotent: a meeting that is already mapped is reused, so
  /// calling this while the meeting is still open and again when it syncs
  /// produces ONE backend meeting.
  ///
  /// Welfare is recorded on the server against a meeting, and a meeting kept on
  /// this phone has no server twin until it syncs — which used to make welfare
  /// say "no meeting is open" while the phone showed one.
  Future<String> ensureRemoteMeeting(Meeting meeting) async {
    final remoteGroupId = await _idMap.remoteId(MapEntity.group, meeting.groupId);
    if (remoteGroupId == null) {
      throw const ApiException(
        'This group is not linked to the backend yet. Link it in Server → '
        'Sync before pushing meetings.',
      );
    }
    var remoteMeetingId = await _idMap.remoteId(MapEntity.meeting, meeting.id) ??
        await _idMap.remoteId(MapEntity.meetingTwin, meeting.id);
    if (remoteMeetingId == null) {
      // The plan this meeting was started from, if the phone knows its server
      // copy; otherwise the server adopts that day's scheduled meeting itself.
      // Either way the scheduled meeting becomes the held one, not a twin of it.
      remoteMeetingId = await _schedule?.remoteIdForMeeting(meeting.id) ??
          await _writeApi.createMeeting(
            groupId: remoteGroupId,
            title: 'Meeting #${meeting.number}',
            scheduledAt: meeting.date,
            adoptScheduled: true,
            source: 'PHONE',
          );
      // Recorded as a TWIN, not as a pushed meeting: nothing has been sent to it
      // yet. `MapEntity.meeting` is written by [syncMeeting] once a full pass has
      // run, because that mapping is what the sync (and its badge) reads as
      // "backed up". Writing it here made a meeting given a twin while open look
      // finished the moment it closed, and its shares, loans and repayments never
      // reached the server.
      await _idMap.put(MapEntity.meetingTwin, meeting.id, remoteMeetingId,
          groupId: remoteGroupId);
      log.info('sync', 'Created backend meeting $remoteMeetingId');
    }
    // A meeting on the phone exists only because someone started it, so the
    // server hears so. Idempotent there; sent on every call because a phone
    // that was offline at the start still has to say it eventually.
    await _reportLifecycle(remoteGroupId, remoteMeetingId, 'STARTED', meeting.date);
    return remoteMeetingId;
  }

  /// Tells the server what a person did to a meeting on this phone.
  ///
  /// A refusal never fails the sync: a server from before this existed
  /// answers 404, and the meeting's records matter more than its status. A cancelled server
  /// meeting (the console cancelled a plan this phone then held) is left as
  /// the console set it and logged.
  Future<void> _reportLifecycle(
    String remoteGroupId,
    String remoteMeetingId,
    String event,
    DateTime at,
  ) async {
    try {
      await _writeApi.reportMeetingLifecycle(
        groupId: remoteGroupId,
        meetingId: remoteMeetingId,
        event: event,
        at: at,
      );
    } on ApiException catch (e) {
      // No signal: fail this pass so it is tried again, rather than leaving
      // the server showing a meeting in progress that the phone has closed.
      if (e.statusCode == 0) rethrow;
      log.warn('sync', 'Meeting $remoteMeetingId: $event not recorded: ${e.message}');
    }
  }

  Future<MeetingSyncResult> syncMeeting(Meeting meeting) async {
    final remoteGroupId = await _idMap.remoteId(MapEntity.group, meeting.groupId);
    if (remoteGroupId == null) {
      throw const ApiException(
        'This group is not linked to the backend yet. Link it in Server → '
        'Sync before pushing meetings.',
      );
    }
    log.info('sync', 'Syncing meeting ${meeting.number} (${meeting.id})');

    // 1. Ensure a backend meeting exists and is mapped.
    final remoteMeetingId = await ensureRemoteMeeting(meeting);

    final memberMap = await _idMap.mappings(MapEntity.member);
    final conflicts = <SyncConflict>[];
    var synced = 0;
    final now = DateTime.now();

    void conflict(String kind, String code, String message,
        [String? clientRequestId]) {
      conflicts.add(SyncConflict(
        meetingId: meeting.id,
        kind: kind,
        clientRequestId: clientRequestId,
        code: code,
        message: message,
        createdAt: now,
      ));
    }

    // 2. Attendance (upsert per mapped member).
    final db = await _db.database;
    final attendance = await db.query('attendance',
        where: 'meeting_id = ?', whereArgs: [meeting.id]);
    for (final row in attendance) {
      final localMemberId = row['member_id'] as String;
      final remoteMemberId = memberMap[localMemberId];
      if (remoteMemberId == null) {
        conflict('attendance', 'MEMBER_NOT_MAPPED',
            'Member is not linked to the backend.');
        continue;
      }
      final present = (row['present'] as int) == 1;
      try {
        await _writeApi.putAttendance(
          groupId: remoteGroupId,
          meetingId: remoteMeetingId,
          memberId: remoteMemberId,
          status: present ? 'PRESENT' : 'ABSENT',
        );
        synced++;
      } on ApiException catch (e) {
        conflict('attendance', _codeOf(e), e.message);
      }
    }

    // 3. Ledger entries.
    final entries = await _collectLedgerEntries(meeting.id, memberMap, conflict);
    for (final entry in entries) {
      try {
        await _writeApi.postLedgerEntry(
          groupId: remoteGroupId,
          meetingId: remoteMeetingId,
          entry: entry,
        );
        synced++;
      } on ApiException catch (e) {
        conflict('ledgerEntry', _codeOf(e), e.message, entry.clientRequestId);
      }
    }

    // 4. Fines now ride the meeting ledger as FINE_COLLECTION (Gap 3), so
    // they are collected alongside the other entries above — nothing skipped.
    const skippedFines = 0;

    // Closed on the phone: the server's copy is closed too, after its records.
    if (!meeting.isOpen) {
      await _reportLifecycle(remoteGroupId, remoteMeetingId, 'CLOSED',
          meeting.closedAt ?? DateTime.now());
    }

    await _idMap.replaceConflicts(meeting.id, conflicts);
    // Only now: a pass that stopped part-way (the signal went, the app was
    // closed) leaves the meeting unmapped, so it is tried again rather than
    // being counted as backed up. Anything that did not go through is a
    // recorded conflict, which keeps it pending too.
    await _idMap.put(MapEntity.meeting, meeting.id, remoteMeetingId,
        groupId: remoteGroupId);
    log.info('sync',
        'Meeting ${meeting.number}: synced=$synced conflicts=${conflicts.length} skippedFines=$skippedFines');

    return MeetingSyncResult(
      remoteMeetingId: remoteMeetingId,
      syncedCount: synced,
      conflicts: conflicts,
      skippedFines: skippedFines,
    );
  }

  Future<List<LedgerEntryInput>> _collectLedgerEntries(
    String meetingId,
    Map<String, String> memberMap,
    void Function(String, String, String, [String?]) conflict,
  ) async {
    final db = await _db.database;
    final result = <LedgerEntryInput>[];

    String? remote(String localMemberId, String kind, String clientRequestId) {
      final id = memberMap[localMemberId];
      if (id == null) {
        conflict(kind, 'MEMBER_NOT_MAPPED',
            'Member is not linked to the backend.', clientRequestId);
      }
      return id;
    }

    // Share purchases -> SHARE_PURCHASE (carries payment method/reference).
    for (final row in await db.query('share_purchases',
        where: 'meeting_id = ?', whereArgs: [meetingId])) {
      final crid = 'shr-${row['id']}';
      final member = remote(row['member_id'] as String, 'ledgerEntry', crid);
      if (member == null) continue;
      final method = enumFromName(PaymentMethod.values,
          (row['payment_method'] ?? 'cash') as String, PaymentMethod.cash);
      result.add(LedgerEntryInput(
        memberId: member,
        type: 'SHARE_PURCHASE',
        amountCents: _cents(row['amount'] as num),
        description: '${row['shares']} share(s) · ${method.label}',
        externalReference: row['payment_reference'] as String?,
        clientRequestId: crid,
      ));
    }

    // Social fund -> SOCIAL_CONTRIBUTION.
    for (final row in await db.query('social_fund_entries',
        where: 'meeting_id = ?', whereArgs: [meetingId])) {
      final crid = 'soc-${row['id']}';
      final member = remote(row['member_id'] as String, 'ledgerEntry', crid);
      if (member == null) continue;
      result.add(LedgerEntryInput(
        memberId: member,
        type: 'SOCIAL_CONTRIBUTION',
        amountCents: _cents(row['amount'] as num),
        description: 'Social fund contribution',
        clientRequestId: crid,
      ));
    }

    // Loans disbursed in this meeting -> INTERNAL_LOAN_DISBURSEMENT.
    for (final row in await db.query('loans',
        where: 'meeting_id = ?', whereArgs: [meetingId])) {
      final crid = 'lnd-${row['id']}';
      final member = remote(row['member_id'] as String, 'ledgerEntry', crid);
      if (member == null) continue;
      final agreed = Loan.fromMap({...row, 'amount_repaid': 0, 'member_name': ''});
      result.add(LedgerEntryInput(
        memberId: member,
        type: 'INTERNAL_LOAN_DISBURSEMENT',
        amountCents: _cents(row['principal'] as num),
        description: 'Loan disbursement',
        clientRequestId: crid,
        // The terms THIS loan was agreed at, so the server charges exactly
        // what the phone does (month by month, same rule).
        loan: {
          'termMonths': agreed.termMonths,
          'interestRateBps': (agreed.interestRate * 100).round(),
          'interestType': agreed.interestType == InterestType.reducingBalance ? 'REDUCING' : 'FLAT',
        },
      ));
    }

    // Repayments in this meeting -> LOAN_REPAYMENT (member via the loan).
    for (final row in await db.rawQuery('''
      SELECT r.id, r.amount, l.member_id
      FROM loan_repayments r JOIN loans l ON l.id = r.loan_id
      WHERE r.meeting_id = ?
    ''', [meetingId])) {
      final crid = 'rpy-${row['id']}';
      final member = remote(row['member_id'] as String, 'ledgerEntry', crid);
      if (member == null) continue;
      result.add(LedgerEntryInput(
        memberId: member,
        type: 'LOAN_REPAYMENT',
        amountCents: _cents(row['amount'] as num),
        description: 'Loan repayment',
        clientRequestId: crid,
      ));
    }

    // Fines -> FINE_COLLECTION (credits the SOCIAL fund on the backend).
    for (final row in await db.query('fines',
        where: 'meeting_id = ?', whereArgs: [meetingId])) {
      final crid = 'fin-${row['id']}';
      final member = remote(row['member_id'] as String, 'ledgerEntry', crid);
      if (member == null) continue;
      final reason = (row['reason'] as String?)?.trim();
      result.add(LedgerEntryInput(
        memberId: member,
        type: 'FINE_COLLECTION',
        amountCents: _cents(row['amount'] as num),
        description:
            reason == null || reason.isEmpty ? 'Fine' : 'Fine · $reason',
        clientRequestId: crid,
      ));
    }

    // A zero-value entry (a "paid KSh 0" social fund tick made while the amount
    // was unset) carries no money, and the server refuses anything below one
    // cent. Sent, it would sit as a permanent conflict and keep the meeting on
    // "waiting to back up" for ever; dropped, nothing is lost.
    result.removeWhere((entry) => entry.amountCents <= 0);

    return result;
  }

  String _codeOf(ApiException e) =>
      e.statusCode == 0 ? 'NETWORK' : 'HTTP_${e.statusCode}';
}
