/// End-of-cycle **share-out** calculation for a VSLA group.
///
/// This is deliberately a pure, dependency-free function so the money maths can
/// be exhaustively unit-tested. It mirrors the backend's method
/// (`computeShareOutPreview` in `apps/api`): the savings pool is distributed
/// **pro-rata to each member's share contributions**, and every last cent of
/// the pool is allocated — here with the *largest-remainder* method so the
/// rounding is spread fairly rather than dumped on one member.
///
/// All amounts are handled as integer **cents** to avoid floating-point drift;
/// callers convert to/from KES at the edges.
library;

/// One member's inputs to the share-out.
class ShareOutMember {
  const ShareOutMember({
    required this.memberId,
    required this.memberName,
    required this.shareCents,
    this.outstandingCents = 0,
  });

  /// Total the member paid in for shares **this cycle** (their savings basis).
  final int shareCents;

  /// The member's still-owed loan balance (principal + unpaid interest) that
  /// will be settled out of their payout.
  final int outstandingCents;

  final String memberId;
  final String memberName;
}

/// One member's computed payout.
class ShareOutLine {
  const ShareOutLine({
    required this.memberId,
    required this.memberName,
    required this.shareCents,
    required this.sharePercent,
    required this.grossPayoutCents,
    required this.welfareCents,
    required this.loanOffsetCents,
    required this.netPayoutCents,
  });

  final String memberId;
  final String memberName;
  final int shareCents;
  final double sharePercent; // 0..1 of the savings pool
  final int grossPayoutCents; // pro-rata slice of the savings pool
  final int welfareCents; // equal welfare share (0 when not distributed)
  final int loanOffsetCents; // outstanding loan netted off
  final int netPayoutCents; // grossPayout + welfare - loanOffset

  /// The member's profit: what they take home beyond what they paid in.
  int get returnCents => grossPayoutCents + welfareCents - shareCents;

  /// True when the member's debt exceeds their entitlement — they must pay the
  /// group the shortfall instead of receiving a payout.
  bool get owesGroup => netPayoutCents < 0;
}

/// The full result of a share-out run, with the figures needed to explain it.
class ShareOutResult {
  const ShareOutResult({
    required this.savingsPoolCents,
    required this.shareCapitalCents,
    required this.welfarePoolCents,
    required this.distributeWelfare,
    required this.totalOutstandingCents,
    required this.lines,
  });

  /// The distributable savings fund (share capital + interest/earnings).
  final int savingsPoolCents;

  /// Total members paid in for shares this cycle.
  final int shareCapitalCents;

  /// The welfare/social fund (social contributions + fines).
  final int welfarePoolCents;

  /// Whether the welfare fund was split equally among members.
  final bool distributeWelfare;

  /// Total still-owed loan balances netted off across all members.
  final int totalOutstandingCents;

  final List<ShareOutLine> lines;

  /// Group earnings this cycle — the pool beyond what members contributed.
  int get interestEarnedCents => savingsPoolCents - shareCapitalCents;

  /// Growth on contributed capital (e.g. 0.18 = 18% return), 0 when no capital.
  double get growthRate =>
      shareCapitalCents > 0 ? interestEarnedCents / shareCapitalCents : 0;

  /// Cash that actually leaves the box: the sum of net payouts. Equals
  /// (savings pool − outstanding) + (welfare distributed), i.e. exactly the
  /// cash the group holds. Members with a negative net pay the difference in.
  int get totalNetPaidCents =>
      lines.fold(0, (sum, l) => sum + l.netPayoutCents);

  int get welfareDistributedCents =>
      distributeWelfare ? welfarePoolCents : 0;

  /// Members whose debt exceeds their entitlement.
  Iterable<ShareOutLine> get membersOwing => lines.where((l) => l.owesGroup);

  /// Invariant: the gross payouts must sum to exactly the savings pool (no
  /// cents created or lost). True for any valid run.
  bool get isBalanced =>
      lines.fold(0, (s, l) => s + l.grossPayoutCents) == savingsPoolCents &&
      lines.fold(0, (s, l) => s + l.welfareCents) == welfareDistributedCents;
}

abstract final class ShareOutCalculator {
  /// Computes the share-out.
  ///
  /// - [savingsPoolCents]: the fund distributed pro-rata by shares (defaults,
  ///   set by the caller, to share capital + interest earned).
  /// - [shareCapitalCents]: total contributions, for the earnings figure.
  /// - [welfarePoolCents] + [distributeWelfare]: the social fund, optionally
  ///   split equally among members.
  static ShareOutResult compute({
    required List<ShareOutMember> members,
    required int savingsPoolCents,
    required int shareCapitalCents,
    required int welfarePoolCents,
    required bool distributeWelfare,
  }) {
    final shares = [for (final m in members) m.shareCents];
    final gross = _allocateProRata(savingsPoolCents, shares);
    final welfare = distributeWelfare
        ? _allocateEqually(welfarePoolCents, members.length)
        : List<int>.filled(members.length, 0);
    final totalShares = shares.fold(0, (a, b) => a + b);

    final lines = <ShareOutLine>[];
    var totalOutstanding = 0;
    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      final net = gross[i] + welfare[i] - m.outstandingCents;
      totalOutstanding += m.outstandingCents;
      lines.add(ShareOutLine(
        memberId: m.memberId,
        memberName: m.memberName,
        shareCents: m.shareCents,
        sharePercent: totalShares > 0 ? m.shareCents / totalShares : 0,
        grossPayoutCents: gross[i],
        welfareCents: welfare[i],
        loanOffsetCents: m.outstandingCents,
        netPayoutCents: net,
      ));
    }

    return ShareOutResult(
      savingsPoolCents: savingsPoolCents,
      shareCapitalCents: shareCapitalCents,
      welfarePoolCents: welfarePoolCents,
      distributeWelfare: distributeWelfare,
      totalOutstandingCents: totalOutstanding,
      lines: lines,
    );
  }

  /// Splits [total] across [weights] proportionally, allocating every last cent
  /// via the largest-remainder method. Returns a list that sums to exactly
  /// [total] (when the weights sum to > 0).
  static List<int> _allocateProRata(int total, List<int> weights) {
    final n = weights.length;
    if (n == 0) return const [];
    final weightSum = weights.fold(0, (a, b) => a + b);
    if (weightSum <= 0 || total <= 0) return List<int>.filled(n, 0);

    final base = List<int>.filled(n, 0);
    final remainders = List<double>.filled(n, 0);
    var allocated = 0;
    for (var i = 0; i < n; i++) {
      final exact = total * weights[i] / weightSum;
      base[i] = exact.floor();
      remainders[i] = exact - base[i];
      allocated += base[i];
    }
    // Hand the leftover cents to the largest fractional remainders (ties break
    // toward the larger weight, then the lower index — deterministic).
    var leftover = total - allocated;
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final r = remainders[b].compareTo(remainders[a]);
        if (r != 0) return r;
        final w = weights[b].compareTo(weights[a]);
        return w != 0 ? w : a.compareTo(b);
      });
    for (var k = 0; k < leftover; k++) {
      base[order[k]] += 1;
    }
    return base;
  }

  /// Splits [total] as evenly as possible across [n] members; the first
  /// `total % n` members get one extra cent.
  static List<int> _allocateEqually(int total, int n) {
    if (n <= 0) return const [];
    if (total <= 0) return List<int>.filled(n, 0);
    final base = total ~/ n;
    final extra = total % n;
    return [for (var i = 0; i < n; i++) base + (i < extra ? 1 : 0)];
  }
}
