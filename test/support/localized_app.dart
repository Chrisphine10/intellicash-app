import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intellicash_mobile/core/l10n/material_locale_fallback.dart';
import 'package:intellicash_mobile/l10n/app_localizations.dart';

/// A `MaterialApp` carrying the same localisation delegates the real app
/// installs.
///
/// Every widget test used to pump a bare `MaterialApp(home: screen)`. That
/// worked only for as long as the screens contained English literals; the
/// moment a screen reads `L10n.of(context)` — which is now nearly all of
/// them — a bare MaterialApp throws "Null check operator used on a null
/// value" from inside `L10n.of`, and the failure points at the screen rather
/// than at the harness that is actually missing something.
///
/// Tests build through here so a screen is exercised the way it ships. Passing
/// a [locale] also makes a test able to assert on translated copy, which is
/// the only way a translation can be checked automatically at all.
MaterialApp localizedApp({
  required Widget home,
  ThemeData? theme,
  Locale? locale,
}) {
  return MaterialApp(
    theme: theme,
    locale: locale,
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      // Kikuyu, Dholuo and Kiembu have no Material translations upstream, so
      // these stand in. Without them a supported locale crashes on the first
      // widget that wants a back-button tooltip.
      FallbackMaterialLocalizationsDelegate(),
      FallbackCupertinoLocalizationsDelegate(),
      FallbackWidgetsLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: home,
  );
}
