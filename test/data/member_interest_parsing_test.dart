import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/member_overview.dart';
import 'package:intellicash_mobile/data/models/remote/member_passbook.dart';

/// What a member is told they owe.
///
/// The server sends TWO outstanding figures: `loanOutstandingCents`, which is
/// only the ledger difference (disbursed minus repaid), and
/// `loanOutstandingWithInterestCents`, which is what the group will actually
/// collect. The app read the first one, so every screen and every printed
/// statement understated the debt by the whole of the interest.
///
/// Picking the wrong key is invisible to the analyzer and looks entirely
/// plausible on screen, which is why it is pinned here.
void main() {
  group('single-group passbook', () {
    Map<String, dynamic> passbook({bool withInterest = true}) => {
          'member': {'fullName': 'Rose Mwende', 'role': 'MEMBER'},
          'summary': {
            'sharesCents': 500000,
            'socialCents': 100000,
            'finesCents': 0,
            'totalPaidInCents': 600000,
            'loansReceivedCents': 1000000,
            'loansRepaidCents': 0,
            'loanOutstandingCents': 1000000,
            if (withInterest) ...{
              'loanOutstandingWithInterestCents': 1100000,
              'loanInterestCents': 100000,
            },
          },
          'attendance': {'present': 3, 'total': 4, 'rate': 0.75},
        };

    test('reports what is owed WITH interest', () {
      final book = MemberPassbook.fromJson(passbook());
      // 10,000 principal + 1,000 interest — not the 10,000 the ledger alone
      // would suggest.
      expect(book.loanOutstanding, 11000.0);
      expect(book.loanInterest, 1000.0);
    });

    test('the interest-aware figure is higher than the ledger difference', () {
      final book = MemberPassbook.fromJson(passbook());
      final ledgerOnly = book.loansReceived - book.loansRepaid;
      expect(book.loanOutstanding, greaterThan(ledgerOnly));
    });

    test('falls back to the old field against an older server', () {
      // A phone updated before the server must still show a number, and the
      // only honest one available is the ledger difference.
      final book = MemberPassbook.fromJson(passbook(withInterest: false));
      expect(book.loanOutstanding, 10000.0);
      expect(book.loanInterest, 0.0);
    });
  });

  group('combined across groups', () {
    Map<String, dynamic> overview(Map<String, dynamic> combined) => {
          'member': {'name': 'Rose Mwende'},
          'groups': const [],
          'combined': combined,
        };

    test('rolls up interest rather than dropping it', () {
      final o = MemberOverview.fromJson(overview({
        'sharesCents': 750000,
        'loansReceivedCents': 2000000,
        'loansRepaidCents': 0,
        'loanOutstandingCents': 2000000,
        'loanOutstandingWithInterestCents': 2200000,
        'loanInterestCents': 200000,
        'welfareReceivedCents': 45000,
        'shareOutReceivedCents': 320000,
      }));
      expect(o.loanOutstanding, 22000.0);
      expect(o.loanInterest, 2000.0);
    });

    test('surfaces money RECEIVED, not only money paid in', () {
      // Welfare and share-outs flow toward the member. A statement of
      // contributions alone leaves half their history out.
      final o = MemberOverview.fromJson(overview({
        'welfareReceivedCents': 45000,
        'shareOutReceivedCents': 320000,
      }));
      expect(o.welfareReceived, 450.0);
      expect(o.shareOutReceived, 3200.0);
    });

    test('falls back to the old field against an older server', () {
      final o = MemberOverview.fromJson(overview({
        'loanOutstandingCents': 2000000,
      }));
      expect(o.loanOutstanding, 20000.0);
    });

    test('a zero interest-aware total is used, not treated as missing', () {
      // Someone who has repaid everything owes zero. If a null-check were
      // written as a falsy-check, that zero would fall through to the legacy
      // field and report a debt they have already cleared.
      final o = MemberOverview.fromJson(overview({
        'loanOutstandingCents': 2000000,
        'loanOutstandingWithInterestCents': 0,
      }));
      expect(o.loanOutstanding, 0.0);
    });
  });
}
