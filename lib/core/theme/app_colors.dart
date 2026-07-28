import 'package:flutter/material.dart';

/// Which palette [AppColors] currently resolves to. Flipped by
/// `ThemeController`. Every `AppColors.xxx` member is a **getter**, not a
/// `const`, so it always reflects the live mode — which also means call
/// sites that build a widget with `const` using an `AppColors.xxx` value
/// won't compile; drop the `const` there (the widget must rebuild on a
/// theme change anyway).
enum AppBrightness { light, dark }

/// Intelli-Cash design tokens.
///
/// One brand voice (the mint green) and one status vocabulary (repaid/
/// defaulted/pending) across two grounds — dark (default) and light —
/// selected by [setMode]. Status colors are reserved for loan/sync states
/// and never reused as decoration, in either mode.
abstract final class AppColors {
  static AppBrightness _mode = AppBrightness.dark;

  /// Swaps every `AppColors.xxx` getter to the given palette. Callers must
  /// also trigger a widget rebuild (see `ThemeController`) — this alone does
  /// not repaint anything.
  static void setMode(AppBrightness mode) => _mode = mode;

  static bool get isLight => _mode == AppBrightness.light;

  // Grounds
  static Color get background => isLight ? _Light.background : _Dark.background;
  static Color get surface => isLight ? _Light.surface : _Dark.surface;
  static Color get surfaceRaised =>
      isLight ? _Light.surfaceRaised : _Dark.surfaceRaised;
  static Color get outline => isLight ? _Light.outline : _Dark.outline;
  static Color get navBackground =>
      isLight ? _Light.navBackground : _Dark.navBackground;

  // Brand
  static Color get primary => isLight ? _Light.primary : _Dark.primary;
  static Color get onPrimary => isLight ? _Light.onPrimary : _Dark.onPrimary;
  static Color get primaryTint =>
      isLight ? _Light.primaryTint : _Dark.primaryTint;

  // Ink
  static Color get textPrimary =>
      isLight ? _Light.textPrimary : _Dark.textPrimary;
  static Color get textSecondary =>
      isLight ? _Light.textSecondary : _Dark.textSecondary;

  // Status — loans & sync
  static Color get repaid => isLight ? _Light.repaid : _Dark.repaid;
  static Color get repaidTint => isLight ? _Light.repaidTint : _Dark.repaidTint;
  static Color get defaulted => isLight ? _Light.defaulted : _Dark.defaulted;
  static Color get defaultedTint =>
      isLight ? _Light.defaultedTint : _Dark.defaultedTint;
  static Color get pending => isLight ? _Light.pending : _Dark.pending;
  static Color get pendingTint =>
      isLight ? _Light.pendingTint : _Dark.pendingTint;
}

/// The original dark palette — unchanged from the published design spec.
abstract final class _Dark {
  static const Color background = Color(0xFF0E1113);
  static const Color surface = Color(0xFF1B2126);
  static const Color surfaceRaised = Color(0xFF232A30);
  static const Color outline = Color(0xFF2C343B);
  static const Color navBackground = Color(0xFF101519);

  static const Color primary = Color(0xFF3DDC7E);
  static const Color onPrimary = Color(0xFF08301B);
  static const Color primaryTint = Color(0x223DDC7E);

  static const Color textPrimary = Color(0xFFF2F5F6);
  static const Color textSecondary = Color(0xFF8C99A2);

  static const Color repaid = Color(0xFF8AB4F8);
  static const Color repaidTint = Color(0x228AB4F8);
  static const Color defaulted = Color(0xFFF28B82);
  static const Color defaultedTint = Color(0x22F28B82);
  static const Color pending = Color(0xFFFDD663);
  static const Color pendingTint = Color(0x22FDD663);
}

/// The light palette — mirrors the dark ground's layering (background is
/// the least emphasized surface, `surfaceRaised` the most) and deepens every
/// hue that was tuned for a dark backdrop so it keeps AA-ish contrast on
/// white when used as text or an icon, not just as a tinted fill.
abstract final class _Light {
  static const Color background = Color(0xFFF2F4F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFEAEEF0);
  static const Color outline = Color(0xFFDBE1E4);
  static const Color navBackground = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF1E9E56);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryTint = Color(0x221E9E56);

  static const Color textPrimary = Color(0xFF15191B);
  static const Color textSecondary = Color(0xFF5C6B73);

  static const Color repaid = Color(0xFF3B6FD1);
  static const Color repaidTint = Color(0x223B6FD1);
  static const Color defaulted = Color(0xFFD93B30);
  static const Color defaultedTint = Color(0x22D93B30);
  static const Color pending = Color(0xFFB8860B);
  static const Color pendingTint = Color(0x22B8860B);
}
