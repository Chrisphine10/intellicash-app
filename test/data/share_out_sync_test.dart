import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/core/network/api_exception.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/meeting.dart';
import 'package:intellicash_mobile/data/models/member.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/services/auto_sync_coordinator.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/share_out_sync_service.dart';
import 'package:intellicash_mobile/data/services/write_sync_service.dart';

/// Says what the server would say, and remembers what it was sent.
class _FakeShareOutApi extends RemoteWriteApi {
  _FakeShareOutApi(this.log)
      : super(ApiClient(
            credentials: () => const ApiCredentials(baseUrl: '', apiKey: '')));

  final List<String> log;
  final List<Map<String, Object?>> sent = [];

  /// What the next call does. Null means accept it.
  ApiException? failWith;

  @override
  Future<RecordedShareOut> recordShareOut({
    required String groupId,
    required String shareOutId,
    required int cycleNumber,
    required List<ShareOutLineInput> lines,
    bool force = false,
  }) async {
    log.add('share-out c$cycleNumber');
    sent.add({
      'groupId': groupId,
      'shareOutId': shareOutId,
      'cycleNumber': cycleNumber,
      'force': force,
      'lines': [for (final line in lines) line.toJson()],
    });
    final problem = failWith;
    if (problem != null) throw problem;
    return const RecordedShareOut(replayed: false, closedCycleId: 'cyc-closed-1');
  }
}

/// Records the order meetings are pushed in, and can leave one un-pushed the way
/// a failing signal would.
class _OrderedWriteSync extends WriteSyncService {
  _OrderedWriteSync(AppDatabase db, IdMapRepository idMap, this.log)
      : super(
          db: db,
          idMap: idMap,
          writeApi: RemoteWriteApi(ApiClient(
              credentials: () =>
                  const ApiCredentials(baseUrl: '', apiKey: ''))),
        );

  final List<String> log;
  final Set<int> failing = {};
  final IdMapRepository _map = IdMapRepository(AppDatabase.instance);

  @override
  Future<MeetingSyncResult> syncMeeting(Meeting meeting) async {
    if (failing.contains(meeting.number)) throw Exception('no signal');
    log.add('meeting ${meeting.number}');
    // What a real pass does last: it is only "backed up" once mapped.
    await _map.put(MapEntity.meeting, meeting.id, 'remote-m-${meeting.number}',
        groupId: 'remote-group-1');
    return const MeetingSyncResult(
        remoteMeetingId: 'r', syncedCount: 3, conflicts: [], skippedFines: 0);
  }
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late MeetingRepository meetings;
  late IdMapRepository idMap;
  late List<String> log;
  late _FakeShareOutApi api;
  late ShareOutSyncService service;
  late _OrderedWriteSync writeSync;
  late AutoSyncCoordinator coordinator;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_shareout_sync');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    meetings = MeetingRepository(db);
    idMap = IdMapRepository(db);
    log = [];
    api = _FakeShareOutApi(log);
    service = ShareOutSyncService(db: db, idMap: idMap, writeApi: api);
    writeSync = _OrderedWriteSync(db, idMap, log);
    coordinator = AutoSyncCoordinator(
      idMap: idMap,
      meetings: meetings,
      writeSync: writeSync,
      shareOutSync: service,
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
        interestRate: 10,
        interestType: InterestType.flat,
        loanMultiplier: 2,
        defaultLoanTermMonths: 3,
        meetingFrequency: MeetingFrequency.weekly,
        meetingDays: const [DateTime.sunday],
        memberNames: ['Achieng Odhiambo', 'Wanjiku Kamau'],
      );

  /// Links the group and its members to server ids, as a synced phone has.
  Future<List<Member>> link(Group group) async {
    await idMap.put(MapEntity.group, group.id, 'remote-group-1',
        groupId: 'remote-group-1');
    final roster = await members.membersForGroup(group.id);
    for (final member in roster) {
      await idMap.put(MapEntity.member, member.id, 'remote-${member.id}',
          groupId: 'remote-group-1');
    }
    return roster;
  }

  /// A finished share-out for [cycle], written the way `commit` writes it.
  Future<void> shareOutOf(Group group, List<Member> roster,
      {required int cycle, required DateTime at}) async {
    final database = await db.database;
    var i = 0;
    for (final member in roster) {
      await database.insert('share_out_payouts', {
        'id': 'p-$cycle-${i++}',
        'group_id': group.id,
        'cycle_number': cycle,
        'member_id': member.id,
        'member_name': member.name,
        'share_amount': 500.0,
        'gross_payout': 510.5,
        'welfare_payout': 10.0,
        'loan_offset': 20.25,
        'net_payout': 500.25,
        'created_at': at.toIso8601String(),
      });
    }
  }

  /// A closed meeting that ended at [at], as a phone that recorded it then would hold.
  Future<Meeting> closedMeeting(Group group, DateTime at) async {
    final meeting = await meetings.startMeeting(group);
    final closed = await meetings.closeMeeting(meeting);
    final database = await db.database;
    await database.update(
        'meetings',
        {
          'date': at.toIso8601String(),
          'closed_at': at.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [meeting.id]);
    return closed;
  }

  group('sending one share-out', () {
    test('sends what was paid, in cents, against the members\' server ids', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));

      final batch = (await service.unsent(group.id)).single;
      expect(batch.cycleNumber, 1);
      final result = await service.send(batch);

      expect(result.outcome, ShareOutSendOutcome.sent);
      final body = api.sent.single;
      expect(body['groupId'], 'remote-group-1');
      expect(body['cycleNumber'], 1);
      expect(body['force'], false);
      // The id the server recognises a retry by: stable for this group and cycle.
      expect(body['shareOutId'], '${group.id}-c1');
      final lines = body['lines'] as List;
      expect(lines, hasLength(2));
      final first = lines.first as Map<String, dynamic>;
      expect(first['memberId'], startsWith('remote-'));
      expect(first['shareCents'], 50000);
      expect(first['grossPayoutCents'], 51050);
      expect(first['welfarePayoutCents'], 1000);
      expect(first['loanOffsetCents'], 2025);
      expect(first['netPayoutCents'], 50025);
      // 51050 + 1000 - 2025 = 50025: what the server checks it adds up to.
      expect(51050 + 1000 - 2025, 50025);
    });

    test('once recorded it is done, and shows as sent', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));

      await service.send((await service.unsent(group.id)).single);

      expect(await service.unsent(group.id), isEmpty);
      expect((await service.statuses(group.id))[1]!.state, ShareOutSyncState.sent);
      expect(await coordinator.pendingShareOuts(), 0);
    });

    test('a cycle the server already closed is not sent, and stops holding things up', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      api.failWith = const ApiException(
        'The online record is already on Cycle 2.',
        statusCode: 409,
        code: 'SHARE_OUT_CYCLE_CLOSED',
      );

      final result = await service.send((await service.unsent(group.id)).single);

      expect(result.outcome, ShareOutSendOutcome.alreadyOnline);
      expect(result.done, isTrue);
      expect(await service.unsent(group.id), isEmpty);
      expect((await service.statuses(group.id))[1]!.state,
          ShareOutSyncState.alreadyOnline);
      expect(await idMap.totalConflicts(), 0);
    });

    test('a refusal is remembered with its reason, and can be overridden knowingly', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      api.failWith = const ApiException(
        'The online record does not hold the same share purchases as this phone.',
        statusCode: 409,
        code: 'SHARE_OUT_OUT_OF_STEP',
      );

      final refused = await service.send((await service.unsent(group.id)).single);
      expect(refused.outcome, ShareOutSendOutcome.blocked);

      final status = (await service.statuses(group.id))[1]!;
      expect(status.state, ShareOutSyncState.blocked);
      expect(status.message, contains('does not hold the same share purchases'));
      expect(status.canSendAnyway, isTrue);
      expect(await service.attention(group.id), contains('Cycle 1 share-out'));
      // Still to send: it must not be counted as backed up.
      expect(await coordinator.pendingShareOuts(), 1);

      // A person chooses to send anyway; only then is the flag set.
      api.failWith = null;
      final forced = await service.send(
          (await service.unsent(group.id)).single,
          force: true);
      expect(forced.outcome, ShareOutSendOutcome.sent);
      expect(api.sent.last['force'], true);
      expect(await service.attention(group.id), isNull);
      expect(await idMap.totalConflicts(), 0);
    });

    test('a refusal that is not the phone\'s to override offers no override', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      api.failWith = const ApiException(
        'Only a platform admin or the group\'s own account may close a cycle.',
        statusCode: 403,
      );

      await service.send((await service.unsent(group.id)).single);

      final status = (await service.statuses(group.id))[1]!;
      expect(status.state, ShareOutSyncState.blocked);
      expect(status.canSendAnyway, isFalse);
    });

    test('no signal, an ended session or a server error is just "later"', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));

      for (final failure in [
        const ApiException('offline', statusCode: 0),
        const ApiException('ended', statusCode: 401),
        const ApiException('busy', statusCode: 503),
        const ApiException('slow down', statusCode: 429),
      ]) {
        api.failWith = failure;
        final result = await service.send((await service.unsent(group.id)).single);
        expect(result.outcome, ShareOutSendOutcome.offline,
            reason: 'status ${failure.statusCode}');
      }

      // Nothing was recorded against it, so nobody is told it was refused.
      expect((await service.statuses(group.id))[1]!.state, ShareOutSyncState.waiting);
      expect(await service.attention(group.id), isNull);
      expect(await idMap.totalConflicts(), 0);
    });

    test('a member who is not linked yet stops it before anything is sent', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      final database = await db.database;
      await database.delete('id_map',
          where: 'entity_type = ? AND local_id = ?',
          whereArgs: [MapEntity.member, roster.first.id]);

      final result = await service.send((await service.unsent(group.id)).single);

      expect(result.outcome, ShareOutSendOutcome.blocked);
      expect(result.code, 'MEMBER_NOT_MAPPED');
      expect(api.sent, isEmpty);
    });

    test('a group that is not linked has nowhere to send it', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));

      final result = await service.send((await service.batches(group.id)).single);

      expect(result.outcome, ShareOutSendOutcome.notLinked);
      expect(api.sent, isEmpty);
      // And it is not counted as waiting: an unlinked group is not "behind".
      expect(await coordinator.pendingShareOuts(), 0);
    });
  });

  group('sending in the order things happened', () {
    test('a cycle\'s meetings go first, then its share-out, then the next cycle\'s meetings',
        () async {
      final group = await seedGroup();
      final roster = await link(group);
      await closedMeeting(group, DateTime(2026, 1, 10));
      await closedMeeting(group, DateTime(2026, 2, 10));
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      await closedMeeting(group, DateTime(2026, 4, 10));

      await coordinator.syncBoundGroups();

      expect(log, ['meeting 1', 'meeting 2', 'share-out c1', 'meeting 3']);
    });

    test('a meeting from before the share-out that has not gone up holds the share-out back',
        () async {
      final group = await seedGroup();
      final roster = await link(group);
      await closedMeeting(group, DateTime(2026, 1, 10));
      await closedMeeting(group, DateTime(2026, 2, 10));
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      await closedMeeting(group, DateTime(2026, 4, 10));
      writeSync.failing.add(2); // no signal for the second one

      await coordinator.syncBoundGroups();

      // The share-out would close a cycle the server does not hold in full, and
      // the third meeting would be filed under the wrong cycle.
      expect(log, ['meeting 1']);
      expect(api.sent, isEmpty);
      expect(await coordinator.pendingShareOuts(), 1);

      // The signal returns: everything goes, in order.
      log.clear();
      writeSync.failing.clear();
      await coordinator.syncBoundGroups();
      expect(log, ['meeting 2', 'share-out c1', 'meeting 3']);
      expect(await coordinator.pendingShareOuts(), 0);
    });

    test('a refused share-out holds back the meetings after it, and they wait rather than vanish',
        () async {
      final group = await seedGroup();
      final roster = await link(group);
      await closedMeeting(group, DateTime(2026, 1, 10));
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      await closedMeeting(group, DateTime(2026, 4, 10));
      api.failWith = const ApiException('does not match',
          statusCode: 409, code: 'SHARE_OUT_OUT_OF_STEP');

      await coordinator.syncBoundGroups();

      expect(log, ['meeting 1', 'share-out c1']);
      expect(await coordinator.pendingMeetings(), 1,
          reason: 'the later meeting is still waiting to back up');
      expect(await coordinator.shareOutAttention(), isNotNull);

      // Someone sends it anyway; what was held behind it follows on the next run.
      api.failWith = null;
      await service.send((await service.unsent(group.id)).single, force: true);
      log.clear();
      await coordinator.syncBoundGroups();
      expect(log, ['meeting 2']);
      expect(await coordinator.pendingMeetings(), 0);
      expect(await coordinator.shareOutAttention(), isNull);
    });

    test('says why a share-out is stuck behind a meeting the server only partly accepted', () async {
      final group = await seedGroup();
      final roster = await link(group);
      final first = await closedMeeting(group, DateTime(2026, 1, 10));
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      // The meeting reached the server but one record was refused.
      await idMap.put(MapEntity.meeting, first.id, 'remote-m-1', groupId: 'remote-group-1');
      await idMap.replaceConflicts(first.id, [
        SyncConflict(
          meetingId: first.id,
          kind: 'ledgerEntry',
          code: 'HTTP_400',
          message: 'refused',
          createdAt: DateTime.now(),
        ),
      ]);

      final note = await coordinator.shareOutAttention();

      expect(note, contains('Meeting #1'));
      expect(note, contains('Cycle 1 share-out is waiting'));
    });

    test('a cycle already shared out online lets the later meetings through', () async {
      final group = await seedGroup();
      final roster = await link(group);
      await closedMeeting(group, DateTime(2026, 1, 10));
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      await closedMeeting(group, DateTime(2026, 4, 10));
      api.failWith = const ApiException('closed',
          statusCode: 409, code: 'SHARE_OUT_CYCLE_CLOSED');

      await coordinator.syncBoundGroups();

      expect(log, ['meeting 1', 'share-out c1', 'meeting 2']);
      expect(await coordinator.pendingMeetings(), 0);
      expect(await coordinator.pendingShareOuts(), 0);
    });

    test('a share-out made before this existed is history: not sent, and holds nothing back',
        () async {
      final group = await seedGroup();
      final roster = await link(group);
      await closedMeeting(group, DateTime(2026, 1, 10));
      await shareOutOf(group, roster, cycle: 1, at: DateTime(2026, 3, 1));
      await idMap.put(MapEntity.shareOut, '${group.id}#1',
          ShareOutSyncService.beforeOnlineRecordingMarker,
          groupId: 'remote-group-1');
      await closedMeeting(group, DateTime(2026, 4, 10));

      await coordinator.syncBoundGroups();

      expect(log, ['meeting 1', 'meeting 2']);
      expect(api.sent, isEmpty);
      expect((await service.statuses(group.id))[1]!.state,
          ShareOutSyncState.beforeOnlineRecording);
      expect(await coordinator.pendingShareOuts(), 0);
    });

    test('with no share-outs it behaves exactly as it always did', () async {
      final group = await seedGroup();
      await link(group);
      await closedMeeting(group, DateTime(2026, 1, 10));
      await closedMeeting(group, DateTime(2026, 2, 10));

      final records = await coordinator.syncBoundGroups();

      expect(log, ['meeting 1', 'meeting 2']);
      expect(records, 6);
    });
  });
}
