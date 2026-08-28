import '../../core/network/api_exception.dart';
import '../repositories/assessment_repository.dart';
import '../repositories/outbox_repository.dart';
import '../repositories/visit_repository.dart';
import 'remote_assessments_api.dart';
import 'remote_visits_api.dart';

/// Pushes recorded visits to the server.
///
/// Deliberately small: the outbox decides WHAT is due and WHEN to try again,
/// the repository holds the data, and this only performs one attempt per due
/// entry and reports what happened.
class VisitSyncService {
  VisitSyncService({
    required RemoteVisitsApi api,
    RemoteAssessmentsApi? assessmentsApi,
    VisitRepository? visits,
    OutboxRepository? outbox,
    AssessmentRepository? assessments,
  })  : _api = api,
        _assessmentsApi = assessmentsApi,
        _visits = visits ?? VisitRepository(),
        _outbox = outbox ?? OutboxRepository(),
        _assessments = assessments ?? AssessmentRepository();

  final RemoteVisitsApi _api;

  /// Null in tests that only exercise the visit path, and on a build with no
  /// scorecard configured. Assessments are then simply never pushed, which is
  /// the correct degradation: the visit still syncs.
  final RemoteAssessmentsApi? _assessmentsApi;
  final VisitRepository _visits;
  final OutboxRepository _outbox;
  final AssessmentRepository _assessments;

  /// Error codes that will fail identically however many times they are tried.
  ///
  /// Retrying these forever drains the battery and, worse, hides the problem
  /// from the only person who can fix it. A visit for a group the agent no
  /// longer holds needs a human, not another attempt.
  static const _permanent = {
    'GROUP_NOT_FOUND',
    'VISIT_REQUEST_ID_REUSED',
    'VALIDATION_ERROR',
    'FORBIDDEN',
  };

  /// Attempts every due visit. Returns how many reached the server.
  Future<int> pushDue({DateTime? now}) async {
    final due = await _outbox.due(now: now);
    var synced = 0;

    for (final entry in due) {
      if (entry.recordType != OutboxRecordType.visit) continue;

      final visit = await _visits.byId(entry.recordId);
      if (visit == null) {
        // The record went away — an abandoned draft, most likely. Nothing to
        // send, so retiring the entry is correct rather than retrying forever.
        await _outbox.markSynced(entry.id);
        continue;
      }
      if (visit.isSynced) {
        await _outbox.markSynced(entry.id);
        continue;
      }

      try {
        final remote = await _api.submit(
          groupId: visit.remoteGroupId,
          // Re-read from the record at push time, never from the queue entry:
          // a visit corrected after being queued must push the correction.
          clientRequestId: visit.clientRequestId,
          visitType: visit.visitType,
          startedAt: visit.startedAt,
          completedAt: visit.completedAt,
          latitude: visit.latitude,
          longitude: visit.longitude,
          accuracyM: visit.accuracyM,
          locationCapturedAt: visit.locationCapturedAt,
          locationNote: visit.locationNote,
          notes: visit.notes,
        );

        await _visits.markSynced(id: visit.id, remoteId: remote.id);
        await _outbox.markSynced(entry.id);
        synced += 1;

        // The assessment follows the visit it belongs to, and never blocks it.
        // A failure here leaves the answers on the device to be swept up by
        // pushPendingAssessments() on the next sync — losing a visit because
        // its scorecard would not send is not a trade worth making.
        await _pushAssessment(visit.id, remote.id);
      } on ApiException catch (error) {
        await _outbox.markFailure(
          entry.id,
          error: error.message,
          errorCode: error.code,
          permanent: _permanent.contains(error.code),
          now: now,
        );
      } catch (error) {
        // Network, DNS, a captive portal at the county office. All retryable.
        await _outbox.markFailure(
          entry.id,
          error: '$error',
          errorCode: 'NETWORK',
          now: now,
        );
      }
    }

    // Visits that landed earlier but whose assessment did not.
    await pushPendingAssessments();

    // Retire entries that have been done with for a week.
    //
    // `pruneSynced` was written and tested and nothing ever called it, so the
    // outbox only ever grew: every visit this phone has ever sent stayed in
    // the table, and `due()` scanned all of them on every sync. A week is kept
    // rather than deleting on success, because a synced entry is the evidence
    // that a visit was sent — worth having while somebody might still ask.
    await _outbox.pruneSynced(now: now);

    return synced;
  }

  /// Queues a finished visit. Idempotent — the outbox refuses a second entry
  /// for the same record.
  Future<void> queue(String visitId) =>
      _outbox.enqueue(recordType: OutboxRecordType.visit, recordId: visitId);

  Future<int> pendingCount() => _outbox.pendingCount();

  /// Retries assessments for visits already on the server.
  ///
  /// Separate from the outbox on purpose: an assessment is not independently
  /// addressable until its visit has a remote id, and the set of visits waiting
  /// for one is a cheap query rather than something worth queueing.
  Future<int> pushPendingAssessments() async {
    final api = _assessmentsApi;
    if (api == null) return 0;

    var pushed = 0;
    for (final visitId in await _assessments.visitsAwaitingAssessmentPush()) {
      final visit = await _visits.byId(visitId);
      final remoteId = visit?.remoteId;
      if (remoteId == null) continue;
      if (await _pushAssessment(visitId, remoteId)) pushed += 1;
    }
    return pushed;
  }

  /// Sends one visit's answers. Never throws: the caller has already banked a
  /// synced visit and must not have it undone by a scorecard failure.
  Future<bool> _pushAssessment(String localVisitId, String remoteVisitId) async {
    final api = _assessmentsApi;
    if (api == null) return false;

    try {
      final pending = await _assessments.pending(localVisitId);
      // Nothing answered — an agent may legitimately record a visit without
      // filling the form in, and sending an empty assessment would create a
      // 0-scored record that reads as a failed group.
      if (pending == null || pending.isEmpty) return false;

      final result = await api.submit(
        PendingAssessment(
          // The server addresses the visit by ITS id, not the phone's.
          visitId: remoteVisitId,
          snapshotId: pending.snapshotId,
          checksum: pending.checksum,
          answers: pending.answers,
        ),
      );

      await _assessments.markSynced(
        visitId: localVisitId,
        earnedPoints: result.earnedPoints,
        percentage: result.percentage,
        bandKey: result.bandKey,
        bandLabel: result.bandLabel,
      );
      return true;
    } catch (_) {
      // Left provisional, and swept up on the next sync.
      return false;
    }
  }
}
