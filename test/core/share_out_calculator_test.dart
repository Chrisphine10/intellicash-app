import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/share_out_calculator.dart';

ShareOutMember m(String id, int shares, {int outstanding = 0}) =>
    ShareOutMember(
        memberId: id,
        memberName: id,
        shareCents: shares,
        outstandingCents: outstanding);

void main() {
  group('ShareOutCalculator pro-rata', () {
    test('distributes the pool in proportion to shares', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 60000), m('B', 40000)],
        savingsPoolCents: 100000,
        shareCapitalCents: 100000,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      expect(r.lines[0].grossPayoutCents, 60000);
      expect(r.lines[1].grossPayoutCents, 40000);
      expect(r.lines[0].sharePercent, closeTo(0.6, 1e-9));
      expect(r.isBalanced, isTrue);
    });

    test('allocates every cent via largest remainder (no cents lost)', () {
      // KSh 1.00 across three equal members -> 34/33/33, sums to 100.
      final r = ShareOutCalculator.compute(
        members: [m('A', 100), m('B', 100), m('C', 100)],
        savingsPoolCents: 100,
        shareCapitalCents: 300,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      final payouts = r.lines.map((l) => l.grossPayoutCents).toList();
      expect(payouts.reduce((a, b) => a + b), 100);
      expect(payouts, containsAll([34, 33, 33]));
      expect(r.isBalanced, isTrue);
    });

    test('largest remainder favours the larger fractional part', () {
      // pool 10 cents; shares 1,1,8 -> exact 0.83, 0.83, 8.33
      // floors 0,0,8 = 8; leftover 2 goes to the two largest remainders (the
      // 0.83s), not the 0.33.
      final r = ShareOutCalculator.compute(
        members: [m('A', 1), m('B', 1), m('C', 8)],
        savingsPoolCents: 10,
        shareCapitalCents: 10,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      expect(r.lines[0].grossPayoutCents, 1);
      expect(r.lines[1].grossPayoutCents, 1);
      expect(r.lines[2].grossPayoutCents, 8);
      expect(r.isBalanced, isTrue);
    });

    test('a bigger, uneven pool still sums exactly to the pool', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 12345), m('B', 67890), m('C', 1), m('D', 999)],
        savingsPoolCents: 500000,
        shareCapitalCents: 81235,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      expect(r.lines.fold(0, (s, l) => s + l.grossPayoutCents), 500000);
      expect(r.isBalanced, isTrue);
    });
  });

  group('ShareOutCalculator earnings', () {
    test('reports interest earned and growth rate', () {
      // Members put in 100000; pool is 118000 -> 18000 interest, 18% growth.
      final r = ShareOutCalculator.compute(
        members: [m('A', 50000), m('B', 50000)],
        savingsPoolCents: 118000,
        shareCapitalCents: 100000,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      expect(r.interestEarnedCents, 18000);
      expect(r.growthRate, closeTo(0.18, 1e-9));
      // Each contributed 50000 and takes home 59000 -> 9000 profit each.
      expect(r.lines[0].returnCents, 9000);
      expect(r.lines[1].returnCents, 9000);
    });
  });

  group('ShareOutCalculator loan netting', () {
    test('nets outstanding loans off the payout', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 50000, outstanding: 20000), m('B', 50000)],
        savingsPoolCents: 100000,
        shareCapitalCents: 100000,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      // A: gross 50000 - 20000 debt = 30000 net.
      expect(r.lines[0].grossPayoutCents, 50000);
      expect(r.lines[0].loanOffsetCents, 20000);
      expect(r.lines[0].netPayoutCents, 30000);
      expect(r.lines[0].owesGroup, isFalse);
      expect(r.totalOutstandingCents, 20000);
    });

    test('flags a member whose debt exceeds their entitlement', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 10000, outstanding: 40000), m('B', 90000)],
        savingsPoolCents: 100000,
        shareCapitalCents: 100000,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      // A: gross 10000 - 40000 = -30000 -> owes the group 30000.
      expect(r.lines[0].netPayoutCents, -30000);
      expect(r.lines[0].owesGroup, isTrue);
      expect(r.membersOwing.map((l) => l.memberId), ['A']);
    });

    test('conservation: net cash out = pool - outstanding (+ welfare)', () {
      final r = ShareOutCalculator.compute(
        members: [
          m('A', 50000, outstanding: 12000),
          m('B', 30000),
          m('C', 20000, outstanding: 5000),
        ],
        savingsPoolCents: 130000, // 100000 capital + 30000 interest
        shareCapitalCents: 100000,
        welfarePoolCents: 9000,
        distributeWelfare: true,
      );
      // net total = savingsPool (130000) + welfare (9000) - outstanding (17000)
      expect(r.totalNetPaidCents, 130000 + 9000 - 17000);
      expect(r.isBalanced, isTrue);
    });
  });

  group('ShareOutCalculator welfare', () {
    test('splits welfare equally when asked', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 70000), m('B', 30000), m('C', 0)],
        savingsPoolCents: 100000,
        shareCapitalCents: 100000,
        welfarePoolCents: 300, // KSh 3.00 across 3 members = 100 each
        distributeWelfare: true,
      );
      expect(r.lines.map((l) => l.welfareCents), everyElement(100));
      // C contributed nothing but still receives an equal welfare share.
      expect(r.lines[2].welfareCents, 100);
      expect(r.lines[2].grossPayoutCents, 0);
      expect(r.lines[2].netPayoutCents, 100);
      expect(r.isBalanced, isTrue);
    });

    test('welfare uneven split allocates every cent', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 1), m('B', 1), m('C', 1)],
        savingsPoolCents: 3,
        shareCapitalCents: 3,
        welfarePoolCents: 100, // 100 / 3 = 34,33,33
        distributeWelfare: true,
      );
      expect(r.lines.map((l) => l.welfareCents).reduce((a, b) => a + b), 100);
      expect(r.welfareDistributedCents, 100);
    });

    test('welfare retained (not distributed) leaves payouts untouched', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 50000), m('B', 50000)],
        savingsPoolCents: 100000,
        shareCapitalCents: 100000,
        welfarePoolCents: 50000,
        distributeWelfare: false,
      );
      expect(r.lines.every((l) => l.welfareCents == 0), isTrue);
      expect(r.welfareDistributedCents, 0);
    });
  });

  group('ShareOutCalculator edge cases', () {
    test('no contributions yields zero gross payouts gracefully', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 0), m('B', 0)],
        savingsPoolCents: 0,
        shareCapitalCents: 0,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      expect(r.lines.every((l) => l.grossPayoutCents == 0), isTrue);
      expect(r.growthRate, 0);
    });

    test('single member takes the whole pool', () {
      final r = ShareOutCalculator.compute(
        members: [m('A', 12345)],
        savingsPoolCents: 99999,
        shareCapitalCents: 12345,
        welfarePoolCents: 0,
        distributeWelfare: false,
      );
      expect(r.lines.single.grossPayoutCents, 99999);
      expect(r.isBalanced, isTrue);
    });
  });
}
