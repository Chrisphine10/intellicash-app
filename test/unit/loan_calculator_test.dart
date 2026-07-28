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

    test('reducing balance charges interest on the declining principal', () {
      // 5,000 at 5% reducing over 3 months -> interest = P*r*(n+1)/2 = 500
      expect(
        LoanCalculator.totalDue(
          principal: 5000,
          monthlyRatePercent: 5,
          termMonths: 3,
          type: InterestType.reducingBalance,
        ),
        5500,
      );
    });

    test('reducing balance is cheaper than flat for the same terms', () {
      final flat = LoanCalculator.totalDue(
        principal: 10000,
        monthlyRatePercent: 5,
        termMonths: 6,
        type: InterestType.flat,
      );
      final reducing = LoanCalculator.totalDue(
        principal: 10000,
        monthlyRatePercent: 5,
        termMonths: 6,
        type: InterestType.reducingBalance,
      );
      expect(reducing, lessThan(flat));
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
