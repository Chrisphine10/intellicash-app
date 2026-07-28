import 'package:shared_preferences/shared_preferences.dart';

/// Small app-level switches (not group rules), stored in SharedPreferences.
abstract final class AppSettings {
  static const _kMemberAccounts = 'allow_member_accounts';

  /// Whether this group offers its members their own sign-in accounts.
  /// Off by default — it's optional, switched on from the More screen.
  static Future<bool> memberAccountsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMemberAccounts) ?? false;
  }

  static Future<void> setMemberAccountsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMemberAccounts, value);
  }
}
