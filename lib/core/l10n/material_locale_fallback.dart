import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter's bundled Material/Cupertino translations cover English and
/// Kiswahili, but not Gĩkũyũ, Dholuo or Kĩembu. Without this, selecting one
/// of those languages would assert at runtime ("no MaterialLocalizations
/// found"), because a supported locale must resolve those delegates.
///
/// These delegates claim the locales Flutter can't serve and hand back the
/// English built-ins, so system widgets (date pickers, tooltips, the "OK"
/// on a dialog) still read sensibly while our own strings use the chosen
/// language.
const _flutterServedLanguages = {'en', 'sw'};

bool _needsFallback(Locale locale) =>
    !_flutterServedLanguages.contains(locale.languageCode);

class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _needsFallback(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _needsFallback(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}

class FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _needsFallback(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(FallbackWidgetsLocalizationsDelegate old) => false;
}
