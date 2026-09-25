import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/loan_calculator.dart';
import 'package:intellicash_mobile/data/models/enums.dart';

void main() {
  group('LoanCalculator.totalDue', () {
    test('flat interest charges the full principal every month', () {
      // 5,000 at 5% flat for 3 months -> 5,000 + 3 * 250 = 5,750
      expect(
        LoanCalculator.totalDue(
          principal: 5000,
          monthlyRatePercent: 5,
          termMonths: 3,
          type: InterestType.flat,
        ),
        5750,
      );
    });

    test('the at-term maximum is the same for flat and reducing balance', () {
      // Nothing repaid: every month is charged on the full principal either
      // way (5,000 x 5% x 3 = 750). Reducing balance only costs less once
      // principal is repaid — worked out month by month by LoanAccrual and
      // checked in loan_accrual_fixture_test.dart.
      for (final type in InterestType.values) {
        expect(
          LoanCalculator.totalDue(
            principal: 5000,
            monthlyRatePercent: 5,
            termMonths: 3,
            type: type,
          ),
          5750,
        );
      }
    });

    test('zero rate charges no interest', () {
      expect(
        LoanCalculator.totalDue(
          principal: 1200,
          monthlyRatePercent: 0,
          termMonths: 3,
          type: InterestType.flat,
        ),
        1200,
      );
    });
  });

  group('LoanCalculator.availableAmount', () {
    test('matches the deck example: 3,300 savings at 2x with no loan', () {
      expect(
        LoanCalculator.availableAmount(
          totalSavings: 3300,
          multiplier: 2,
          activeLoanBalance: 0,
        ),
        6600,
      );
    });

    test('active balance reduces the headroom', () {
      expect(
        LoanCalculator.availableAmount(
          totalSavings: 3300,
          multiplier: 2,
          activeLoanBalance: 5000,
        ),
        1600,
      );
    });

    test('never goes negative', () {
      expect(
        LoanCalculator.availableAmount(
          totalSavings: 100,
          multiplier: 2,
          activeLoanBalance: 5000,
        ),
        0,
      );
    });
  });
}
