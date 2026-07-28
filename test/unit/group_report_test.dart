import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/group_report.dart';

/// Shaped like `GET /reports/group/:id`.
Map<String, dynamic> _payload({
  List<Map<String, dynamic>>? ledger,
  List<Map<String, dynamic>>? members,
}) =>
    {
      'generatedAt': '2026-07-19T10:00:00.000Z',
      'group': {'name': 'Tujijenge Women VSLA', 'meetingCount': 8},
      'ledger': ledger ??
          const [
            {'type': 'SHARE_PURCHASE', 'direction': 'CREDIT', 'totalCents': 1150000},
            {'type': 'SOCIAL_CONTRIBUTION', 'direction': 'CREDIT', 'totalCents': 250000},
            {'type': 'FINE_COLLECTION', 'direction': 'CREDIT', 'totalCents': 50000},
            {'type': 'INTERNAL_LOAN_DISBURSEMENT', 'direction': 'DEBIT', 'totalCents': 1000000},
            {'type': 'LOAN_REPAYMENT', 'direction': 'CREDIT', 'totalCents': 400000},
          ],
      'members': members ?? const [],
      'meetings': {'attendanceRate': 0.75},
    };

void main() {
  group('GroupReport.fromJson', () {
    test('converts cents to KES once', () {
      final r = GroupReport.fromJson(_payload());
      expect(r.socialFund, 2500);
      expect(r.fines, 500);
      expect(r.loansGivenOut, 10000);
      expect(r.loansRepaid, 4000);
    });

    test('savings is shares plus the social fund', () {
      final r = GroupReport.fromJson(_payload());
      expect(r.totalSavings, 11500 + 2500);
    });

    test('adds up a type that appears under both directions', () {
      // The server groups by type AND direction, so one type can legitimately
      // arrive as two rows — a lookup would silently drop one of them.
      final r = GroupReport.fromJson(_payload(ledger: const [
        {'type': 'SHARE_PURCHASE', 'direction': 'CREDIT', 'totalCents': 100000},
        {'type': 'SHARE_PURCHASE', 'direction': 'DEBIT', 'totalCents': 40000},
      ]));
      expect(r.totalSavings, 1400);
    });

    test('never reports a negative amount still owed', () {
      // Real seed data has a group whose repayments exceed its disbursements;
      // that must read as nothing owed, not as a negative debt.
      final r = GroupReport.fromJson(_payload(ledger: const [
        {'type': 'INTERNAL_LOAN_DISBURSEMENT', 'direction': 'DEBIT', 'totalCents': 1000000},
        {'type': 'LOAN_REPAYMENT', 'direction': 'CREDIT', 'totalCents': 1350000},
      ]));
      expect(r.loansStillOwed, 0);
    });

    test('survives a payload with nothing in it', () {
      final r = GroupReport.fromJson(const {});
      expect(r.totalSavings, 0);
      expect(r.members, isEmpty);
      expect(r.meetingCount, 0);
      expect(r.attendanceRate, isNull);
      expect(r.generatedAt, isNull);
    });

    test('reads the attendance rate and meeting count', () {
      final r = GroupReport.fromJson(_payload());
      expect(r.meetingCount, 8);
      expect(r.attendanceRate, 0.75);
    });
  });

  group('ReportMemberRow.fromJson', () {
    test('totals what a member put in and what they still owe', () {
      final r = ReportMemberRow.fromJson(const {
        'fullName': 'Mary Njeri',
        'role': 'MEMBER',
        'sharesCents': 300000,
        'socialCents': 50000,
        'loanDisbursementsCents': 500000,
        'loanRepaymentsCents': 200000,
      });
      expect(r.name, 'Mary Njeri');
      expect(r.savings, 3500);
      expect(r.owes, 3000);
    });

    test('an overpaying member owes nothing, never a negative', () {
      final r = ReportMemberRow.fromJson(const {
        'fullName': 'Faith Achieng',
        'loanDisbursementsCents': 100000,
        'loanRepaymentsCents': 180000,
      });
      expect(r.owes, 0);
    });

    test('marks office holders and leaves ordinary members unmarked', () {
      final chair = ReportMemberRow.fromJson(const {
        'fullName': 'Agnes Muthoni',
        'role': 'VICE_CHAIRPERSON',
      });
      expect(chair.roleLabel, 'Vice chairperson');

      final plain = ReportMemberRow.fromJson(const {
        'fullName': 'Nancy Atieno',
        'role': 'MEMBER',
      });
      expect(plain.roleLabel, isNull);
    });

    test('leaves the share count unknown rather than inventing one', () {
      // The server totals share value but does not count shares, and dividing
      // by the share value would go wrong if it changed mid-cycle.
      final r = ReportMemberRow.fromJson(const {
        'fullName': 'Mary Njeri',
        'sharesCents': 300000,
      });
      expect(r.shares, isNull);
    });
  });
}
