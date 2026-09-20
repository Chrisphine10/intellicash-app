import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/models/remote/restore_bundle.dart';
import 'package:intellicash_mobile/data/repositories/dashboard_repository.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/loan_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/share_out_repository.dart';
import 'package:intellicash_mobile/data/services/group_history_importer.dart';
import 'package:intellicash_mobile/data/services/group_restore_service.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/share_out_sync_service.dart';

/// A treasurer changes phone. The group, its members and its settings come back
/// - and, until this, nothing else: no savings, no loans, no meetings, so the
/// phone reported a group with no money and would have worked a share-out out
/// from that. These tests restore a small but complete history and check the
/// phone reads it the way the old one did.
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late IdMapRepository idMap;
  late GroupHistoryImporter importer;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_history');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    idMap = IdMapRepository(db);
    importer = GroupHistoryImporter(db: db);
  });

  tearDown(() async {
    await db.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  // The server's clock, in UTC, as it sends it.
  final t0 = DateTime.utc(2026, 8, 1, 6); // the open cycle began
  DateTime days(int n, [int hour = 8]) => DateTime.utc(2026, 8, 1, hour).add(Duration(days: n));

  /// A fresh phone: the group made by "Load my group", two members mapped.
  Future<({Group group, Map<String, String> memberFor})> freshPhone() async {
    final group = await groups.createGroup(
      name: 'Umoja Women Group',
      cycleNumber: 2,
      savingsMode: SavingsMode.fixed,
      shareValue: 500,
      maxSharesPerMeeting: 10,
      socialFundAmount: 0,
      interestRate: 10,
      interestType: InterestType.flat,
      loanMultiplier: 3,
      defaultLoanTermMonths: 1,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [1],
      memberNames: const [],
    );
    final alice = await members.addMember(groupId: group.id, name: 'Alice Achieng', phone: '254700000001');
    final brian = await members.addMember(groupId: group.id, name: 'Brian Bett', phone: '254700000002');
    await idMap.put(MapEntity.group, group.id, 'remote-g', groupId: 'remote-g');
    return (group: group, memberFor: {'r-alice': alice.id, 'r-brian': brian.id});
  }

  RestoreEntry entry(
    String id,
    String type,
    int cents, {
    String? meeting,
    String? member,
    String? loan,
    int? cycle,
    required DateTime at,
    String? description,
    String direction = 'CREDIT',
    String? reference,
  }) =>
      RestoreEntry(
        id: id,
        meetingId: meeting,
        memberId: member,
        loanId: loan,
        cycleNumber: cycle,
        type: type,
        direction: direction,
        amountCents: cents,
        description: description ?? type,
        externalReference: reference,
        createdAt: at,
      );

  /// Cycle 1: Alice 5,000 and Brian 3,000 in shares, 50 social, Brian borrows
  /// 2,000 and repays 500; then the group shares out. Cycle 2 (open): one meeting
  /// where Alice buys 1,000 of shares.
  RestoreBundle bundle() => RestoreBundle(
        cycleNumber: 2,
        cycleStartedAt: t0,
        policyConfigured: true,
        loanInterestRateBps: 500,
        defaultLoanTermMonths: 2,
        meetings: [
          RestoreMeeting(id: 'r-m1', title: 'Meeting #1', scheduledAt: days(-60), status: 'SEALED', closedAt: days(-60), cycleNumber: 1),
          RestoreMeeting(id: 'r-m2', title: 'Meeting #2', scheduledAt: days(10), status: 'SEALED', closedAt: days(10), cycleNumber: 2),
          // Only ever planned: nothing recorded in it, so not history.
          RestoreMeeting(id: 'r-planned', title: 'Planned', scheduledAt: days(40), status: 'SCHEDULED', closedAt: null, cycleNumber: 2),
        ],
        attendance: const [
          RestoreAttendance(meetingId: 'r-m1', memberId: 'r-alice', status: 'PRESENT'),
          RestoreAttendance(meetingId: 'r-m1', memberId: 'r-brian', status: 'ABSENT'),
          RestoreAttendance(meetingId: 'r-m2', memberId: 'r-alice', status: 'PRESENT'),
        ],
        loans: [
          RestoreLoan(
            id: 'r-loan',
            memberId: 'r-brian',
            cycleNumber: 1,
            principalCents: 200000,
            interestRateBps: 500,
            termMonths: 2,
            disbursedAt: days(-59),
            dueAt: days(1),
            status: 'REPAID',
            disbursementEntryId: 'e-loan',
          ),
        ],
        entries: [
          entry('e1', 'SHARE_PURCHASE', 500000, meeting: 'r-m1', member: 'r-alice', cycle: 1, at: days(-60, 9), description: '10 share(s) · M-Pesa', reference: 'SLK123'),
          entry('e2', 'SHARE_PURCHASE', 300000, meeting: 'r-m1', member: 'r-brian', cycle: 1, at: days(-60, 10)),
          entry('e3', 'SOCIAL_CONTRIBUTION', 5000, meeting: 'r-m1', member: 'r-alice', cycle: 1, at: days(-60, 11)),
          entry('e-loan', 'INTERNAL_LOAN_DISBURSEMENT', 200000, meeting: 'r-m1', member: 'r-brian', cycle: 1, at: days(-59), direction: 'DEBIT'),
          entry('e4', 'LOAN_REPAYMENT', 50000, meeting: 'r-m1', member: 'r-brian', loan: 'r-loan', cycle: 1, at: days(-30)),
          // Cycle 1's share-out, recorded against the last meeting.
          entry('e5', 'LOAN_REPAYMENT', 170000, meeting: 'r-m1', member: 'r-brian', loan: 'r-loan', cycle: 1, at: days(-1), description: 'Loan settled from share-out'),
          entry('e6', 'SHARE_OUT_PAYOUT', 512500, meeting: 'r-m1', member: 'r-alice', cycle: 1, at: days(-1, 10), direction: 'DEBIT'),
          entry('e7', 'SHARE_OUT_PAYOUT', 307500, meeting: 'r-m1', member: 'r-brian', cycle: 1, at: days(-1, 10), direction: 'DEBIT'),
          entry('e8', 'WELFARE_SHARE_OUT', 2500, meeting: 'r-m1', member: 'r-alice', cycle: 1, at: days(-1, 10), direction: 'DEBIT'),
          entry('e9', 'WELFARE_SHARE_OUT', 2500, meeting: 'r-m1', member: 'r-brian', cycle: 1, at: days(-1, 10), direction: 'DEBIT'),
          // Cycle 2.
          entry('e10', 'SHARE_PURCHASE', 100000, meeting: 'r-m2', member: 'r-alice', cycle: 2, at: days(10, 9)),
          // Online records the phone cannot place: no meeting, and a member it does not have.
          entry('e11', 'SHARE_PURCHASE', 7000, member: 'r-alice', cycle: 2, at: days(11)),
          entry('e12', 'SOCIAL_CONTRIBUTION', 1000, meeting: 'r-m2', member: 'r-nobody', cycle: 2, at: days(12)),
        ],
      );

  test('the meetings come back in order, as already backed up, with the cash box each opened with', () async {
    final phone = await freshPhone();
    final result = await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: bundle(),
      localMemberFor: phone.memberFor,
    );

    expect(result.imported, isTrue);
    expect(result.meetings, 2, reason: 'the planned one had nothing recorded in it');

    final database = await db.database;
    final rows = await database.query('meetings', orderBy: 'number');
    expect(rows.map((r) => r['number']), [1, 2]);
    expect(rows.every((r) => r['status'] == 'closed'), isTrue);
    // Meeting 1 opened empty; meeting 2 opened with what meeting 1 left. The
    // share-out paid everything back out, so the box was empty again.
    expect(rows[0]['opening_balance'], 0.0);
    // in: 5000+3000+50+500+1700 ; out: 2000 loan + 5125 + 3075 + 25 + 25
    expect(rows[1]['opening_balance'],
        5000 + 3000 + 50 + 500 + 1700 - 2000 - 5125 - 3075 - 25 - 25);

    // Each is remembered as the online meeting it came from, so none is sent back.
    final mapped = await idMap.mappings(MapEntity.meeting);
    expect(mapped.values.toSet(), {'r-m1', 'r-m2'});
    expect(mapped.keys.toSet(), rows.map((r) => r['id']).toSet());

    final attendance = await database.query('attendance');
    expect(attendance, hasLength(3));
    expect(attendance.where((r) => r['present'] == 0), hasLength(1));
  });

  test('savings, social fund, loans and repayments are placed as the phone keeps them', () async {
    final phone = await freshPhone();
    final result = await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: bundle(),
      localMemberFor: phone.memberFor,
    );
    final database = await db.database;

    final purchases = await database.query('share_purchases', orderBy: 'amount DESC');
    expect(purchases.map((r) => r['amount']), [5000.0, 3000.0, 1000.0]);
    // 5,000 at 500 a share is 10 shares; what was paid is exact.
    expect(purchases.first['shares'], 10);
    expect(purchases.first['unit_value'], 500.0);
    expect(purchases.first['payment_method'], PaymentMethod.mpesa.name);
    expect(purchases.first['payment_reference'], 'SLK123');
    expect(purchases.last['payment_method'], PaymentMethod.cash.name);

    expect((await database.query('social_fund_entries')).single['amount'], 50.0);

    final loan = (await database.query('loans')).single;
    expect(loan['principal'], 2000.0);
    expect(loan['interest_rate'], 5.0);
    expect(loan['interest_type'], InterestType.flat.name);
    // 2,000 for 2 months at 5% a month, flat: 2,000 + 200
    expect(loan['total_due'], 2200.0);
    expect(loan['status'], LoanStatus.repaid.name);

    final repayments = await database.query('loan_repayments', orderBy: 'amount');
    expect(repayments.map((r) => r['amount']), [500.0, 1700.0]);
    expect(repayments.every((r) => r['loan_id'] == loan['id']), isTrue);

    expect(result.records, 6, reason: '3 purchases + social + 2 repayments');
    expect(result.loans, 1);
    // No meeting, and a member the phone does not have.
    expect(result.skipped, 2);
  });

  test('the open cycle starts where it started online, so this cycle\'s balances read as before', () async {
    final phone = await freshPhone();
    await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: bundle(),
      localMemberFor: phone.memberFor,
    );

    final group = (await groups.currentGroup())!;
    expect(group.cycleNumber, 2);
    expect(group.cycleStartDate.toUtc(), t0);
    expect(group.interestRate, 5.0);
    expect(group.interestType, InterestType.flat);
    expect(group.defaultLoanTermMonths, 2);

    // Only cycle 2's 1,000 counts as savings now; cycle 1 was shared out.
    final summary = await DashboardRepository(db).summary(group.id);
    expect(summary.totalSavings, 1000.0);
    // And nothing from cycle 1 is left owing: the loan is settled.
    final financials = await MemberRepository(db).financialsForGroup(group.id);
    final byName = {for (final f in financials) f.member.name: f};
    expect(byName['Alice Achieng']!.totalSavings, 1000.0);
    expect(byName['Brian Bett']!.totalSavings, 0.0);
    expect(byName['Brian Bett']!.activeLoanBalance, 0.0,
        reason: 'the loan was repaid and shared out in cycle 1');
  });

  test('a cycle shared out on the console but not closed there starts its balances after the payout', () async {
    final phone = await freshPhone();
    final base = bundle();
    // The console's share-out pays out and leaves the cycle open. Cycle 2 here is
    // the open one, so put a payout INTO it, after its first purchase.
    final entries = [
      ...base.entries,
      entry('e20', 'SHARE_OUT_PAYOUT', 100000, meeting: 'r-m2', member: 'r-alice', cycle: 2, at: days(20), direction: 'DEBIT'),
    ];
    await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: RestoreBundle(
        cycleNumber: base.cycleNumber,
        cycleStartedAt: base.cycleStartedAt,
        policyConfigured: base.policyConfigured,
        loanInterestRateBps: base.loanInterestRateBps,
        defaultLoanTermMonths: base.defaultLoanTermMonths,
        meetings: base.meetings,
        attendance: base.attendance,
        entries: entries,
        loans: base.loans,
      ),
      localMemberFor: phone.memberFor,
    );

    final group = (await groups.currentGroup())!;
    expect(group.cycleStartDate.toUtc(), days(20));
    // Alice's 1,000 in cycle 2 came BEFORE that payout, so it is not savings now.
    expect((await DashboardRepository(db).summary(group.id)).totalSavings, 0.0);

    // The open cycle is not recorded as a share-out this phone made: when the
    // group shares it out from the phone, that share-out must still be sent.
    final history = await ShareOutRepository(db).history(phone.group.id);
    expect(history.map((r) => r.cycleNumber), [1], reason: 'only the closed cycle');
    expect((await idMap.mappings(MapEntity.shareOut)).keys, ['${phone.group.id}#1']);
  });

  test('a past share-out is rebuilt from what was paid, and is never sent back', () async {
    final phone = await freshPhone();
    final result = await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: bundle(),
      localMemberFor: phone.memberFor,
    );
    expect(result.shareOuts, 1);

    final history = await ShareOutRepository(db).history(phone.group.id);
    final record = history.single;
    expect(record.cycleNumber, 1);
    final brian = record.payouts.firstWhere((p) => p.memberName == 'Brian Bett');
    expect(brian.shareAmount, 3000.0);
    expect(brian.grossPayout, 3075.0);
    expect(brian.welfarePayout, 25.0);
    expect(brian.loanOffset, 1700.0);
    expect(brian.netPayout, 3075.0 + 25.0 - 1700.0);
    final alice = record.payouts.firstWhere((p) => p.memberName == 'Alice Achieng');
    expect(alice.netPayout, 5125.0 + 25.0);

    // It came from online: nothing to send, and it reads as recorded.
    final service = ShareOutSyncService(
      db: db,
      idMap: idMap,
      writeApi: RemoteWriteApi(ApiClient(credentials: () => const ApiCredentials(baseUrl: '', apiKey: ''))),
    );
    expect(await service.unsent(phone.group.id), isEmpty);
    expect((await service.statuses(phone.group.id))[1]!.state, ShareOutSyncState.sent);
  });

  test('the loan fund and cash box the restored phone reports are the group\'s, not zero', () async {
    final phone = await freshPhone();
    await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: bundle(),
      localMemberFor: phone.memberFor,
    );
    final group = (await groups.currentGroup())!;

    // Cycle 1 was shared out to the cent, so what is left is cycle 2's 1,000.
    expect(await LoanRepository(db).loanFundBalance(group.id), 1000.0);
    expect(await MeetingRepository(db).cashBoxBalance(group.id), 1000.0);
  });

  test('it will not go underneath meetings the phone has recorded itself', () async {
    final phone = await freshPhone();
    await MeetingRepository(db).startMeeting(phone.group);

    final result = await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: bundle(),
      localMemberFor: phone.memberFor,
    );

    expect(result.imported, isFalse);
    expect(result.notImportedBecause, contains('already recorded meetings'));
    final database = await db.database;
    expect(await database.query('share_purchases'), isEmpty);
    expect((await database.query('meetings')).length, 1);
  });

  test('an empty group is a valid restore: nothing to bring, nothing wrong', () async {
    final phone = await freshPhone();
    final result = await importer.import(
      localGroupId: phone.group.id,
      remoteGroupId: 'remote-g',
      bundle: const RestoreBundle(
        cycleNumber: 1,
        cycleStartedAt: null,
        policyConfigured: false,
        loanInterestRateBps: 0,
        defaultLoanTermMonths: 1,
        meetings: [],
        attendance: [],
        entries: [],
        loans: [],
      ),
      localMemberFor: phone.memberFor,
    );
    expect(result.imported, isTrue);
    expect(result.meetings, 0);
    // A group that never set rules keeps the defaults it was given, not a zero rate.
    final group = (await groups.currentGroup())!;
    expect(group.interestRate, 10.0);
  });

  group('through "Load my group"', () {
    late _FakeRestoreApi api;
    late GroupRestoreService service;

    setUp(() {
      api = _FakeRestoreApi(bundle());
      service = GroupRestoreService(
        api: api,
        groups: groups,
        members: members,
        idMap: idMap,
        history: importer,
      );
    });

    test('brings the members and the history in one go', () async {
      final result = await service.restore('remote-g');

      expect(result.alreadyPresent, isFalse);
      expect(result.membersRestored, 2);
      expect(result.history!.meetings, 2);
      expect(result.historyPending, isFalse);
      expect(result.group!.cycleNumber, 2);
      expect((await idMap.remoteId(MapEntity.groupHistory, result.group!.id)), 'done');
    });

    test('a dropped signal leaves the group there and the history to follow, once', () async {
      api.bundleThrows = true;
      final result = await service.restore('remote-g');

      expect(result.history, isNull);
      expect(result.historyPending, isTrue);
      expect(result.membersRestored, 2, reason: 'the part that matters is already on the phone');
      final local = result.group!.id;
      expect(await idMap.remoteId(MapEntity.groupHistory, local), 'pending');
      expect(await DashboardRepository(db).summary(local).then((s) => s.totalSavings), 0.0);

      // The signal is back: the next sync finishes it.
      api.bundleThrows = false;
      await service.completePendingHistory();
      expect(await idMap.remoteId(MapEntity.groupHistory, local), 'done');
      expect(await DashboardRepository(db).summary(local).then((s) => s.totalSavings), 1000.0);

      // And a further sync does not add it a second time.
      await service.completePendingHistory();
      final database = await db.database;
      expect((await database.query('meetings')).length, 2);
    });

    test('a server that cannot give the history still restores the group', () async {
      api.noBundle = true;
      final result = await service.restore('remote-g');

      expect(result.group, isNotNull);
      expect(result.membersRestored, 2);
      expect(result.history!.imported, isFalse);
      expect(result.historyPending, isFalse);
      expect(await idMap.remoteId(MapEntity.groupHistory, result.group!.id), 'skipped');
    });

    test('running it again does not restore twice', () async {
      await service.restore('remote-g');
      final again = await service.restore('remote-g');

      expect(again.alreadyPresent, isTrue);
      final database = await db.database;
      expect((await database.query('meetings')).length, 2);
    });
  });
}

class _FakeRestoreApi implements RemoteApiLike {
  _FakeRestoreApi(this._bundle);

  final RestoreBundle _bundle;
  bool bundleThrows = false;
  bool noBundle = false;

  @override
  Future<RemoteGroup> groupDetail(String groupId) async => RemoteGroup.fromJson({
        'id': groupId,
        'name': 'Umoja Women Group',
        'code': 'IWL-KBU-0001',
        'phase': 'ACTIVE',
        'county': 'Kiambu',
        'shareValueCents': 50000,
        'maxSharesPerMemberPerMeeting': 5,
        'cycleNumber': 2,
      });

  @override
  Future<List<RemoteMember>> groupMembers(String groupId) async => [
        RemoteMember.fromJson({
          'id': 'r-alice',
          'fullName': 'Alice Achieng',
          'phone': '+254700000001',
          'role': 'MEMBER',
          'status': 'ACTIVE',
        }),
        RemoteMember.fromJson({
          'id': 'r-brian',
          'fullName': 'Brian Bett',
          'phone': '+254700000002',
          'role': 'MEMBER',
          'status': 'ACTIVE',
        }),
      ];

  @override
  Future<RestoreBundle?> restoreBundle(String groupId) async {
    if (bundleThrows) throw Exception('no signal');
    return noBundle ? null : _bundle;
  }
}
