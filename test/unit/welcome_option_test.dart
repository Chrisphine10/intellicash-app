import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/features/onboarding/welcome_screen.dart';

/// What each kind of account is offered on the welcome screen.
///
/// The rule being protected: **a personal account is never required to create a
/// group account.** Creating a group makes this handset a group's record book,
/// which is a decision about the phone, not a step in signing up. An account
/// that is not a group must never be told, implicitly or otherwise, that
/// setting one up is its way forward.
void main() {
  group('before anyone signs in', () {
    test('offers creating an account or signing in, and nothing else', () {
      expect(
        welcomeOptionFor(signedIn: false, role: null),
        WelcomeOption.createAccountOrSignIn,
      );
    });

    test('a stale role with no session still shows the sign-in door', () {
      // Signed out is signed out. The remembered role pre-fills a form; it
      // does not grant a destination.
      expect(
        welcomeOptionFor(signedIn: false, role: 'GROUP_ACCOUNT'),
        WelcomeOption.createAccountOrSignIn,
      );
    });
  });

  group('a personal account is never pushed into creating a group', () {
    test('a member goes to their own passbook', () {
      expect(
        welcomeOptionFor(signedIn: true, role: 'MEMBER'),
        WelcomeOption.memberHome,
      );
    });

    test('an agent goes to their own caseload', () {
      expect(
        welcomeOptionFor(signedIn: true, role: 'VILLAGE_AGENT'),
        WelcomeOption.agentHome,
      );
    });

    test('an admin is told to use the web console, not to create a group', () {
      // This is the case that was wrong: an admin signing in on a handset fell
      // through to the group-setup card, which was then the only thing on the
      // screen — a user account being made to create a group account before it
      // could do anything at all.
      expect(
        welcomeOptionFor(signedIn: true, role: 'IWL_ADMIN'),
        WelcomeOption.accountNotUsedOnThisApp,
      );
    });

    test('so are the other back-office roles', () {
      for (final role in ['PARTNER_OFFICER', 'LENDER', 'READ_ONLY']) {
        expect(
          welcomeOptionFor(signedIn: true, role: role),
          WelcomeOption.accountNotUsedOnThisApp,
          reason: '$role must not be offered group setup',
        );
      }
    });

    test('and so is a role this build has never heard of', () {
      // The backend gains roles over time. An old app meeting a new one must
      // fail closed: no record book, and no group-creation dead end either.
      for (final role in ['SOMETHING_NEW', '', 'member', 'group_account']) {
        expect(
          welcomeOptionFor(signedIn: true, role: role),
          WelcomeOption.accountNotUsedOnThisApp,
          reason: 'unrecognised role "$role" must fail closed',
        );
      }
    });

    test('a null role while signed in is not treated as a group', () {
      expect(
        welcomeOptionFor(signedIn: true, role: null),
        WelcomeOption.accountNotUsedOnThisApp,
      );
    });
  });

  group('only a group account sets up the record book', () {
    test('a signed-in group account is offered group setup', () {
      expect(
        welcomeOptionFor(signedIn: true, role: 'GROUP_ACCOUNT'),
        WelcomeOption.setUpGroup,
      );
    });

    test('exactly one role reaches group setup', () {
      // Stated as a whole so adding a role cannot quietly widen who can turn
      // this handset into a group's book.
      const everyRole = [
        'IWL_ADMIN',
        'PARTNER_OFFICER',
        'GROUP_ACCOUNT',
        'MEMBER',
        'LENDER',
        'VILLAGE_AGENT',
        'READ_ONLY',
      ];

      final canSetUpGroup = everyRole
          .where((role) =>
              welcomeOptionFor(signedIn: true, role: role) ==
              WelcomeOption.setUpGroup)
          .toList();

      expect(canSetUpGroup, ['GROUP_ACCOUNT']);
    });
  });
}
