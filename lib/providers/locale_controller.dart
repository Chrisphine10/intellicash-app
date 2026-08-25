import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How far a translation has got.
///
/// Two axes were being confused by a single `complete` flag: whether every
/// string HAS a translation, and whether a speaker of the language has ever
/// looked at it. They are not the same, and the second is the one a group in
/// Embu actually cares about.
enum TranslationState {
  /// Every string translated, and the wording is trusted.
  ready,

  /// Every string translated, but no native speaker has reviewed it yet.
  /// Nothing falls back to English any more — the risk is a word that is
  /// grammatical but wrong, which is worse than a gap because it does not
  /// announce itself.
  draft,
}

/// The languages Intelli-Cash ships. Codes match the backend's
/// `languagePreferences` list so a signed-in account's choice lines up.
enum AppLanguage {
  english('en', 'English', 'English', 'ENGLISH', state: TranslationState.ready),
  kiswahili('sw', 'Kiswahili', 'Swahili', 'KISWAHILI',
      state: TranslationState.ready),
  gikuyu('ki', 'Gĩkũyũ', 'Kikuyu', 'GIKUYU'),
  dholuo('luo', 'Dholuo', 'Luo', 'LUO'),
  kiembu('ebu', 'Kĩembu', 'Embu', 'KIEMBU');

  const AppLanguage(
    this.code,
    this.nativeName,
    this.englishName,
    this.backendValue, {
    this.state = TranslationState.draft,
  });

  /// Locale code, matching the `app_<code>.arb` file.
  final String code;

  /// The language's own name — what a speaker recognises in a picker.
  final String nativeName;
  final String englishName;

  /// The backend `languagePreference` enum value.
  final String backendValue;

  /// How far this translation has got. The picker shows it, rather than
  /// letting a language look finished because every screen has words on it.
  final TranslationState state;

  /// True only when a speaker of the language has signed the wording off.
  bool get isReviewed => state == TranslationState.ready;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.english,
      );

  static AppLanguage fromBackendValue(String? value) => values.firstWhere(
        (l) => l.backendValue == value,
        orElse: () => AppLanguage.english,
      );
}

/// Owns the app's language. Persisted on this phone, so a group that picks
/// Kiswahili keeps it offline and across restarts.
///
/// Unlike appearance, a language change does not need the whole app re-keyed:
/// strings are read through `L10n.of(context)`, so notifying rebuilds every
/// screen that depends on it.
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_language';

  AppLanguage _language = AppLanguage.english;
  bool _ready = false;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  bool get ready => _ready;

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = AppLanguage.fromCode(prefs.getString(_prefsKey));
    } catch (_) {
      // No prefs available (fresh test env) — English is a safe default.
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.code);
  }

  /// Adopts the language stored on a signed-in account, unless this phone
  /// has already been set deliberately.
  Future<void> adoptAccountPreference(String? backendValue) async {
    if (backendValue == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefsKey) != null) return;
    await setLanguage(AppLanguage.fromBackendValue(backendValue));
  }
}
