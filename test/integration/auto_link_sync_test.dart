import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/member.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
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


/// A group set up on the phone — members entered by name only, the group never
/// linked by hand — must still reach the server on its own.
///
/// This is how a group's records could be full on the phone and empty in the
/// console: the phone group was never bound, and members made on the phone
/// were never sent up, so every attendance and payment was dropped as
/// "member not linked to the backend".
void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late MeetingRepository meetings;
  late IdMapRepository idMap;
  late _FakeBackend backend;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_autolink');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    meetings = MeetingRepository(db);
    idMap = IdMapRepository(db);
    backend = _FakeBackend()..online = true;
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<Group> seedGroup(String name) => groups.createGroup(
        name: name,
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
        memberNames: ['Ian Kamau', 'Wanjiku Kamau'],
      );

  RemoteGroup remote(String name, {int members = 0, int meetings = 0}) => RemoteGroup(
        id: 'remote-group-9',
        name: name,
        code: 'IWL-XXX-ABC123',
        phase: 'MOBILISATION',
        county: 'Not set',
        shareValue: 100,
        maxSharesPerMeeting: 10,
        cycleNumber: 1,
        memberCount: members,
        meetingCount: meetings,
      );

  AutoSyncCoordinator coordinator({
    required String? ownGroup,
    required RemoteGroup remoteGroup,
    required List<String> pushed,
  }) =>
      AutoSyncCoordinator(
        idMap: idMap,
        meetings: meetings,
        writeSync: WriteSyncService(db: db, idMap: idMap, writeApi: backend),
        linkSupport: GroupLinkSupport(
          currentGroup: groups.currentGroup,
          membersForGroup: (id) => members.membersForGroup(id),
          ownRemoteGroupId: () async => ownGroup,
          remoteGroup: (_) async => remoteGroup,
          pushMember: (remoteGroupId, Member member) async {
            pushed.add(member.name);
            return 'srv-${member.id}';
          },
        ),
      );

  Future<void> recordClosedMeeting(Group group) async {
    final roster = await members.membersForGroup(group.id);
    final meeting = await meetings.startMeeting(group);
    for (final m in roster) {
      await meetings.setAttendance(meeting: meeting, memberId: m.id, present: true);
    }
    await meetings.closeMeeting(meeting);
  }

  test('binds the group, sends up its members, and the meeting lands', () async {
    final group = await seedGroup('Tsunami SHG');
    await recordClosedMeeting(group);
    final pushed = <String>[];

    // The server group made at sign-up: no members, no meetings yet.
    final sync = coordinator(ownGroup: 'remote-group-9', remoteGroup: remote('Tsunami Self Help'), pushed: pushed);
    await sync.syncBoundGroups();

    expect(await idMap.remoteId(MapEntity.group, group.id), 'remote-group-9');
    expect(pushed, containsAll(['Ian Kamau', 'Wanjiku Kamau']));
    // Both members' attendance reached the server, none dropped as unmapped.
    expect(backend.accepted, greaterThanOrEqualTo(2));
    expect(await sync.pendingMeetings(), 0);

    // A second run sends nothing new: members are mapped, the meeting is done.
    pushed.clear();
    final before = backend.accepted;
    await sync.syncBoundGroups();
    expect(pushed, isEmpty);
    expect(backend.accepted, before);
  });

  test('never binds the phone to a different group that already has records', () async {
    final group = await seedGroup('Tsunami SHG');
    await recordClosedMeeting(group);
    final pushed = <String>[];

    final sync = coordinator(
      ownGroup: 'remote-group-9',
      remoteGroup: remote('Marui Women Group', members: 12, meetings: 30),
      pushed: pushed,
    );
    await sync.syncBoundGroups();

    expect(await idMap.remoteId(MapEntity.group, group.id), isNull);
    expect(pushed, isEmpty);
    expect(backend.accepted, 0);
  });

  test('binds on a matching name even when the server group has records', () async {
    final group = await seedGroup('Marui Women Group');
    final sync = coordinator(
      ownGroup: 'remote-group-9',
      remoteGroup: remote('Marui  women group', members: 12, meetings: 30),
      pushed: <String>[],
    );
    expect(await sync.bindOwnGroupIfClear(), isTrue);
    expect(await idMap.remoteId(MapEntity.group, group.id), 'remote-group-9');
  });

  test('does nothing for an account that is not a group account', () async {
    final group = await seedGroup('Tsunami SHG');
    final sync = coordinator(ownGroup: null, remoteGroup: remote('Tsunami SHG'), pushed: <String>[]);
    expect(await sync.bindOwnGroupIfClear(), isFalse);
    expect(await idMap.remoteId(MapEntity.group, group.id), isNull);
  });
}
