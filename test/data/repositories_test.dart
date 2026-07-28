import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/utils/domain_exception.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/repositories/dashboard_repository.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/loan_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the full VSLA cycle against a real SQLite database:
/// group setup -> meeting -> attendance -> shares -> fines -> social fund
/// -> loan disbursement -> repayment -> close & lock -> dashboard.
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late MeetingRepository meetings;
  late LoanRepository loans;
  late DashboardRepository dashboard;
  late SyncRepository sync;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('intellicash_test');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    meetings = MeetingRepository(db);
    loans = LoanRepository(db);
    dashboard = DashboardRepository(db);
    sync = SyncRepository(db);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<Group> createTestGroup() {
    return groups.createGroup(
      name: 'Umoja Women Group',
      cycleNumber: 2,
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
  }

  test('group setup creates the group with its founding members', () async {
    final group = await createTestGroup();

    final loaded = await groups.currentGroup();
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Umoja Women Group');
    expect(loaded.shareValue, 100);

    final roster = await members.membersForGroup(group.id);
    expect(roster, hasLength(3));
    expect(await sync.pendingCount(), 4); // 1 group + 3 members
  });

  test('full meeting cycle enforces every rule and feeds the dashboard',
      () async {
    final group = await createTestGroup();
    final roster = await members.membersForGroup(group.id);
    final achieng =
        roster.firstWhere((m) => m.name == 'Achieng Odhiambo');
    final wanjiku = roster.firstWhere((m) => m.name == 'Wanjiku Kamau');

    // --- Meeting #1: attendance + savings ---
    final meeting1 = await meetings.startMeeting(group);
    expect(meeting1.number, 1);
    expect(meeting1.openingBalance, 0);

    // A second open meeting is refused.
    expect(() => meetings.startMeeting(group),
        throwsA(isA<DomainException>()));

    await meetings.setAttendance(
        meeting: meeting1, memberId: achieng.id, present: true);
    await meetings.setAttendance(
        meeting: meeting1, memberId: wanjiku.id, present: true);

    // Shares: cap respected across multiple purchases.
    await meetings.recordSharePurchase(
        meeting: meeting1, group: group, memberId: achieng.id, shares: 10);
    expect(
      () => meetings.recordSharePurchase(
          meeting: meeting1, group: group, memberId: achieng.id, shares: 1),
      throwsA(isA<DomainException>()),
    );
    await meetings.recordSharePurchase(
        meeting: meeting1, group: group, memberId: wanjiku.id, shares: 6);

    await meetings.recordFine(
        meeting: meeting1,
        memberId: wanjiku.id,
        amount: 50,
        reason: 'Late arrival');
    final collected = await meetings.collectSocialFundFromPresent(
        meeting: meeting1, group: group);
    expect(collected, 2); // both present members contribute KSh 50

    final totals1 = await meetings.totals(meeting1.id);
    expect(totals1.sharesAmount, 1600); // 16 shares x 100
    expect(totals1.fines, 50);
    expect(totals1.socialFund, 100);
    expect(totals1.presentCount, 2);

    // --- Loan: eligibility enforced from savings ---
    final eligibility =
        await loans.eligibility(group: group, memberId: achieng.id);
    expect(eligibility.totalSavings, 1000);
    expect(eligibility.maxLoan, 2000);
    expect(eligibility.availableAmount, 2000);

    expect(
      () => loans.disburse(
        group: group,
        memberId: achieng.id,
        principal: 2500, // above the 2x ceiling
        dueDate: DateTime.now().add(const Duration(days: 90)),
      ),
      throwsA(isA<DomainException>()),
    );

    final loan = await loans.disburse(
      group: group,
      memberId: achieng.id,
      principal: 2000,
      dueDate: DateTime.now().add(const Duration(days: 92)),
      meetingId: meeting1.id,
    );
    // 3-month reducing balance at 5%: 2000 * 0.05 * (3+1)/2 = 200
    expect(loan.totalDue, 2200);

    // --- Close & lock ---
    final closed = await meetings.closeMeeting(meeting1);
    expect(closed.status, MeetingStatus.closed);
    expect(
      () => meetings.recordSharePurchase(
          meeting: closed, group: group, memberId: wanjiku.id, shares: 1),
      throwsA(isA<DomainException>()),
    );

    // --- Meeting #2 opens with the cash box balance ---
    final meeting2 = await meetings.startMeeting(group);
    expect(meeting2.number, 2);
    // 1600 shares + 50 fine + 100 social fund - 2000 loan = -250
    expect(meeting2.openingBalance, -250);

    // --- Repayment flips the loan to repaid at zero outstanding ---
    final partly = await loans.repay(loan: loan, amount: 1200);
    expect(partly.status, LoanStatus.active);
    expect(partly.outstanding, 1000);

    final settled = await loans.repay(loan: partly, amount: 1000);
    expect(settled.status, LoanStatus.repaid);
    expect(settled.outstanding, 0);

    expect(() => loans.repay(loan: settled, amount: 10),
        throwsA(isA<DomainException>()));

    // --- Dashboard aggregates line up ---
    final summary = await dashboard.summary(group.id);
    expect(summary.totalSavings, 1600);
    expect(summary.activeLoans, 0);
    expect(summary.memberCount, 3);
    expect(summary.meetingCount, 2);
    expect(summary.finesCollected, 50);
    expect(summary.socialFund, 100);
    expect(summary.trend, hasLength(2));
    expect(summary.trend.first.cumulativeSavings, 1600);

    // --- Member financials join ---
    final financials = await members.financialsForGroup(group.id);
    final achiengPos =
        financials.firstWhere((f) => f.member.id == achieng.id);
    expect(achiengPos.totalSavings, 1000);
    expect(achiengPos.hasActiveLoan, false);

    // Everything queued for the cloud.
    expect(await sync.pendingCount(), greaterThan(10));
  });

  test('active loans past their due date surface as defaulted', () async {
    final group = await createTestGroup();
    final roster = await members.membersForGroup(group.id);
    final member = roster.first;

    final meeting = await meetings.startMeeting(group);
    await meetings.recordSharePurchase(
        meeting: meeting, group: group, memberId: member.id, shares: 10);

    final loan = await loans.disburse(
      group: group,
      memberId: member.id,
      principal: 500,
      dueDate: DateTime.now().add(const Duration(days: 40)),
    );

    // Backdate the due date to simulate an overdue loan.
    final database = await db.database;
    await database.update(
      'loans',
      {'due_date': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()},
      where: 'id = ?',
      whereArgs: [loan.id],
    );

    final portfolio = await loans.loansForGroup(group.id);
    expect(portfolio.single.status, LoanStatus.defaulted);
  });

  test('sync queue drains only when the sender accepts the batch', () async {
    await createTestGroup();
    final before = await sync.pendingCount();
    expect(before, greaterThan(0));

    // Sender fails -> queue intact.
    final failed = await sync.drain((_) async => false);
    expect(failed, 0);
    expect(await sync.pendingCount(), before);

    // Sender succeeds -> queue empty.
    final pushed = await sync.drain((batch) async {
      expect(batch, hasLength(before));
      expect(batch.first['entityType'], 'group');
      return true;
    });
    expect(pushed, before);
    expect(await sync.pendingCount(), 0);
  });
}
