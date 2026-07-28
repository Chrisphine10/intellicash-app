import '../../data/models/enums.dart';

/// Loan arithmetic for VSLA lending rules.
///
/// Rates are **per month**, matching how VSLAs quote them (e.g. "5%").
abstract final class LoanCalculator {
  /// Total repayable at disbursement.
  ///
  /// Flat: interest on the full principal every month of the term.
  /// Reducing balance: interest on the outstanding principal, assuming the
  /// principal reduces in equal monthly installments — the standard
  /// `P * r * (n + 1) / 2` total-interest formula.
  static double totalDue({
    required double principal,
    required double monthlyRatePercent,
    required int termMonths,
    required InterestType type,
  }) {
    final r = monthlyRatePercent / 100;
    final interest = switch (type) {
      InterestType.flat => principal * r * termMonths,
      InterestType.reducingBalance => principal * r * (termMonths + 1) / 2,
    };
    return _round2(principal + interest);
  }

  /// The ceiling a member may borrow: `savings x multiplier`, less what they
  /// still owe on active loans. Never negative.
  static double availableAmount({
    required double totalSavings,
    required double multiplier,
    required double activeLoanBalance,
  }) {
    final available = totalSavings * multiplier - activeLoanBalance;
    return available > 0 ? _round2(available) : 0;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}
