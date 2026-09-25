import '../../data/models/enums.dart';

/// Loan arithmetic for VSLA lending rules.
///
/// Rates are **per month**, matching how VSLAs quote them (e.g. "5%").
abstract final class LoanCalculator {
  /// The most a loan can cost: principal plus a month's interest for every
  /// month of the term, as if nothing were repaid. For both flat and reducing
  /// balance that is `P * r * n` — reducing balance only costs less once
  /// principal is actually repaid, which [LoanAccrual] works out month by
  /// month from the repayments (same rule as the server). What a member owes
  /// on a given day is `Loan.positionAsOf`, not this.
  static double totalDue({
    required double principal,
    required double monthlyRatePercent,
    required int termMonths,
    required InterestType type,
  }) {
    final r = monthlyRatePercent / 100;
    final interest = principal * r * termMonths;
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
