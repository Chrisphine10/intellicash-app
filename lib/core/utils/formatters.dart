import 'package:intl/intl.dart';

/// Money and date formatting used across the app.
abstract final class Formatters {
  static final NumberFormat _money = NumberFormat('#,##0.00', 'en_KE');
  static final NumberFormat _moneyCompact = NumberFormat('#,##0', 'en_KE');
  static final DateFormat _fullDate = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  /// `KSh 6,600.00`
  static String money(double amount) => 'KSh ${_money.format(amount)}';

  /// `KSh 52,300` — for stat cards where cents add noise.
  static String moneyCompact(double amount) =>
      'KSh ${_moneyCompact.format(amount)}';

  /// `Sun, 12 Jul 2026`
  static String fullDate(DateTime date) => _fullDate.format(date);

  /// `12 Jul 2026`
  static String shortDate(DateTime date) => _shortDate.format(date);

  /// `2026-07-12`
  static String isoDate(DateTime date) => _isoDate.format(date);

  /// Two-letter initials for member avatars.
  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
