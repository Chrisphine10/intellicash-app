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

  testWidgets('Dholuo no longer falls back to English', (tester) async {
    // It used to: 12 of 420 strings were translated and the rest showed in
    // English. Both of these are now Dholuo, which is the whole point.
    await tester.pumpWidget(_appIn(const Locale('luo'), child: _probe));
    await tester.pumpAndSettle();
    expect(find.text('Chokruoge'), findsOneWidget);
    expect(find.text('Your VSLA in your pocket'), findsNothing);
  });

  testWidgets('a real screen renders in Kiswahili, not just the nav labels',
      (tester) async {
    // The picker was always convincing; the screens were not. This asserts
    // translated copy from three different parts of the app at once, so a
    // regression that empties one ARB section cannot hide behind another.
    await tester.pumpWidget(
      _appIn(
        const Locale('sw'),
        child: Builder(
          builder: (context) {
            final l10n = L10n.of(context);
            return Scaffold(
              body: Column(
                children: [
                  Text(l10n.meetingHubBuyShares),
                  Text(l10n.dashboardTotalSavings),
                  Text(l10n.memberPassbookMyPassbook),
                  Text(l10n.joinRequestsApprove),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nunua Hisa'), findsOneWidget);
    expect(find.text('Jumla ya Akiba'), findsOneWidget);
    expect(find.text('Kitabu Changu'), findsOneWidget);
    expect(find.text('Kubali'), findsOneWidget);
  });

  testWidgets('a sentence with a number keeps the number where it belongs',
      (tester) async {
    // Parameterised messages are the reason sentences are not glued together
    // from fragments: the translator decides where the value sits in their
    // own word order.
    await tester.pumpWidget(
      _appIn(
        const Locale('sw'),
        child: Builder(
          builder: (context) =>
              Scaffold(body: Text(L10n.of(context).unlockOpensWhen(3, 5))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3'), findsOneWidget);
    expect(find.textContaining('viongozi'), findsOneWidget);
  });

  test('language metadata lines up with the backend enum', () {
    expect(AppLanguage.fromBackendValue('KISWAHILI'), AppLanguage.kiswahili);
    expect(AppLanguage.fromCode('luo'), AppLanguage.dholuo);
    // Unknown values degrade to English rather than throwing.
    expect(AppLanguage.fromBackendValue('KLINGON'), AppLanguage.english);
    expect(AppLanguage.fromCode(null), AppLanguage.english);
    // Every language is fully translated; only two have been read by someone
    // who speaks them, and only those two may claim it.
    expect(
      AppLanguage.values.where((l) => l.isReviewed).toSet(),
      {AppLanguage.english, AppLanguage.kiswahili},
    );
  });
}
