import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/loan_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
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
  }) async {
    createMeetingCalls++;
    return 'remote-meeting-1';
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
