import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/features/account/account_screen.dart';

/// The account screen is a pure widget over a value object, so it can be
/// rendered and inspected without a device — which is the whole reason it was
/// built that way. These tests pin the things a redesign is most likely to
/// break: that the destructive action is reachable and labelled, that optional
/// sections disappear cleanly rather than leaving empty cards, and that it fits
/// a small screen without overflowing.
void main() {
  const agent = AccountSummary(
    name: 'Grace Wanjiku',
    roleLabel: 'Village Agent',
    phone: '254720100102',
    email: 'demo.agent@intellicash.co.ke',
    scopeLabel: '12 groups in your caseload',
    serverLabel: 'intellicash.co.ke',
    appVersion: '2.4.0 (12)',
    languageLabel: 'English',
    themeLabel: 'Follow the phone',
  );

  Widget host(AccountSummary summary, {VoidCallback? onSignOut}) => MaterialApp(
        home: AccountScreen(
          summary: summary,
          onSignOut: onSignOut ?? () {},
          onLanguage: () {},
          onTheme: () {},
          onServer: () {},
        ),
      );

  testWidgets('shows who you are before anything else', (tester) async {
    await tester.pumpWidget(host(agent));
    expect(find.text('Grace Wanjiku'), findsOneWidget);
    expect(find.text('Village Agent'), findsOneWidget);
    expect(find.text('12 groups in your caseload'), findsOneWidget);
    // Initials, not an empty circle.
    expect(find.text('GW'), findsOneWidget);
  });

  testWidgets('sign out is labelled, not an anonymous icon', (tester) async {
    // A ListView builds only what is on screen, so the button below the fold
    // does not exist until the surface is tall enough to reach it.
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var signedOut = false;
    await tester.pumpWidget(host(agent, onSignOut: () => signedOut = true));

    // Found and tapped by its visible label, which is how a person reaches it.
    // (`widgetWithText(OutlinedButton, ...)` does not match: `.icon` wraps the
    // label in its own private subclass.)
    final button = find.text('Sign out');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(signedOut, isTrue);
  });

  testWidgets('drops sections it has no data for', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A member account with no email, no server override and no version should
    // not render empty cards where those rows would have been.
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          summary: const AccountSummary(name: 'Mary Njeri', roleLabel: 'Member'),
          onSignOut: () {},
        ),
      ),
    );
    // No headings over empty cards.
    expect(find.text('Contact details'), findsNothing);
    expect(find.text('This phone'), findsNothing);
    expect(find.text('Preferences'), findsNothing);
    // The one thing that must always be reachable.
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('falls back to a dash rather than an empty avatar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          summary: const AccountSummary(name: '   ', roleLabel: 'Member'),
          onSignOut: () {},
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('lays out on a 320x480 screen without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(agent));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
