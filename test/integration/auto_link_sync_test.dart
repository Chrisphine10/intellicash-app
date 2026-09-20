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
import 'package:intellicash_mobile/data/services/auto_sync_coordinator.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
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

  test('a role changed on the phone reaches the server once, and only that one', () async {
    final group = await seedGroup('Tsunami SHG');
    final roster = await members.membersForGroup(group.id);
    await idMap.put(MapEntity.group, group.id, 'remote-group-9', groupId: 'remote-group-9');
    for (final m in roster) {
      await idMap.put(MapEntity.member, m.id, 'srv-${m.id}', groupId: 'remote-group-9');
    }

    var watermark = 0;
    final pushedRoles = <String>[];
    final sync = AutoSyncCoordinator(
      idMap: idMap,
      meetings: meetings,
      writeSync: WriteSyncService(db: db, idMap: idMap, writeApi: backend),
      linkSupport: GroupLinkSupport(
        currentGroup: groups.currentGroup,
        membersForGroup: (id) => members.membersForGroup(id),
        ownRemoteGroupId: () async => 'remote-group-9',
        remoteGroup: (_) async => remote('Tsunami SHG'),
        pushMember: (_, m) async => 'srv-${m.id}',
        editedMembersSince: members.editedSince,
        roleWatermark: () async => watermark,
        saveRoleWatermark: (value) async => watermark = value,
        pushRole: (remoteGroupId, remoteMemberId, role) async =>
            pushedRoles.add('$remoteMemberId=${role.serverName}'),
      ),
    );

    // Everything already on the phone at install time is not a "change".
    await sync.syncBoundGroups();
    pushedRoles.clear();

    final ian = roster.firstWhere((m) => m.name == 'Ian Kamau');
    await members.updateMember(ian.copyWith(role: MemberRole.keyHolder));
    await sync.syncBoundGroups();
    expect(pushedRoles, ['srv-${ian.id}=KEY_HOLDER']);

    // Nothing new changed: nothing is sent again.
    pushedRoles.clear();
    await sync.syncBoundGroups();
    expect(pushedRoles, isEmpty);
  });

  /// A coordinator with the pull/policy hooks, over a server roster and policy
  /// the test controls.
  AutoSyncCoordinator twoWay({
    required List<RemoteMember> serverRoster,
    required List<String> added,
    bool policyConfigured = false,
    List<String>? policySent,
  }) =>
      AutoSyncCoordinator(
        idMap: idMap,
        meetings: meetings,
        writeSync: WriteSyncService(db: db, idMap: idMap, writeApi: backend),
        linkSupport: GroupLinkSupport(
          currentGroup: groups.currentGroup,
          membersForGroup: (id) => members.membersForGroup(id),
          ownRemoteGroupId: () async => 'remote-group-9',
          remoteGroup: (_) async => remote('Tsunami SHG'),
          pushMember: (remoteGroupId, Member member) async => 'srv-${member.id}',
          remoteMembers: (_) async => serverRoster,
          addLocalMember: (localGroupId, person) async {
            added.add(person.fullName);
            return members.addMember(
              groupId: localGroupId,
              name: person.fullName,
              phone: person.phone,
            );
          },
          policyIsConfigured: (_) async => policyConfigured,
          pushPolicy: (remoteGroupId, {required rateBps, required termMonths}) async =>
              policySent?.add('$rateBps/$termMonths'),
        ),
      );

  RemoteMember serverMember(String id, String name, {String? phone, String status = 'ACTIVE'}) =>
      RemoteMember(id: id, fullName: name, phone: phone, role: 'MEMBER', kycStatus: 'PENDING', status: status);

  test('a member the server admitted arrives on the phone, once', () async {
    final group = await seedGroup('Tsunami SHG');
    final added = <String>[];
    final roster = [
      serverMember('srv-new', 'Newcomer Njeri', phone: '254733020287'),
      serverMember('srv-gone', 'Left The Group', status: 'INACTIVE'),
    ];
    final sync = twoWay(serverRoster: roster, added: added);

    await sync.syncBoundGroups();
    final names = (await members.membersForGroup(group.id)).map((m) => m.name).toList();
    expect(names, contains('Newcomer Njeri'));
    expect(names, isNot(contains('Left The Group'))); // inactive: not brought down
    expect(added, ['Newcomer Njeri']);

    // A second run does not add them again — they are mapped now.
    await sync.syncBoundGroups();
    expect(added, ['Newcomer Njeri']);
    expect((await members.membersForGroup(group.id)).where((m) => m.name == 'Newcomer Njeri'), hasLength(1));
  });

  test('a server member who is already on the phone is linked, not duplicated', () async {
    final group = await seedGroup('Tsunami SHG');
    // Same person, number written differently on the phone and the server.
    final local = await members.addMember(groupId: group.id, name: 'Achieng O', phone: '0722100011');
    final added = <String>[];
    final sync = twoWay(
      serverRoster: [serverMember('srv-achieng', 'Achieng Otieno', phone: '254722100011')],
      added: added,
    );

    // Make the push not claim them first, so the pull has to recognise them.
    await idMap.put(MapEntity.group, group.id, 'remote-group-9', groupId: 'remote-group-9');
    for (final m in await members.membersForGroup(group.id)) {
      if (m.id != local.id) await idMap.put(MapEntity.member, m.id, 'srv-${m.id}', groupId: 'remote-group-9');
    }
    await sync.pullNewMembers(group.id, 'remote-group-9');

    expect(added, isEmpty);
    expect(await idMap.remoteId(MapEntity.member, local.id), 'srv-achieng');
  });

  test('two people with the same name but different numbers are never fused', () async {
    final group = await seedGroup('Tsunami SHG');
    await members.addMember(groupId: group.id, name: 'Mary Wanjiku', phone: '0711000001');
    final added = <String>[];
    final sync = twoWay(
      serverRoster: [serverMember('srv-mary2', 'Mary Wanjiku', phone: '254722000002')],
      added: added,
    );
    await idMap.put(MapEntity.group, group.id, 'remote-group-9', groupId: 'remote-group-9');
    await sync.pullNewMembers(group.id, 'remote-group-9');
    expect(added, ['Mary Wanjiku']);
    expect((await members.membersForGroup(group.id)).where((m) => m.name == 'Mary Wanjiku'), hasLength(2));
  });

  test('the phone gives the server its loan rules only when the server has none', () async {
    final group = await seedGroup('Tsunami SHG');
    // seedGroup uses reducing balance, which the server cannot express: nothing sent.
    var sent = <String>[];
    var sync = twoWay(serverRoster: const [], added: <String>[], policySent: sent);
    expect(await sync.pushPolicyIfUnset(group.id, 'remote-group-9'), isFalse);
    expect(sent, isEmpty);

    // A flat-rate group with an unconfigured server: 10% a month, 3 months.
    await groups.updateGroup(group.copyWith(interestType: InterestType.flat, interestRate: 10, defaultLoanTermMonths: 3));
    sync = twoWay(serverRoster: const [], added: <String>[], policySent: sent);
    expect(await sync.pushPolicyIfUnset(group.id, 'remote-group-9'), isTrue);
    expect(sent, ['1000/3']);

    // A server that already has rules of its own is never overwritten.
    sent = <String>[];
    sync = twoWay(serverRoster: const [], added: <String>[], policyConfigured: true, policySent: sent);
    expect(await sync.pushPolicyIfUnset(group.id, 'remote-group-9'), isFalse);
    expect(sent, isEmpty);
  });
}
