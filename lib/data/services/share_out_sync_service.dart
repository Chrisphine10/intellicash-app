import '../../core/database/app_database.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/app_logger.dart';
import '../repositories/id_map_repository.dart';
import 'remote_write_api.dart';

/// One member's line of a share-out this phone made, as it was paid.
class ShareOutBatchLine {
  const ShareOutBatchLine({
    required this.localMemberId,
    required this.shareCents,
    required this.grossPayoutCents,
    required this.welfarePayoutCents,
    required this.loanOffsetCents,
    required this.netPayoutCents,
  });

  final String localMemberId;
  final int shareCents;
  final int grossPayoutCents;
  final int welfarePayoutCents;
  final int loanOffsetCents;
  final int netPayoutCents;
}

/// A whole share-out (one group, one cycle) waiting to be sent.
class ShareOutBatch {
  const ShareOutBatch({
    required this.localGroupId,
    required this.cycleNumber,
    required this.createdAt,
    required this.lines,
  });

  final String localGroupId;
  final int cycleNumber;

  /// When the group shared out. Meetings recorded after this belong to the NEXT
  /// cycle, which is how the sync knows what has to reach the server first.
  final DateTime createdAt;
  final List<ShareOutBatchLine> lines;

  /// Names this share-out in the id map and in the conflicts table.
  String get key => '$localGroupId#$cycleNumber';

  /// What the server remembers it by, so a retry is recognised as a retry.
  String get shareOutId => '$localGroupId-c$cycleNumber';
}

enum ShareOutSendOutcome {
  /// The server recorded it and closed the cycle.
  sent,

  /// The server had already closed that cycle - it was shared out elsewhere (the
  /// web console). Sending it would pay the members twice, so it was not sent
  /// and there is nothing left to do.
  alreadyOnline,

  /// No signal, the session ended, or the server had a bad moment. Nothing is
  /// wrong with the share-out; it is simply tried again later.
  offline,

  /// This share-out cannot be sent yet (a member is not linked) or at all
  /// without someone looking at it: see [ShareOutSendResult.message].
  blocked,

  /// The group is not linked to the online record, so there is nowhere to send it.
  notLinked,
}

class ShareOutSendResult {
  const ShareOutSendResult(this.outcome, {this.message, this.code});

  final ShareOutSendOutcome outcome;

  /// Plain words for the person, when there is something to say.
  final String? message;

  /// The server's reason, for a refusal.
  final String? code;

  bool get done =>
      outcome == ShareOutSendOutcome.sent ||
      outcome == ShareOutSendOutcome.alreadyOnline;
}

/// Where a past share-out stands with the online record.
enum ShareOutSyncState {
  /// Recorded online.
  sent,

  /// The online record had closed that cycle already; this phone's copy was not sent.
  alreadyOnline,

  /// Made before share-outs could be sent online. Never sent, and not held up.
  beforeOnlineRecording,

  /// Not sent yet; nothing is wrong (no signal, earlier meetings still going up).
  waiting,

  /// The server refused it. [ShareOutSyncStatus.message] says why.
  blocked,
}

class ShareOutSyncStatus {
  const ShareOutSyncStatus(this.state, {this.message, this.code});

  final ShareOutSyncState state;
  final String? message;
  final String? code;

  /// Someone may want to send it now.
  bool get canSend =>
      state == ShareOutSyncState.waiting || state == ShareOutSyncState.blocked;

  /// The refusal that a person may knowingly override: the online record does
  /// not hold the same share purchases as this phone.
  bool get canSendAnyway => code == 'SHARE_OUT_OUT_OF_STEP';
}

/// Sends the share-outs a phone has made to the online record.
///
/// A share-out is money that has already been counted out at the table, so the
/// server is told what was paid rather than asked to work it out. The server
/// records it and closes the cycle in one step, or refuses it whole; a refusal
/// is remembered so the person can see why (see [statuses]) and is never
/// silently retried into a different answer.
///
/// Order matters: a cycle's meetings must reach the server before its
/// share-out, and the next cycle's meetings after it, or the server would file
/// them under the wrong cycle. `AutoSyncCoordinator` does the ordering; this
/// class only knows how to send one share-out.
class ShareOutSyncService {
  ShareOutSyncService({
    required AppDatabase db,
    required IdMapRepository idMap,
    required RemoteWriteApi writeApi,
  })  : _db = db,
        _idMap = idMap,
        _writeApi = writeApi;

  final AppDatabase _db;
  final IdMapRepository _idMap;
  final RemoteWriteApi _writeApi;

  /// Written into the id map for a share-out that the server had already closed.
  static const alreadyOnlineMarker = 'already-online';

  /// Written for share-outs made before this existed (see the schema upgrade).
  static const beforeOnlineRecordingMarker = 'before-online-recording';

  static int _cents(num kes) => (kes * 100).round();

  static String conflictKey(ShareOutBatch batch) => 'shareout:${batch.key}';

  /// Whether the group is linked to the online record - the only way a share-out
  /// it makes can be sent.
  Future<bool> isLinked(String localGroupId) async =>
      await _idMap.remoteId(MapEntity.group, localGroupId) != null;

  /// Every share-out the group has made, oldest cycle first.
  Future<List<ShareOutBatch>> batches(String localGroupId) async {
    final db = await _db.database;
    final rows = await db.query(
      'share_out_payouts',
      where: 'group_id = ?',
      whereArgs: [localGroupId],
      orderBy: 'cycle_number ASC, member_name COLLATE NOCASE',
    );
    final byCycle = <int, List<Map<String, Object?>>>{};
    for (final row in rows) {
      (byCycle[row['cycle_number'] as int] ??= []).add(row);
    }
    return [
      for (final entry in byCycle.entries)
        ShareOutBatch(
          localGroupId: localGroupId,
          cycleNumber: entry.key,
          createdAt: entry.value
              .map((row) => DateTime.parse(row['created_at'] as String))
              .reduce((a, b) => a.isBefore(b) ? a : b),
          lines: [
            for (final row in entry.value)
              ShareOutBatchLine(
                localMemberId: row['member_id'] as String,
                shareCents: _cents(row['share_amount'] as num),
                grossPayoutCents: _cents(row['gross_payout'] as num),
                welfarePayoutCents: _cents(row['welfare_payout'] as num),
                loanOffsetCents: _cents(row['loan_offset'] as num),
                netPayoutCents: _cents(row['net_payout'] as num),
              ),
          ],
        ),
    ];
  }

  /// The share-outs that have not been dealt with online, oldest first.
  Future<List<ShareOutBatch>> unsent(String localGroupId) async {
    final handled = await _idMap.mappings(MapEntity.shareOut);
    return [
      for (final batch in await batches(localGroupId))
        if (!handled.containsKey(batch.key)) batch,
    ];
  }

  /// How each past share-out stands, keyed by cycle number.
  Future<Map<int, ShareOutSyncStatus>> statuses(String localGroupId) async {
    final handled = await _idMap.mappings(MapEntity.shareOut);
    final result = <int, ShareOutSyncStatus>{};
    for (final batch in await batches(localGroupId)) {
      final remote = handled[batch.key];
      if (remote == alreadyOnlineMarker) {
        result[batch.cycleNumber] =
            const ShareOutSyncStatus(ShareOutSyncState.alreadyOnline);
      } else if (remote == beforeOnlineRecordingMarker) {
        result[batch.cycleNumber] =
            const ShareOutSyncStatus(ShareOutSyncState.beforeOnlineRecording);
      } else if (remote != null) {
        result[batch.cycleNumber] =
            const ShareOutSyncStatus(ShareOutSyncState.sent);
      } else {
        final conflicts = await _idMap.conflictsForMeeting(conflictKey(batch));
        result[batch.cycleNumber] = conflicts.isEmpty
            ? const ShareOutSyncStatus(ShareOutSyncState.waiting)
            : ShareOutSyncStatus(
                ShareOutSyncState.blocked,
                message: conflicts.first.message,
                code: conflicts.first.code,
              );
      }
    }
    return result;
  }

  /// The first refusal among this group's unsent share-outs, for the sync screen.
  Future<String?> attention(String localGroupId) async {
    final status = await statuses(localGroupId);
    for (final entry in status.entries) {
      if (entry.value.state == ShareOutSyncState.blocked) {
        return 'The Cycle ${entry.key} share-out has not reached the online '
            'record. ${entry.value.message ?? ''}'.trim();
      }
    }
    return null;
  }

  /// Sends one share-out. Never throws: a refusal is remembered and returned,
  /// and a failure of the network is just "try again later".
  ///
  /// [force] records it although the online share purchases differ from the
  /// phone's - only ever set by a person who has been told so.
  Future<ShareOutSendResult> send(ShareOutBatch batch, {bool force = false}) async {
    final remoteGroupId =
        await _idMap.remoteId(MapEntity.group, batch.localGroupId);
    if (remoteGroupId == null) {
      return const ShareOutSendResult(ShareOutSendOutcome.notLinked);
    }

    final memberMap = await _idMap.mappings(MapEntity.member);
    final lines = <ShareOutLineInput>[];
    for (final line in batch.lines) {
      final remote = memberMap[line.localMemberId];
      if (remote == null) {
        // Members are sent up before anything else, so this is a member that
        // has not gone yet (no signal), not a share-out that is wrong.
        return const ShareOutSendResult(
          ShareOutSendOutcome.blocked,
          message: 'A member in it is not linked to the online record yet.',
          code: 'MEMBER_NOT_MAPPED',
        );
      }
      lines.add(ShareOutLineInput(
        memberId: remote,
        shareCents: line.shareCents,
        grossPayoutCents: line.grossPayoutCents,
        welfarePayoutCents: line.welfarePayoutCents,
        loanOffsetCents: line.loanOffsetCents,
        netPayoutCents: line.netPayoutCents,
      ));
    }

    try {
      final recorded = await _writeApi.recordShareOut(
        groupId: remoteGroupId,
        shareOutId: batch.shareOutId,
        cycleNumber: batch.cycleNumber,
        lines: lines,
        force: force,
      );
      await _idMap.put(MapEntity.shareOut, batch.key, recorded.closedCycleId,
          groupId: remoteGroupId);
      await _idMap.replaceConflicts(conflictKey(batch), const []);
      log.info('sync', 'Cycle ${batch.cycleNumber} share-out recorded online');
      return const ShareOutSendResult(ShareOutSendOutcome.sent);
    } on ApiException catch (e) {
      // Not the share-out's fault: nothing to record, just try again.
      if (e.statusCode == 0 ||
          e.statusCode == 401 ||
          e.statusCode == 429 ||
          e.statusCode >= 500) {
        return ShareOutSendResult(ShareOutSendOutcome.offline, message: e.message);
      }
      if (e.code == 'SHARE_OUT_CYCLE_CLOSED') {
        // Shared out elsewhere already. Sending it would pay twice; there is
        // nothing more for this phone to do, so it stops holding the sync up.
        await _idMap.put(
            MapEntity.shareOut, batch.key, alreadyOnlineMarker,
            groupId: remoteGroupId);
        await _idMap.replaceConflicts(conflictKey(batch), const []);
        log.warn('sync',
            'Cycle ${batch.cycleNumber} was already shared out online; the phone\'s copy was not sent');
        return ShareOutSendResult(ShareOutSendOutcome.alreadyOnline,
            message: e.message, code: e.code);
      }
      await _remember(batch, e.code ?? 'HTTP_${e.statusCode}', e.message);
      log.warn('sync',
          'Cycle ${batch.cycleNumber} share-out was refused: ${e.message}');
      return ShareOutSendResult(ShareOutSendOutcome.blocked,
          message: e.message, code: e.code);
    }
  }

  Future<void> _remember(ShareOutBatch batch, String code, String message) {
    return _idMap.replaceConflicts(conflictKey(batch), [
      SyncConflict(
        meetingId: conflictKey(batch),
        kind: 'shareOut',
        code: code,
        message: message,
        createdAt: DateTime.now(),
      ),
    ]);
  }
}
