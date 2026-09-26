import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/remote/restore_bundle.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/loan_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/share_out_repository.dart';

/// The group's calculations follow the group's own rules, month by month, on
/// the phone exactly as on the server.
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late MeetingRepository meetings;
  late LoanRepository loans;
  late ShareOutRepository shareOut;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_money_rules');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    meetings = MeetingRepository(db);
    loans = LoanRepository(db);
    shareOut = ShareOutRepository(db);
  });

  tearDown(() async {
    await db.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Future<Group> seedGroup({InterestType type = InterestType.flat}) async {
    await groups.createGroup(
      name: 'Rules Group',
      cycleNumber: 1,
      savingsMode: SavingsMode.fixed,
      shareValue: 100,
      maxSharesPerMeeting: 20,
      socialFundAmount: 50,
      interestRate: 10,
      interestType: type,
      loanMultiplier: 3,
      defaultLoanTermMonths: 3,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [DateTime.sunday],
      memberNames: const ['Ann', 'Ben'],
    );
    final g = (await groups.currentGroup())!.copyWith(cycleStartDate: DateTime(2026, 1, 1));
    await groups.updateGroup(g);
    return (await groups.currentGroup())!;
  }

  /// Moves a loan back in time as a whole: given out [days] ago, still due
  /// three months after that (its term does not change).
  Future<void> backdate(String loanId, int days) async {
    final database = await db.database;
    final disbursed = DateTime.now().subtract(Duration(days: days));
    await database.update(
      'loans',
      {
        'disbursed_at': disbursed.toIso8601String(),
        'due_date': DateTime(disbursed.year, disbursed.month + 3, disbursed.day).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  test('interest builds month by month and stops at the term', () async {
    final group = await seedGroup();
    final ann = (await members.membersForGroup(group.id)).first;
    final meeting = await meetings.startMeeting(group);
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: ann.id, shares: 10);
    final loan = await loans.disburse(
      group: group,
      memberId: ann.id,
      principal: 1000,
      dueDate: DateTime.now().add(const Duration(days: 92)),
      meetingId: meeting.id,
    );

    expect(loan.outstanding, 1000, reason: 'no month completed yet');
    await backdate(loan.id, 31);
    expect((await loans.loanById(loan.id))!.outstanding, 1100, reason: 'one month at 10%');
    await backdate(loan.id, 65);
    expect((await loans.loanById(loan.id))!.outstanding, 1200);
    await backdate(loan.id, 400);
    expect((await loans.loanById(loan.id))!.outstanding, 1300, reason: 'capped at the 3-month term');
  });

  test('reducing balance charges less once principal is repaid', () async {
    final group = await seedGroup(type: InterestType.reducingBalance);
    final ann = (await members.membersForGroup(group.id)).first;
    final meeting = await meetings.startMeeting(group);
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: ann.id, shares: 10);
    final loan = await loans.disburse(
      group: group,
      memberId: ann.id,
      principal: 1000,
      dueDate: DateTime.now().add(const Duration(days: 92)),
      meetingId: meeting.id,
    );
    await backdate(loan.id, 95);
    // Half the principal paid back in the first month (10 days in).
    final database = await db.database;
    await database.insert('loan_repayments', {
      'id': 'early-half',
      'loan_id': loan.id,
      'meeting_id': null,
      'amount': 500,
      'paid_at': DateTime.now().subtract(const Duration(days: 85)).toIso8601String(),
    });
    final now = (await loans.loanById(loan.id))!;
    // Month 1: 100 (on 1,000). Months 2 and 3: 50 each (on the 500 left).
    expect(now.interestSoFar, 200);
    expect(now.outstanding, 700);
  });

  test("a payment clears the member's oldest loan first, as the server applies it", () async {
    final group = await seedGroup();
    final ann = (await members.membersForGroup(group.id)).first;
    final meeting = await meetings.startMeeting(group);
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: ann.id, shares: 20);
    final older = await loans.disburse(
      group: group,
      memberId: ann.id,
      principal: 300,
      dueDate: DateTime.now().add(const Duration(days: 92)),
      meetingId: meeting.id,
    );
    // Make it plainly the older one.
    final database = await db.database;
    await database.update('loans', {'disbursed_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
        where: 'id = ?', whereArgs: [older.id]);
    final newer = await loans.disburse(
      group: group,
      memberId: ann.id,
      principal: 250,
      dueDate: DateTime.now().add(const Duration(days: 92)),
      meetingId: meeting.id,
    );

    // The treasurer picks the newer loan and records 250.
    await loans.repay(loan: newer, amount: 250, meetingId: meeting.id);

    final oldAfter = (await loans.loanById(older.id))!;
    final newAfter = (await loans.loanById(newer.id))!;
    expect(oldAfter.outstanding, 50, reason: 'the payment went to the oldest loan first');
    expect(newAfter.outstanding, 250);
    expect(await loans.owedByMember(ann.id), 300);

    // 300 more clears the rest of the old loan and rolls 250 onto the newer one.
    await loans.repay(loan: newAfter, amount: 250, meetingId: meeting.id);
    await loans.repay(loan: (await loans.loanById(newer.id))!, amount: 50, meetingId: meeting.id);
    expect((await loans.loanById(older.id))!.status, LoanStatus.repaid);
    expect((await loans.loanById(newer.id))!.status, LoanStatus.repaid);
    expect(await loans.owedByMember(ann.id), 0);
  });

  test('share-out nets and settles a loan carried over from an earlier cycle', () async {
    final group = await seedGroup();
    final roster = await members.membersForGroup(group.id);
    final ann = roster.firstWhere((m) => m.name == 'Ann');
    final ben = roster.firstWhere((m) => m.name == 'Ben');
    final meeting = await meetings.startMeeting(group);
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: ann.id, shares: 10);
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: ben.id, shares: 10);
    final old = await loans.disburse(
      group: group,
      memberId: ben.id,
      principal: 400,
      dueDate: DateTime.now().add(const Duration(days: 92)),
      meetingId: meeting.id,
    );
    await meetings.closeMeeting(meeting);

    // The loan belongs to the previous cycle: it was lent before this one began.
    final database = await db.database;
    await database.update('loans', {'disbursed_at': DateTime(2025, 12, 1).toIso8601String()},
        where: 'id = ?', whereArgs: [old.id]);
    final owed = (await loans.loanById(old.id))!.outstanding;
    expect(owed, greaterThan(400), reason: 'interest has built up since December');

    final preview = await shareOut.preview((await groups.currentGroup())!);
    final benLine = preview.lines.firstWhere((line) => line.memberId == ben.id);
    expect(benLine.loanOffsetCents, (owed * 100).round(), reason: 'the old loan is netted off his payout');

    await shareOut.commit((await groups.currentGroup())!, preview);
    final settled = (await loans.loanById(old.id))!;
    expect(settled.status, LoanStatus.repaid, reason: 'never carried forward again');
    expect(settled.outstanding, 0);
  });

  test('the social fund screen total is what was recorded, not payers x today\'s amount', () async {
    var group = await seedGroup();
    final roster = await members.membersForGroup(group.id);
    final meeting = await meetings.startMeeting(group);
    await meetings.setSocialFundPaid(meeting: meeting, group: group, memberId: roster[0].id, paid: true);
    // The group raises its amount mid-meeting; the first member paid 50.
    await groups.updateGroup(group.copyWith(socialFundAmount: 80));
    group = (await groups.currentGroup())!;
    await meetings.setSocialFundPaid(meeting: meeting, group: group, memberId: roster[1].id, paid: true);
    expect(await meetings.socialFundCollected(meeting.id), 130);
  });

  test('collecting the social fund at KSh 0 is refused', () async {
    var group = await seedGroup();
    await groups.updateGroup(group.copyWith(socialFundAmount: 0));
    group = (await groups.currentGroup())!;
    final meeting = await meetings.startMeeting(group);
    expect(
      () => meetings.collectSocialFundFromPresent(meeting: meeting, group: group),
      throwsA(anything),
    );
  });

  test('a restored phone takes the group rules and each loan\'s own interest type', () {
    final bundle = RestoreBundle.fromJson({
      'group': {'cycleNumber': 2, 'cycleStartedAt': '2026-06-01T00:00:00.000Z', 'meetingFrequency': 'WEEKLY', 'meetingDays': '3', 'meetingTime': '15:00'},
      'policy': {
        'configured': true,
        'loanInterestRateBps': 750,
        'defaultLoanTermMonths': 4,
        'interestType': 'REDUCING',
        'shareValueCents': 20000,
        'maxSharesPerMeeting': 5,
        'socialFundCents': 5000,
        'loanMultiplierBps': 25000,
      },
      'loans': [
        {
          'id': 'l1',
          'memberId': 'm1',
          'principalCents': 100000,
          'interestRateBps': 1000,
          'interestType': 'FLAT',
          'termMonths': 2,
          'disbursedAt': '2026-06-02T00:00:00.000Z',
          'dueAt': '2026-08-02T00:00:00.000Z',
          'status': 'ACTIVE',
        },
      ],
    });
    expect(bundle.interestType, 'REDUCING');
    expect(bundle.shareValueCents, 20000);
    expect(bundle.maxSharesPerMeeting, 5);
    expect(bundle.socialFundCents, 5000);
    expect(bundle.loanMultiplierBps, 25000);
    expect(bundle.meetingTime, '15:00');
    expect(bundle.loans.single.interestType, 'FLAT', reason: 'a loan keeps the type it was lent under');
  });
}
