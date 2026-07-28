import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/member_overview.dart';
import 'package:intellicash_mobile/features/reports/member_pdf.dart';

Map<String, dynamic> _passbookJson({
  required String group,
  int shares = 500000,
  int social = 100000,
  int borrowed = 300000,
  int repaid = 100000,
  bool active = false,
}) =>
    {
      'member': {
        'id': 'm-$group',
        'fullName': 'Wanjiru Kamau',
        'group': {'id': 'g-$group', 'name': group, 'code': 'IWL-$group'}
      },
      'summary': {
        'sharesCents': shares,
        'socialCents': social,
        'finesCents': 0,
        'totalPaidInCents': shares + social,
        'loansReceivedCents': borrowed,
        'loansRepaidCents': repaid,
        'loanOutstandingCents':
            borrowed - repaid < 0 ? 0 : borrowed - repaid,
      },
      'attendance': {'present': 7, 'total': 9, 'rate': 0.78},
      'recentEntries': const [],
      'isActive': active,
    };

MemberOverview _overview() => MemberOverview.fromJson({
      'generatedAt': '2026-07-20T10:00:00.000Z',
      'member': {'name': 'Wanjiru Kamau', 'phone': '254722334455'},
      'combined': {
        'sharesCents': 750000,
        'socialCents': 100000,
        'finesCents': 0,
        'totalPaidInCents': 850000,
        'loansReceivedCents': 400000,
        'loansRepaidCents': 250000,
        'loanOutstandingCents': 200000,
      },
      'groups': [
        _passbookJson(group: 'Tujijenge', active: true),
        _passbookJson(
            group: 'Umoja',
            shares: 250000,
            social: 0,
            borrowed: 100000,
            repaid: 150000),
      ],
    });

void main() {
  group('MemberOverview parsing', () {
    test('turns cents into KES once', () {
      final o = _overview();
      expect(o.shares, 7500);
      expect(o.totalPaidIn, 8500);
      expect(o.loanOutstanding, 2000);
    });

    test('keeps each group separate and marks the one in view', () {
      final o = _overview();
      expect(o.groupCount, 2);
      expect(o.groups.map((g) => g.groupName), ['Tujijenge', 'Umoja']);
      expect(o.active?.groupName, 'Tujijenge');
    });

    test('an overpaying group shows nothing owed, not a negative', () {
      // Umoja borrowed 1,000 and repaid 1,500. That must read as zero owed —
      // and must not reduce what is owed in the other group.
      final o = _overview();
      final umoja = o.groups.firstWhere((g) => g.groupName == 'Umoja');
      expect(umoja.passbook.loanOutstanding, 0);
      expect(o.loanOutstanding, 2000);
    });

    test('survives a member with no groups at all', () {
      final o = MemberOverview.fromJson(const {});
      expect(o.groupCount, 0);
      expect(o.totalPaidIn, 0);
      expect(o.active, isNull);
    });
  });

  group('PDF builders', () {
    test('the combined report produces a real PDF document', () async {
      final bytes = await buildOverviewPdfBytes(_overview());
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(ascii.decode(bytes.skip(bytes.length - 32).toList()),
          contains('%%EOF'));
      expect(bytes.length, greaterThan(1000));
    });

    test('a single group statement produces a real PDF document', () async {
      final book = _overview().groups.first.passbook;
      final bytes = await buildPassbookPdfBytes(book);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('a member with one group still gets a valid report', () async {
      final one = MemberOverview.fromJson({
        'member': {'name': 'Solo Saver'},
        'combined': {
          'sharesCents': 100000,
          'totalPaidInCents': 100000,
          'loanOutstandingCents': 0,
        },
        'groups': [_passbookJson(group: 'OnlyGroup', active: true)],
      });
      final bytes = await buildOverviewPdfBytes(one);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('a member with no groups does not crash the builder', () async {
      // The screen hides the button in this case, but the builder must not be
      // the thing that decides that.
      final bytes = await buildOverviewPdfBytes(MemberOverview.fromJson(const {}));
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });
  });
}
