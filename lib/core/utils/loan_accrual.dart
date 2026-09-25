import '../../data/models/enums.dart';

/// What a loan owes on a given day, month by month — the SAME rule the server
/// applies (intellicash_admin apps/api/src/domain/loan-math.ts), so a member is
/// told one balance whether they ask the phone or the console.
///
/// - Interest is charged for each COMPLETED 30-day month since the loan was
///   given out, never more months than the term.
/// - FLAT: each month costs rate x the original principal.
/// - REDUCING balance: each month costs rate x the principal still unpaid at
///   the START of that month. Money paid during a month clears interest
///   already charged first, then principal, so it lowers the NEXT month's
///   charge. A payment exactly at a month's end counts in the following month.
/// - A repayment that covers everything owed at that moment settles the loan
///   and its interest stops there; anything beyond is an overpayment.
///
/// Integer cents throughout, rounded as the server rounds. Both sides are
/// checked against the same hand-worked cases
/// (test/fixtures/loan-accrual-cases.json, copied from the server's qa/).
abstract final class LoanAccrual {
  static const monthMs = 30 * 24 * 60 * 60 * 1000;

  static int elapsedMonths(DateTime disbursedAt, DateTime asOf) {
    final ms = asOf.millisecondsSinceEpoch - disbursedAt.millisecondsSinceEpoch;
    if (ms <= 0) return 0;
    return ms ~/ monthMs;
  }

  static int chargeableMonths(DateTime disbursedAt, int termMonths, DateTime asOf) {
    final elapsed = elapsedMonths(disbursedAt, asOf);
    final term = termMonths < 0 ? 0 : termMonths;
    return elapsed < term ? elapsed : term;
  }

  /// Interest charged up to [asOf]. [applications] is money applied to THIS
  /// loan (only reducing balance needs it).
  static int interestCents({
    required int principalCents,
    required int rateBps,
    required int termMonths,
    required InterestType type,
    required DateTime disbursedAt,
    required DateTime asOf,
    List<LoanMoney> applications = const [],
  }) {
    final months = chargeableMonths(disbursedAt, termMonths, asOf);
    if (months == 0 || rateBps <= 0) return 0;

    if (type != InterestType.reducingBalance) {
      return _roundHalfUp(principalCents * rateBps * months / 10000);
    }

    final payments = applications
        .where((p) => !p.at.isAfter(asOf))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    var principalLeft = principalCents;
    var unpaidInterest = 0;
    var total = 0;
    var next = 0;
    final start = disbursedAt.millisecondsSinceEpoch;
    for (var month = 1; month <= months; month++) {
      final charge = _roundHalfUp(principalLeft * rateBps / 10000);
      final end = start + month * monthMs;
      while (next < payments.length && payments[next].at.millisecondsSinceEpoch < end) {
        var cents = payments[next].cents;
        final toInterest = cents < unpaidInterest ? cents : unpaidInterest;
        unpaidInterest -= toInterest;
        cents -= toInterest;
        principalLeft = principalLeft - cents < 0 ? 0 : principalLeft - cents;
        next++;
      }
      unpaidInterest += charge;
      total += charge;
    }
    return total;
  }

  /// Replays [repayments] in order, as the server's memberLoanPosition does
  /// for one loan: each clears what the loan owed ON THAT DAY, and the loan is
  /// settled (interest stops) once a repayment covers it.
  static LoanPosition position({
    required int principalCents,
    required int rateBps,
    required int termMonths,
    required InterestType type,
    required DateTime disbursedAt,
    required List<LoanMoney> repayments,
    required DateTime asOf,
  }) {
    final events = repayments
        .where((r) => r.cents > 0 && !r.at.isAfter(asOf))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));

    var applied = 0;
    var surplus = 0;
    DateTime? settledAt;
    final applications = <LoanMoney>[];

    for (final repayment in events) {
      // Money paid before the loan existed was not paid towards it (the
      // server drops it the same way).
      if (repayment.at.isBefore(disbursedAt)) continue;
      if (settledAt != null) {
        surplus += repayment.cents;
        continue;
      }
      final owed = principalCents +
          interestCents(
            principalCents: principalCents,
            rateBps: rateBps,
            termMonths: termMonths,
            type: type,
            disbursedAt: disbursedAt,
            asOf: repayment.at,
            applications: applications,
          ) -
          applied;
      if (owed <= 0) {
        settledAt = repayment.at;
        surplus += repayment.cents;
        continue;
      }
      final take = repayment.cents < owed ? repayment.cents : owed;
      applied += take;
      applications.add(LoanMoney(repayment.at, take));
      surplus += repayment.cents - take;
      if (take == owed) settledAt = repayment.at;
    }

    final interest = interestCents(
      principalCents: principalCents,
      rateBps: rateBps,
      termMonths: termMonths,
      type: type,
      disbursedAt: disbursedAt,
      asOf: settledAt ?? asOf,
      applications: applications,
    );
    final net = principalCents + interest - applied;
    return LoanPosition(
      principalCents: principalCents,
      interestCents: interest,
      repaidCents: applied + surplus,
      outstandingCents: net > 0 ? net : 0,
      overpaidCents: (net < 0 ? -net : 0) + surplus,
      settled: net <= 0,
      settledAt: settledAt,
    );
  }

  /// Math.round semantics (half up), matching the server's JavaScript.
  static int _roundHalfUp(double value) => (value + 0.5).floor();
}

/// An amount of money at a moment: a repayment, or the part of one applied.
class LoanMoney {
  const LoanMoney(this.at, this.cents);

  final DateTime at;
  final int cents;
}

class LoanPosition {
  const LoanPosition({
    required this.principalCents,
    required this.interestCents,
    required this.repaidCents,
    required this.outstandingCents,
    required this.overpaidCents,
    required this.settled,
    this.settledAt,
  });

  final int principalCents;
  final int interestCents;
  final int repaidCents;

  /// principal + interest so far - repaid; never negative.
  final int outstandingCents;

  /// Paid beyond what was owed: refundable, not a negative balance.
  final int overpaidCents;
  final bool settled;
  final DateTime? settledAt;
}
