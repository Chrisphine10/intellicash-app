import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:intellicash_mobile/core/utils/loan_accrual.dart';
import 'package:intellicash_mobile/data/models/enums.dart';

/// The phone and the server must owe a member the same money.
///
/// test/fixtures/loan-accrual-cases.json is a copy of the server's
/// qa/fixtures/loan-accrual-cases.json; the server runs the same cases through
/// its own implementation (apps/api/tests/loan-accrual-fixture.test.ts). A rule
/// changed on one side only fails the other side's test.
void main() {
  final fixture = jsonDecode(File('test/fixtures/loan-accrual-cases.json').readAsStringSync())
      as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
  final base = DateTime.utc(2026, 1, 1);
  DateTime day(num n) => base.add(Duration(days: n.toInt()));

  test('has the shared cases', () {
    expect(cases.length, greaterThanOrEqualTo(12));
  });

  for (final entry in cases) {
    test(entry['name'] as String, () {
      final loan = entry['loan'] as Map<String, dynamic>;
      final position = LoanAccrual.position(
        principalCents: loan['principalCents'] as int,
        rateBps: loan['interestRateBps'] as int,
        termMonths: loan['termMonths'] as int,
        type: loan['interestType'] == 'REDUCING' ? InterestType.reducingBalance : InterestType.flat,
        disbursedAt: day(0),
        repayments: [
          for (final r in (entry['repayments'] as List).cast<Map<String, dynamic>>())
            LoanMoney(day(r['day'] as num), r['cents'] as int),
        ],
        asOf: day(entry['asOfDay'] as num),
      );
      final expected = entry['expect'] as Map<String, dynamic>;
      expect(
        {
          'interestCents': position.interestCents,
          'repaidCents': position.repaidCents,
          'outstandingCents': position.outstandingCents,
          'overpaidCents': position.overpaidCents,
          'settled': position.settled,
        },
        expected,
      );
    });
  }
}
