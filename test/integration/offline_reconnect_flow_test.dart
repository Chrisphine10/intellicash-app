import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/auto_sync_coordinator.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';
import 'package:intellicash_mobile/data/services/write_sync_service.dart';

/// A backend that accepts everything, without a network. Its `online` flag
/// stands in for connectivity: while false, every call throws, exactly as an
/// offline device behaves.
class _FakeBackend extends RemoteWriteApi {
  _FakeBackend()
      : super(ApiClient(
            credentials: () => const ApiCredentials(baseUrl: '', apiKey: '')));

  bool online = false;
  int accepted = 0;

  void _guard() {
    if (!online) throw Exception('offline');
  }

  @override
  Future<String> createMeeting({
    required String groupId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    _guard();
    return 'remote-meeting-1';
  }

  @override
  Future<void> putAttendance({
    required String groupId,
    required String meetingId,
    required String memberId,
    required String status,
  }) async {
    _guard();
    accepted++;
  }

  @override
  Future<void> postLedgerEntry({
    required String groupId,
    required String meetingId,
    required LedgerEntryInput entry,
  }) async {
    _guard();
    accepted++;
  }
}

/// The full journey a real device takes: record a meeting with no signal,
/// then get connectivity back and watch it sync on its own.
void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late MeetingRepository meetings;
  late IdMapRepository idMap;
  late _FakeBackend backend;
  late SyncService syncService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_reconnect');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    meetings = MeetingRepository(db);
    idMap = IdMapRepository(db);
    backend = _FakeBackend();

    final writeSync = WriteSyncService(db: db, idMap: idMap, writeApi: backend);
    final coordinator = AutoSyncCoordinator(
      idMap: idMap,
      meetings: meetings,
      writeSync: writeSync,
    );
    // Wired exactly as main.dart wires it.
    syncService = SyncService(SyncRepository(db));
    syncService.onSync = coordinator.syncBoundGroups;
    syncService.pendingProbe = coordinator.pendingMeetings;
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

  test('records offline, then syncs itself when the signal returns', () async {
    // 1. A whole meeting recorded with no internet.
    final group = await seedGroup();
    final roster = await members.membersForGroup(group.id);
    final meeting = await meetings.startMeeting(group);
    for (final m in roster) {
      await meetings.setAttendance(meeting: meeting, memberId: m.id, present: true);
    }
    await meetings.closeMeeting(meeting);

    // 2. The group has been linked to the backend and its members matched.
    await idMap.put(MapEntity.group, group.id, 'remote-group-1',
        groupId: 'remote-group-1');
    for (final m in roster) {
      await idMap.put(MapEntity.member, m.id, 'r-${m.id}',
          groupId: 'remote-group-1');
    }

    // 3. Still offline: the badge shows the meeting waiting, and a sync
    //    attempt changes nothing — the records stay safe on the phone.
    expect(await syncService.pendingCount(), 1);
    expect(await syncService.pushNow(), 0, reason: 'offline: nothing accepted');
    expect(await syncService.pendingCount(), 1, reason: 'still waiting');

    // 4. Connectivity returns. This is the call the connectivity listener
    //    makes on reconnect.
    backend.online = true;
    final synced = await syncService.pushNow();

    // 5. It backed itself up, and the badge cleared.
    expect(synced, greaterThan(0));
    expect(backend.accepted, greaterThan(0));
    expect(await syncService.pendingCount(), 0, reason: 'backed up, badge clear');
  });

  test('a second reconnect is a no-op once everything is backed up', () async {
    final group = await seedGroup();
    final roster = await members.membersForGroup(group.id);
    final meeting = await meetings.startMeeting(group);
    for (final m in roster) {
      await meetings.setAttendance(meeting: meeting, memberId: m.id, present: true);
    }
    await meetings.closeMeeting(meeting);
    await idMap.put(MapEntity.group, group.id, 'remote-group-1',
        groupId: 'remote-group-1');
    // Every member mapped, so the sync leaves no conflict behind.
    for (final m in roster) {
      await idMap.put(MapEntity.member, m.id, 'r-${m.id}',
          groupId: 'remote-group-1');
    }

    backend.online = true;
    await syncService.pushNow();
    expect(await syncService.pendingCount(), 0);

    // A later reconnect finds nothing new to send.
    final acceptedAfterFirst = backend.accepted;
    final second = await syncService.pushNow();
    expect(second, 0);
    expect(backend.accepted, acceptedAfterFirst,
        reason: 're-sync must not re-send an already-synced meeting');
  });
}
