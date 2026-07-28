import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/loan_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/share_out_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int c(double kes) => (kes * 100).round();

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
    tempDir = await Directory.systemTemp.createTemp('ic_shareout');
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
    await tempDir.delete(recursive: true);
  });

  Future<Group> seedGroup() async {
    await groups.createGroup(
      name: 'Share-Out Group',
      cycleNumber: 1,
      savingsMode: SavingsMode.fixed,
      shareValue: 100,
      maxSharesPerMeeting: 20,
      socialFundAmount: 50,
      interestRate: 10, // 10%/month
      interestType: InterestType.flat,
      loanMultiplier: 2,
      defaultLoanTermMonths: 3,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [DateTime.sunday],
      memberNames: const ['Ann', 'Ben', 'Cara'],
    );
    // Pin the cycle start well before the seeded activity so every entry
    // counts toward the current cycle.
    final g = (await groups.currentGroup())!
        .copyWith(cycleStartDate: DateTime(2026, 1, 1));
    await groups.updateGroup(g);
    return (await groups.currentGroup())!;
  }

  test('computes a correct, balanced share-out and rolls the cycle', () async {
    final group = await seedGroup();
    final roster = await members.membersForGroup(group.id);
    final ann = roster.firstWhere((m) => m.name == 'Ann');
    final ben = roster.firstWhere((m) => m.name == 'Ben');
    final cara = roster.firstWhere((m) => m.name == 'Cara');

    final meeting = await meetings.startMeeting(group);
    // Contributions: Ann 1000, Ben 600, Cara 400 -> capital 2000.
    await meetings.recordSharePurchase(
        meeting: meeting, group: group, memberId: ann.id, shares: 10);
    await meetings.recordSharePurchase(
        meeting: meeting, group: group, memberId: ben.id, shares: 6);
    await meetings.recordSharePurchase(
        meeting: meeting, group: group, memberId: cara.id, shares: 4);
    // A fine builds the welfare fund.
    await meetings.recordFine(
        meeting: meeting, memberId: ann.id, amount: 90, reason: 'Late');

    // Ben takes a loan and repays it in full -> the group earns its interest.
    final benLoan = await loans.disburse(
      group: group,
      memberId: ben.id,
      principal: 500,
      dueDate: DateTime.now().add(const Duration(days: 90)),
      meetingId: meeting.id,
    );
    await loans.repay(loan: benLoan, amount: benLoan.outstanding, meetingId: meeting.id);

    // Cara takes a loan and only partly repays -> outstanding at share-out.
    final caraLoan = await loans.disburse(
      group: group,
      memberId: cara.id,
      principal: 300,
      dueDate: DateTime.now().add(const Duration(days: 90)),
      meetingId: meeting.id,
    );
    await loans.repay(loan: caraLoan, amount: 100, meetingId: meeting.id);
    final caraOutstanding = caraLoan.totalDue - 100;

    // --- Preview ---
    final preview = await shareOut.preview(group);

    expect(preview.shareCapitalCents, c(2000));
    // Pool (E) = capital + repayments - disbursed + outstanding, rounded
    // per component exactly as the repository does.
    final expectedPool = c(2000) +
        c(benLoan.totalDue + 100) -
        c(800) +
        c(caraOutstanding);
    expect(preview.savingsPoolCents, expectedPool);
    expect(preview.interestEarnedCents, greaterThan(0));
    expect(preview.welfarePoolCents, c(90));
    expect(preview.isBalanced, isTrue,
        reason: 'gross payouts must sum to exactly the pool');

    // Ann contributed half the capital -> half the pool (± rounding).
    final annLine = preview.lines.firstWhere((l) => l.memberId == ann.id);
    expect(annLine.sharePercent, closeTo(0.5, 1e-9));
    expect(annLine.grossPayoutCents,
        closeTo(expectedPool * 1000 / 2000, 1));

    // Cara's loan is netted off her payout.
    final caraLine = preview.lines.firstWhere((l) => l.memberId == cara.id);
    expect(caraLine.loanOffsetCents, c(caraOutstanding));
    expect(caraLine.netPayoutCents,
        caraLine.grossPayoutCents - caraLine.loanOffsetCents);

    // Conservation: net cash out = pool - outstanding (welfare retained).
    expect(preview.totalNetPaidCents,
        preview.savingsPoolCents - c(caraOutstanding));

    // --- Welfare toggle recomputes the split ---
    await shareOut.preview(group, distributeWelfare: true).then((withWelfare) {
      expect(withWelfare.lines.map((l) => l.welfareCents).reduce((a, b) => a + b),
          c(90));
    });

    // --- Commit ---
    final next = await shareOut.commit(group, preview);
    expect(next.cycleNumber, 2);
    expect(next.cycleStartDate.isAfter(group.cycleStartDate), isTrue);

    // Group in storage advanced to cycle 2.
    final reloaded = await groups.currentGroup();
    expect(reloaded!.cycleNumber, 2);

    // Both loans are now settled.
    final groupLoans = await loans.loansForGroup(group.id);
    expect(groupLoans.every((l) => l.status == LoanStatus.repaid), isTrue);
    expect(groupLoans.firstWhere((l) => l.memberId == cara.id).outstanding, 0);

    // History holds the completed share-out.
    final history = await shareOut.history(group.id);
    expect(history, hasLength(1));
    expect(history.single.cycleNumber, 1);
    expect(history.single.payouts, hasLength(3));

    // The new cycle starts empty — nothing to share out again.
    final freshPreview = await shareOut.preview(reloaded);
    expect(freshPreview.shareCapitalCents, 0);
  });

  test('refuses to share out a cycle with no contributions', () async {
    final group = await seedGroup();
    final empty = await shareOut.preview(group);
    expect(empty.shareCapitalCents, 0);
    expect(
      () => shareOut.commit(group, empty),
      throwsA(anything),
    );
  });
}
