import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/formatters.dart';

void main() {
  group('Formatters.money', () {
    test('formats with thousands separators and cents', () {
      expect(Formatters.money(6600), 'KSh 6,600.00');
      expect(Formatters.money(52300.5), 'KSh 52,300.50');
      expect(Formatters.money(0), 'KSh 0.00');
    });

    test('compact form drops the cents only when there are none', () {
      expect(Formatters.moneyCompact(52300), 'KSh 52,300');
      expect(Formatters.moneyCompact(0), 'KSh 0');
    });

    test('compact form never rounds real cents away', () {
      // A fine of 50.50 was shown on the dashboard as "KSh 51" while the
      // meeting summary said 50.50.
      expect(Formatters.moneyCompact(50.5), 'KSh 50.50');
      expect(Formatters.moneyCompact(2500.05), 'KSh 2,500.05');
      // Floating point noise around a whole amount is not cents.
      expect(Formatters.moneyCompact(1100.0000000001), 'KSh 1,100');
    });
  });

  group('Formatters.initials', () {
    test('takes first and last name initials', () {
      expect(Formatters.initials('Achieng Odhiambo'), 'AO');
      expect(Formatters.initials('Wanjiku  Kamau'), 'WK');
    });

    test('handles single names and blanks', () {
      expect(Formatters.initials('Neema'), 'NE');
      expect(Formatters.initials('  '), '?');
    });
  });
}
