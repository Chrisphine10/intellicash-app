import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/loan.dart';
import 'package:intellicash_mobile/data/models/member.dart';
import 'package:intellicash_mobile/data/models/remote/group_report.dart';
import 'package:intellicash_mobile/features/reports/pdf_report.dart';

Group _group() => Group(
      id: 'g1',
      name: 'Test Group',
      cycleNumber: 1,
      cycleStartDate: DateTime(2026, 1, 1),
      savingsMode: SavingsMode.fixed,
      shareValue: 100,
      maxSharesPerMeeting: 10,
      socialFundAmount: 50,
      interestRate: 5,
      interestType: InterestType.reducingBalance,
      loanMultiplier: 2,
      defaultLoanTermMonths: 3,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [7],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Member _member() => Member(
      id: 'm1',
      groupId: 'g1',
      name: 'Ann Test',
      role: MemberRole.chairperson,
      joinedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('group PDF builder produces a valid PDF document', () async {
    final bytes = await buildGroupPdfBytes(
      group: _group(),
      totalSavings: 12500,
      socialFund: 800,
      fines: 150,
      loansGivenOut: 5000,
      loansRepaid: 2500,
      loansStillOwed: 2750,
      cashBox: 10700,
      members: [
        ReportMemberRow.fromLocal(
          MemberFinancials(
            member: _member(),
            totalSavings: 12500,
            totalShares: 125,
            activeLoanBalance: 2750,
            hasDefaultedLoan: false,
          ),
        ),
      ],
      meetingsThisCycle: 8,
    );
    // A real PDF starts with %PDF- and ends with %%EOF.
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(ascii.decode(bytes.skip(bytes.length - 32).toList()),
        contains('%%EOF'));
    expect(bytes.length, greaterThan(1000));
  });

  test('member PDF builder produces a valid PDF document', () async {
    final bytes = await buildMemberPdfBytes(
      group: _group(),
      member: _member(),
      totalSavings: 12500,
      totalShares: 125,
      socialContributions: 800,
      finesPaid: 150,
      activeLoanBalance: 2750,
      attendanceRate: 0.9,
      loans: [
        Loan(
          id: 'l1',
          groupId: 'g1',
          memberId: 'm1',
          principal: 5000,
          interestRate: 5,
          interestType: InterestType.reducingBalance,
          totalDue: 5250,
          disbursedAt: DateTime(2026, 3, 1),
          dueDate: DateTime(2026, 6, 1),
          status: LoanStatus.active,
          createdAt: DateTime(2026, 3, 1),
        ),
      ],
    );
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
