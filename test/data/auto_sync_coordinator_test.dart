import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/meeting.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/services/auto_sync_coordinator.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/write_sync_service.dart';

/// Records which meetings it was asked to sync, without any network. Returns a
/// canned result so the coordinator's own logic — which groups and which
/// meetings it touches — is what gets exercised.
class _RecordingWriteSync extends WriteSyncService {
  _RecordingWriteSync(AppDatabase db, IdMapRepository idMap)
      : super(
          db: db,
          idMap: idMap,
          writeApi: RemoteWriteApi(
            ApiClient(credentials: () => const ApiCredentials(baseUrl: '', apiKey: '')),
          ),
        );

  final List<String> syncedMeetingIds = [];
  bool throwOnce = false;

  @override
  Future<MeetingSyncResult> syncMeeting(Meeting meeting) async {
    if (throwOnce) {
      throwOnce = false;
      throw Exception('offline mid-sync');
    }
    syncedMeetingIds.add(meeting.id);
    return const MeetingSyncResult(
      remoteMeetingId: 'r',
      syncedCount: 4,
      conflicts: [],
      skippedFines: 0,
    );
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MeetingRepository meetings;
  late IdMapRepository idMap;
  late _RecordingWriteSync writeSync;
  late AutoSyncCoordinator coordinator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_autosync');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    meetings = MeetingRepository(db);
    idMap = IdMapRepository(db);
    writeSync = _RecordingWriteSync(db, idMap);
    coordinator = AutoSyncCoordinator(
      idMap: idMap,
      meetings: meetings,
      writeSync: writeSync,
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<Group> seedGroup() => groups.createGroup(
        name: 'Umoja Women Group',
        cycleNumber: 1,
        savingsMode: SavingsMode.fixed,
        shareValue: 100,
        maxSharesPerMeeting: 10,
        socialFundAmount: 50,
        interestRate: 5,
        interestType: InterestType.reducingBalance,
        loanMultiplier: 2,
        defaultLoanTermMonths: 3,
        meetingFrequency: MeetingFrequency.weekly,
        meetingDays: const [DateTime.sunday],
        memberNames: ['Achieng Odhiambo', 'Wanjiku Kamau'],
      );

  test('syncs nothing when no group is bound to the backend', () async {
    final group = await seedGroup();
    final meeting = await meetings.startMeeting(group);
    await meetings.closeMeeting(meeting);
    // Group is closed and ready, but never linked — so it stays on the phone.
    expect(await coordinator.syncBoundGroups(), 0);
    expect(writeSync.syncedMeetingIds, isEmpty);
  });

  test('syncs a bound group\'s closed meeting on reconnect', () async {
    final group = await seedGroup();
    final meeting = await meetings.startMeeting(group);
    await meetings.closeMeeting(meeting);
    await idMap.put(MapEntity.group, group.id, 'remote-group-1',
        groupId: 'remote-group-1');

    final records = await coordinator.syncBoundGroups();
    expect(records, 4);
    expect(writeSync.syncedMeetingIds, [meeting.id]);
  });

  test('leaves an open meeting alone — it is still being recorded', () async {
    final group = await seedGroup();
    await meetings.startMeeting(group); // left open
    await idMap.put(MapEntity.group, group.id, 'remote-group-1',
        groupId: 'remote-group-1');

    expect(await coordinator.syncBoundGroups(), 0);
    expect(writeSync.syncedMeetingIds, isEmpty);
  });

  group('pending badge count', () {
    test('is zero when no group is bound, whatever is on the phone', () async {
      final group = await seedGroup();
      final meeting = await meetings.startMeeting(group);
      await meetings.closeMeeting(meeting);
      // Offline-only VSLA, never linked: nothing is "waiting to back up".
      expect(await coordinator.pendingMeetings(), 0);
    });

    test('counts a closed, never-synced meeting in a bound group', () async {
      final group = await seedGroup();
      final meeting = await meetings.startMeeting(group);
      await meetings.closeMeeting(meeting);
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');

      expect(await coordinator.pendingMeetings(), 1);
    });

    test('does not count an open meeting still being recorded', () async {
      final group = await seedGroup();
      await meetings.startMeeting(group); // left open
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');

      expect(await coordinator.pendingMeetings(), 0);
    });

    test('drops to zero once the meeting has synced', () async {
      final group = await seedGroup();
      final meeting = await meetings.startMeeting(group);
      await meetings.closeMeeting(meeting);
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');
      expect(await coordinator.pendingMeetings(), 1);

      // A sync maps the meeting; the fake records no conflicts.
      await idMap.put(MapEntity.meeting, meeting.id, 'remote-meeting-1',
          groupId: 'remote-group-1');
      expect(await coordinator.pendingMeetings(), 0);
    });

    test('still counts a synced meeting that left conflicts', () async {
      final group = await seedGroup();
      final meeting = await meetings.startMeeting(group);
      await meetings.closeMeeting(meeting);
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');
      await idMap.put(MapEntity.meeting, meeting.id, 'remote-meeting-1',
          groupId: 'remote-group-1');

      // Something did not go through — it is still waiting, not done.
      await idMap.replaceConflicts(meeting.id, [
        SyncConflict(
          meetingId: meeting.id,
          kind: 'ledgerEntry',
          code: 'MEMBER_NOT_MAPPED',
          message: 'x',
          createdAt: DateTime.now(),
        ),
      ]);
      expect(await coordinator.pendingMeetings(), 1);
    });
  });

  test('one meeting failing does not stop the reconnect from finishing',
      () async {
    final group = await seedGroup();
    final first = await meetings.startMeeting(group);
    await meetings.closeMeeting(first);
    await idMap.put(MapEntity.group, group.id, 'remote-group-1',
        groupId: 'remote-group-1');

    // The first attempt throws (offline mid-run); the coordinator swallows it
    // and returns, rather than bubbling up into a background reconnect.
    writeSync.throwOnce = true;
    final records = await coordinator.syncBoundGroups();
    expect(records, 0);

    // And a later reconnect picks it up cleanly — nothing was lost.
    final retry = await coordinator.syncBoundGroups();
    expect(retry, 4);
    expect(writeSync.syncedMeetingIds, [first.id]);
  });
}
