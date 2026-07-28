import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// Owns the user's light/dark/system appearance preference.
///
/// [AppColors] is a set of plain static getters (not `Theme.of(context)`
/// consumers), so a screen already on-screen won't repaint just because this
/// notifies — [IntelliCashApp] re-keys its content on [mode] changes to force
/// a full rebuild, which is why switching appearance returns to the app's
/// root screen. "System" is resolved once, at [bootstrap] — this app doesn't
/// live-track OS theme changes mid-session, so an appearance change is always
/// a deliberate action from the Appearance setting, never a surprise reset.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'appearance_mode';

  ThemeMode _mode = ThemeMode.system;
  bool _ready = false;

  ThemeMode get mode => _mode;
  bool get ready => _ready;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    _mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _applyBrightness();
    _ready = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    _applyBrightness();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  void _applyBrightness() {
    final brightness = switch (_mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    AppColors.setMode(
      brightness == Brightness.light ? AppBrightness.light : AppBrightness.dark,
    );
  }
}
