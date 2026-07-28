import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/l10n/material_locale_fallback.dart';
import 'package:intellicash_mobile/l10n/app_localizations.dart';
import 'package:intellicash_mobile/providers/locale_controller.dart';

/// Mirrors the delegate stack IntelliCashApp installs, so these tests fail
/// if the real wiring regresses.
Widget _appIn(Locale locale, {required Widget child}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      FallbackMaterialLocalizationsDelegate(),
      FallbackCupertinoLocalizationsDelegate(),
      FallbackWidgetsLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: child,
  );
}

/// Uses a Material widget that *requires* MaterialLocalizations (a back
/// button tooltip), which is exactly what crashes when a supported locale
/// has no Material translations.
Widget get _probe => Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(L10n.of(context).navMeetings),
        ),
        body: Text(L10n.of(context).appTagline),
      ),
    );

void main() {
  group('every shipped language renders', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.englishName} (${language.code})',
          (tester) async {
        await tester.pumpWidget(_appIn(language.locale, child: _probe));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${language.code} must resolve Material localizations');
        // MaterialLocalizations resolved — the back button has its tooltip.
        expect(find.byType(BackButton), findsOneWidget);
      });
    }
  });

  testWidgets('Kiswahili shows translated strings', (tester) async {
    await tester.pumpWidget(_appIn(const Locale('sw'), child: _probe));
    await tester.pumpAndSettle();
    expect(find.text('Mikutano'), findsOneWidget);
    expect(find.text('VSLA yako mfukoni mwako'), findsOneWidget);
  });

  testWidgets('a partly translated language falls back to English',
      (tester) async {
    await tester.pumpWidget(_appIn(const Locale('luo'), child: _probe));
    await tester.pumpAndSettle();
    // Translated key uses Dholuo…
    expect(find.text('Chokruoge'), findsOneWidget);
    // …while an untranslated one falls back to the English template rather
    // than rendering blank.
    expect(find.text('Your VSLA in your pocket'), findsOneWidget);
  });

  test('language metadata lines up with the backend enum', () {
    expect(AppLanguage.fromBackendValue('KISWAHILI'), AppLanguage.kiswahili);
    expect(AppLanguage.fromCode('luo'), AppLanguage.dholuo);
    // Unknown values degrade to English rather than throwing.
    expect(AppLanguage.fromBackendValue('KLINGON'), AppLanguage.english);
    expect(AppLanguage.fromCode(null), AppLanguage.english);
    // Only the two complete translations claim completeness.
    expect(
      AppLanguage.values.where((l) => l.complete).toSet(),
      {AppLanguage.english, AppLanguage.kiswahili},
    );
  });
}
