import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/formatters.dart';

void main() {
  group('Formatters.money', () {
    test('formats with thousands separators and cents', () {
      expect(Formatters.money(6600), 'KSh 6,600.00');
      expect(Formatters.money(52300.5), 'KSh 52,300.50');
      expect(Formatters.money(0), 'KSh 0.00');
    });

    test('compact form drops the cents', () {
      expect(Formatters.moneyCompact(52300), 'KSh 52,300');
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
