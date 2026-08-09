import '../../core/network/api_exception.dart';
import '../repositories/outbox_repository.dart';
import '../repositories/visit_repository.dart';
import 'remote_visits_api.dart';

/// Pushes recorded visits to the server.
///
/// Deliberately small: the outbox decides WHAT is due and WHEN to try again,
/// the repository holds the data, and this only performs one attempt per due
/// entry and reports what happened.
class VisitSyncService {
  VisitSyncService({
    required RemoteVisitsApi api,
    VisitRepository? visits,
    OutboxRepository? outbox,
  })  : _api = api,
        _visits = visits ?? VisitRepository(),
        _outbox = outbox ?? OutboxRepository();

  final RemoteVisitsApi _api;
  final VisitRepository _visits;
  final OutboxRepository _outbox;

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

    return synced;
  }

  /// Queues a finished visit. Idempotent — the outbox refuses a second entry
  /// for the same record.
  Future<void> queue(String visitId) =>
      _outbox.enqueue(recordType: OutboxRecordType.visit, recordId: visitId);

  Future<int> pendingCount() => _outbox.pendingCount();
}
