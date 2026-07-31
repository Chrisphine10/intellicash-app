import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/services/remote_governance_api.dart';

/// Parsing tests, not plumbing tests.
///
/// `flutter analyze` cannot see inside a JSON key string, so a mistyped field
/// name compiles cleanly and shows up as a silent zero on screen. For welfare
/// that is the worst possible failure: a balance of 0 reads as "nothing left
/// to share", and a spent figure of 0 reads as "we can still spend it".
///
/// The payload below is shaped exactly like the API's response — the amount
/// lives on `ledgerEntry`, NOT on the expense row.
void main() {
  Map<String, dynamic> payload() => {
        'group': {'id': 'g1', 'name': 'Umoja', 'code': 'UMJ'},
        'expenses': [
          {
            'id': 'we_1',
            'category': 'MEDICAL',
            'payeeName': 'Kisumu County Hospital',
            'note': 'Maternity bill',
            'createdAt': '2026-07-20T10:00:00.000Z',
            'ledgerEntry': {
              'amountCents': 450000,
              'createdAt': '2026-07-20T10:00:00.000Z',
            },
          },
          {
            'id': 'we_2',
            'category': 'BEREAVEMENT',
            'payeeMember': {'id': 'm3', 'fullName': 'Rose Mwende'},
            'ledgerEntry': {
              'amountCents': 200000,
              'createdAt': '2026-07-22T10:00:00.000Z',
            },
          },
        ],
        'spentCents': 650000,
        'welfareBalanceCents': 350000,
      };

  test('reads the amount off the ledger entry, not the expense row', () {
    final welfare = RemoteWelfare.fromJson(payload());
    expect(welfare.expenses.first.amountCents, 450000);
  });

  test('balance and spent are read from the fields the API actually sends', () {
    // welfareBalanceCents, not "balanceCents" — the names differ on purpose and
    // a wrong guess here silently reports zero.
    final welfare = RemoteWelfare.fromJson(payload());
    expect(welfare.balanceCents, 350000);
    expect(welfare.spentCents, 650000);
  });

  test('a payee who IS a member is named from payeeMember', () {
    // Welfare paid to a member arrives with no payeeName at all; falling back
    // to the joined member is what stops the row reading "Payee not recorded".
    final welfare = RemoteWelfare.fromJson(payload());
    expect(welfare.expenses[1].payeeName, 'Rose Mwende');
  });

  test('a payee who is NOT a member keeps the free-text name', () {
    final welfare = RemoteWelfare.fromJson(payload());
    expect(welfare.expenses.first.payeeName, 'Kisumu County Hospital');
  });

  test('an empty fund parses as zero rather than throwing', () {
    // A group that has never spent welfare still has to open the screen.
    final welfare = RemoteWelfare.fromJson({
      'expenses': const [],
      'spentCents': 0,
      'welfareBalanceCents': 0,
    });
    expect(welfare.expenses, isEmpty);
    expect(welfare.balanceCents, 0);
  });

  test('missing fields do not crash the screen', () {
    // Older servers, or a partial response, must degrade to zero — not throw
    // and leave an official staring at a red screen mid-meeting.
    final welfare = RemoteWelfare.fromJson({
      'expenses': [
        {'id': 'we_3', 'category': 'OTHER', 'ledgerEntry': const {}},
      ],
    });
    expect(welfare.expenses.first.amountCents, 0);
    expect(welfare.expenses.first.payeeName, isNull);
    expect(welfare.balanceCents, 0);
  });
}
