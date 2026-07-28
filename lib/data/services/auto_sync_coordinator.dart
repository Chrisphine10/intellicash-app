import '../../core/utils/app_logger.dart';
import '../models/meeting.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/meeting_repository.dart';
import 'write_sync_service.dart';

/// Pushes local writes to the backend automatically when connectivity returns.
///
/// It does not invent a new sync mechanism: it runs the same idempotent
/// per-meeting write-sync the manual "Sync" screen uses (`WriteSyncService`),
/// over every group this device has bound to a backend group. Because each
/// entry carries a `clientRequestId`, re-running a sync that already partly
/// succeeded is safe — the server ignores what it has already stored.
///
/// A group that has not been linked to the backend is skipped, not failed:
/// its data stays on the phone until someone links it, which is the correct
/// behaviour, not a lost write.
class AutoSyncCoordinator {
  AutoSyncCoordinator({
    required IdMapRepository idMap,
    required MeetingRepository meetings,
    required WriteSyncService writeSync,
  })  : _idMap = idMap,
        _meetings = meetings,
        _writeSync = writeSync;

  final IdMapRepository _idMap;
  final MeetingRepository _meetings;
  final WriteSyncService _writeSync;

  /// How many closed meetings are still waiting to reach the backend, across
  /// every bound group. This is what the "waiting to back up" badge shows.
  ///
  /// A meeting is still pending when it has never been pushed (no backend
  /// mapping yet) or when its last push left conflicts. Open meetings are not
  /// counted — they are still being recorded, not waiting to sync — and an
  /// unbound group contributes nothing, because there is nowhere for its data
  /// to back up to until it is linked. So the count only ever reflects work
  /// the sync can actually do, and drops to zero once everything is through.
  Future<int> pendingMeetings() async {
    final boundGroups = await _idMap.mappings(MapEntity.group);
    if (boundGroups.isEmpty) return 0;

    var pending = 0;
    for (final localGroupId in boundGroups.keys) {
      final items = await _meetings.meetingsForGroup(localGroupId);
      for (final item in items) {
        if (await _needsSync(item.meeting)) pending++;
      }
    }
    return pending;
  }

  /// Syncs the closed meetings of every bound group that still need it, and
  /// returns the number of records the backend accepted.
  ///
  /// It skips meetings already fully backed up: re-pushing every closed
  /// meeting on every reconnect would be idempotent but re-upload the whole
  /// history each time — real cost on a metered connection. So it syncs
  /// exactly what the badge counts as pending, and no more.
  ///
  /// Never throws: one group or meeting failing (offline mid-run, a member not
  /// yet mapped) must not stop the others, and a background reconnect has
  /// nowhere to surface an exception anyway.
  Future<int> syncBoundGroups() async {
    final boundGroups = await _idMap.mappings(MapEntity.group);
    if (boundGroups.isEmpty) return 0;

    var records = 0;
    for (final localGroupId in boundGroups.keys) {
      try {
        final items = await _meetings.meetingsForGroup(localGroupId);
        for (final item in items) {
          if (!await _needsSync(item.meeting)) continue;
          try {
            final result = await _writeSync.syncMeeting(item.meeting);
            records += result.syncedCount;
          } catch (e) {
            log.warn('autosync',
                'Meeting ${item.meeting.number} did not sync: $e');
          }
        }
      } catch (e) {
        log.warn('autosync', 'Group $localGroupId did not sync: $e');
      }
    }
    if (records > 0) {
      log.info('autosync', 'Auto-synced $records record(s) on reconnect');
    }
    return records;
  }

  /// Whether a meeting is still waiting to reach the backend.
  ///
  /// The single definition of "pending", so the badge count and what the sync
  /// actually pushes can never diverge. An open meeting is still being
  /// recorded; a meeting with no backend mapping was never pushed; a mapped
  /// meeting with conflicts was only partly pushed. Anything else is done.
  Future<bool> _needsSync(Meeting meeting) async {
    if (meeting.isOpen) return false;
    final mapped = await _idMap.remoteId(MapEntity.meeting, meeting.id);
    if (mapped == null) return true;
    final conflicts = await _idMap.conflictsForMeeting(meeting.id);
    return conflicts.isNotEmpty;
  }
}
