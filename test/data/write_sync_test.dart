import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/core/network/api_exception.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/loan_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/services/auto_sync_coordinator.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/write_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Records what the write API was asked to send, without a network.
class FakeRemoteWriteApi extends RemoteWriteApi {
  FakeRemoteWriteApi()
      : super(ApiClient(
            credentials: () =>
                const ApiCredentials(baseUrl: '', apiKey: '')));

  int createMeetingCalls = 0;
  final List<Map<String, String>> attendance = [];
  final List<LedgerEntryInput> ledger = [];

  @override
  Future<String> createMeeting({
    required String groupId,
    required String title,
    required DateTime scheduledAt,
    bool adoptScheduled = false,
    String? source,
  }) async {
    createMeetingCalls++;
    return 'remote-meeting-1';
  }

  /// What the phone told the server a person did: STARTED, CLOSED.
  final List<String> lifecycle = [];

  /// Who the phone said opened the meeting, sent with CLOSED.
  List<String>? closedUnlockedBy;

  /// When set, CLOSED is refused with this (the server said no).
  ApiException? refuseClosed;

  @override
  Future<void> reportMeetingLifecycle({
    required String groupId,
    required String meetingId,
    required String event,
    required DateTime at,
    List<String>? unlockedByMemberIds,
  }) async {
    if (event == 'CLOSED' && refuseClosed != null) throw refuseClosed!;
    lifecycle.add(event);
    if (event == 'CLOSED') closedUnlockedBy = unlockedByMemberIds;
  }

  @override
  Future<void> putAttendance({
    required String groupId,
    required String meetingId,
    required String memberId,
    required String status,
  }) async {
    attendance.add({'memberId': memberId, 'status': status});
  }

  @override
  Future<void> postLedgerEntry({
    required String groupId,
    required String meetingId,
    required LedgerEntryInput entry,
  }) async {
    ledger.add(entry);
  }
}

/// Fails the way a dropped signal does - with something that is not an
/// [ApiException] - until told to stop.
class _FlakyWriteApi extends FakeRemoteWriteApi {
  bool failing = true;

  @override
  Future<void> postLedgerEntry({
    required String groupId,
    required String meetingId,
    required LedgerEntryInput entry,
  }) async {
    if (failing) throw const SocketException('connection lost');
    await super.postLedgerEntry(
        groupId: groupId, meetingId: meetingId, entry: entry);
  }
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late MeetingRepository meetings;
  late LoanRepository loans;
  late IdMapRepository idMap;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_writesync');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    meetings = MeetingRepository(db);
    loans = LoanRepository(db);
    idMap = IdMapRepository(db);
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
        memberNames: ['Achieng Odhiambo', 'Wanjiku Kamau', 'Baraka Mwangi'],
      );

  group('payment method on share purchases', () {
    test('persists and appears in the ledger summary', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      final achieng = roster.firstWhere((m) => m.name == 'Achieng Odhiambo');
      final meeting = await meetings.startMeeting(group);

      await meetings.recordSharePurchase(
        meeting: meeting,
        group: group,
        memberId: achieng.id,
        shares: 3,
        paymentMethod: PaymentMethod.mpesa,
        paymentReference: 'SLK4H2X9Y1',
      );

      final ledger = await meetings.ledger(meeting.id);
      expect(ledger, hasLength(1));
      expect(ledger.first.paymentSummary, 'M-Pesa');

      final db2 = await db.database;
      final row = (await db2.query('share_purchases')).first;
      expect(row['payment_method'], 'mpesa');
      expect(row['payment_reference'], 'SLK4H2X9Y1');
    });

    test('cash purchase stores no reference', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      final meeting = await meetings.startMeeting(group);
      await meetings.recordSharePurchase(
        meeting: meeting,
        group: group,
        memberId: roster.first.id,
        shares: 1,
      );
      final row = (await (await db.database).query('share_purchases')).first;
      expect(row['payment_method'], 'cash');
      expect(row['payment_reference'], isNull);
    });
  });

  group('WriteSyncService translation', () {
    test('maps local records to backend ledger vocabulary', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      final achieng = roster.firstWhere((m) => m.name == 'Achieng Odhiambo');
      final wanjiku = roster.firstWhere((m) => m.name == 'Wanjiku Kamau');
      final baraka = roster.firstWhere((m) => m.name == 'Baraka Mwangi');

      final meeting = await meetings.startMeeting(group);
      await meetings.setAttendance(
          meeting: meeting, memberId: achieng.id, present: true);
      await meetings.recordSharePurchase(
        meeting: meeting,
        group: group,
        memberId: achieng.id,
        shares: 10, // 1000 -> 100000 cents, and makes Achieng loan-eligible
        paymentMethod: PaymentMethod.mpesa,
        paymentReference: 'MPESA123',
      );
      await meetings.collectSocialFundFromPresent(
          meeting: meeting, group: group); // 50 for Achieng -> 5000 cents
      final loan = await loans.disburse(
        group: group,
        memberId: achieng.id,
        principal: 500, // -> 50000 cents
        dueDate: DateTime.now().add(const Duration(days: 90)),
        meetingId: meeting.id,
      );
      await loans.repay(loan: loan, amount: 200, meetingId: meeting.id); // 20000
      await meetings.recordFine(
        meeting: meeting,
        memberId: achieng.id,
        amount: 150, // -> 15000 cents
        reason: 'Late arrival',
      );

      // Bind group + two of three members; leave Baraka unmapped.
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');
      await idMap.put(MapEntity.member, achieng.id, 'r-achieng',
          groupId: 'remote-group-1');
      await idMap.put(MapEntity.member, wanjiku.id, 'r-wanjiku',
          groupId: 'remote-group-1');

      final fake = FakeRemoteWriteApi();
      final service =
          WriteSyncService(db: db, idMap: idMap, writeApi: fake);

      final result = await service.syncMeeting(meeting);

      // Created and mapped the remote meeting once.
      expect(fake.createMeetingCalls, 1);
      expect(await idMap.remoteId(MapEntity.meeting, meeting.id),
          'remote-meeting-1');

      // Ledger entries carry the right types, cents and idempotency keys.
      final byType = {for (final e in fake.ledger) e.type: e};
      expect(byType['SHARE_PURCHASE']!.amountCents, 100000);
      expect(byType['SHARE_PURCHASE']!.memberId, 'r-achieng');
      expect(byType['SHARE_PURCHASE']!.externalReference, 'MPESA123');
      expect(byType['SHARE_PURCHASE']!.clientRequestId, startsWith('shr-'));
      expect(byType['SOCIAL_CONTRIBUTION']!.amountCents, 5000);
      expect(byType['INTERNAL_LOAN_DISBURSEMENT']!.amountCents, 50000);
      expect(byType['LOAN_REPAYMENT']!.amountCents, 20000);
      // Gap 3: fines now translate to FINE_COLLECTION and are no longer skipped.
      expect(byType['FINE_COLLECTION']!.amountCents, 15000);
      expect(byType['FINE_COLLECTION']!.memberId, 'r-achieng');
      expect(byType['FINE_COLLECTION']!.clientRequestId, startsWith('fin-'));
      expect(result.skippedFines, 0);

      // Baraka is unmapped: his auto-created attendance row is a conflict,
      // and no ledger entry references him.
      expect(result.conflicts.any((c) => c.code == 'MEMBER_NOT_MAPPED'), isTrue);
      expect(fake.ledger.any((e) => e.memberId == baraka.id), isFalse);

      // Present + mapped attendance was pushed.
      expect(
        fake.attendance.any(
            (a) => a['memberId'] == 'r-achieng' && a['status'] == 'PRESENT'),
        isTrue,
      );
    });

    test('re-sync does not re-create the meeting (idempotent mapping)', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      final meeting = await meetings.startMeeting(group);
      await meetings.recordSharePurchase(
          meeting: meeting, group: group, memberId: roster.first.id, shares: 1);

      await idMap.put(MapEntity.group, group.id, 'remote-group-1');
      await idMap.put(MapEntity.member, roster.first.id, 'r-1');

      final fake = FakeRemoteWriteApi();
      final service = WriteSyncService(db: db, idMap: idMap, writeApi: fake);

      await service.syncMeeting(meeting);
      await service.syncMeeting(meeting);
      expect(fake.createMeetingCalls, 1); // second run reuses the mapping
    });

    test('refuses to sync when the group is not bound', () async {
      final group = await seedGroup();
      final meeting = await meetings.startMeeting(group);
      final service = WriteSyncService(
          db: db, idMap: idMap, writeApi: FakeRemoteWriteApi());
      expect(() => service.syncMeeting(meeting), throwsA(anything));
    });
  });

  group('closing a meeting on the server', () {
    Future<(Group, List<String>)> boundGroup() async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');
      for (final member in roster) {
        await idMap.put(MapEntity.member, member.id, 'r-${member.id}',
            groupId: 'remote-group-1');
      }
      return (group, [for (final m in roster) m.id]);
    }

    test('tells the server whose PINs opened the meeting', () async {
      final (group, ids) = await boundGroup();
      final meeting = await meetings.startMeeting(group, unlockedBy: ids.take(2).toList());
      await meetings.closeMeeting(meeting);

      final fake = FakeRemoteWriteApi();
      final service = WriteSyncService(db: db, idMap: idMap, writeApi: fake);
      await service.syncMeeting((await meetings.meetingsForGroup(group.id)).first.meeting);

      expect(fake.lifecycle.last, 'CLOSED');
      expect(fake.closedUnlockedBy, ['r-${ids[0]}', 'r-${ids[1]}']);
    });

    test('a close the server refuses keeps the meeting waiting', () async {
      final (group, _) = await boundGroup();
      final meeting = await meetings.startMeeting(group);
      await meetings.closeMeeting(meeting);

      final fake = FakeRemoteWriteApi()
        ..refuseClosed = const ApiException('No.', statusCode: 409, code: 'MEETING_CANCELLED');
      final service = WriteSyncService(db: db, idMap: idMap, writeApi: fake);
      final coordinator =
          AutoSyncCoordinator(idMap: idMap, meetings: meetings, writeSync: service);

      await coordinator.syncBoundGroups();
      expect(await coordinator.pendingMeetings(), 1,
          reason: 'the console still shows it open, so it is not backed up');

      // Accepted next time: now it is done.
      fake.refuseClosed = null;
      await coordinator.syncBoundGroups();
      expect(await coordinator.pendingMeetings(), 0);
    });
  });

  group('a server twin made while the meeting is still open', () {
    // Found on a phone: opening Welfare during a meeting gave it a server twin,
    // that twin was recorded as "this meeting has been pushed", and when the
    // meeting closed the sync (and its badge) decided there was nothing to send.
    // The shares, loan and repayment it held never reached the server.
    test('does not make a closed meeting look backed up', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      final meeting = await meetings.startMeeting(group);
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');
      for (final member in roster) {
        // Everyone linked, so no attendance row is left as a conflict.
        await idMap.put(MapEntity.member, member.id, 'r-${member.id}',
            groupId: 'remote-group-1');
      }

      final fake = FakeRemoteWriteApi();
      final service = WriteSyncService(db: db, idMap: idMap, writeApi: fake);
      final coordinator =
          AutoSyncCoordinator(idMap: idMap, meetings: meetings, writeSync: service);

      await service.ensureRemoteMeeting(meeting); // what the Welfare screen does
      expect(fake.createMeetingCalls, 1);
      await meetings.recordSharePurchase(
          meeting: meeting, group: group, memberId: roster.first.id, shares: 2);
      await meetings.closeMeeting(meeting);

      // Closed, and nothing has been sent to its twin: it is waiting.
      expect(await coordinator.pendingMeetings(), 1);

      await coordinator.syncBoundGroups();

      expect(fake.ledger.where((e) => e.type == 'SHARE_PURCHASE'), hasLength(1));
      expect(fake.createMeetingCalls, 1,
          reason: 'the twin is reused, not created a second time');
      expect(await coordinator.pendingMeetings(), 0);

      // The server heard what people did, in order: started, then closed.
      expect(fake.lifecycle.first, 'STARTED');
      expect(fake.lifecycle.last, 'CLOSED');
    });

    test('a meeting in progress is reported started, and its records wait for the close', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      final meeting = await meetings.startMeeting(group);
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');
      for (final member in roster) {
        await idMap.put(MapEntity.member, member.id, 'r-${member.id}',
            groupId: 'remote-group-1');
      }
      await meetings.recordSharePurchase(
          meeting: meeting, group: group, memberId: roster.first.id, shares: 1);

      final fake = FakeRemoteWriteApi();
      final service = WriteSyncService(db: db, idMap: idMap, writeApi: fake);
      final coordinator =
          AutoSyncCoordinator(idMap: idMap, meetings: meetings, writeSync: service);

      await coordinator.syncBoundGroups();

      expect(fake.lifecycle, ['STARTED']);
      expect(fake.ledger, isEmpty, reason: 'an open meeting is still being recorded');
    });

    test('a push that stops part-way is tried again, not counted as done', () async {
      final group = await seedGroup();
      final roster = await members.membersForGroup(group.id);
      final meeting = await meetings.startMeeting(group);
      await meetings.recordSharePurchase(
          meeting: meeting, group: group, memberId: roster.first.id, shares: 1);
      await meetings.closeMeeting(meeting);
      await idMap.put(MapEntity.group, group.id, 'remote-group-1',
          groupId: 'remote-group-1');
      for (final member in roster) {
        await idMap.put(MapEntity.member, member.id, 'r-${member.id}',
            groupId: 'remote-group-1');
      }

      final fake = _FlakyWriteApi();
      final service = WriteSyncService(db: db, idMap: idMap, writeApi: fake);
      final coordinator =
          AutoSyncCoordinator(idMap: idMap, meetings: meetings, writeSync: service);

      // The signal goes after the meeting was created on the server but before
      // its money was sent. It used to be mapped by then, so it looked finished.
      await coordinator.syncBoundGroups();
      expect(fake.ledger, isEmpty);
      expect(await coordinator.pendingMeetings(), 1);

      fake.failing = false;
      await coordinator.syncBoundGroups();
      expect(fake.ledger, hasLength(1));
      expect(fake.createMeetingCalls, 1);
      expect(await coordinator.pendingMeetings(), 0);
    });
  });

  group('IdMapRepository', () {
    test('stores and resolves mappings and conflicts', () async {
      await seedGroup();
      await idMap.put(MapEntity.member, 'local-1', 'remote-1');
      expect(await idMap.remoteId(MapEntity.member, 'local-1'), 'remote-1');
      expect((await idMap.mappings(MapEntity.member))['local-1'], 'remote-1');

      await idMap.replaceConflicts('m1', [
        SyncConflict(
          meetingId: 'm1',
          kind: 'ledgerEntry',
          code: 'INSUFFICIENT_FUND_BALANCE',
          message: 'nope',
          createdAt: DateTime(2026, 1, 1),
        ),
      ]);
      expect(await idMap.totalConflicts(), 1);
      expect((await idMap.conflictsForMeeting('m1')).single.code,
          'INSUFFICIENT_FUND_BALANCE');
    });
  });
}
