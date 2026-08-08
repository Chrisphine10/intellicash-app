import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/app.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/providers/app_state.dart';

/// Member, field agent and group account are three separate products. These
/// tests pin that separation to the one place that decides it.
///
/// The bug these were written against: the root chose by AppStatus alone, and
/// AppStatus only ever meant "does a group's book exist on this phone". So any
/// phone with a group on it returned the group shell to everyone. A member who
/// signed in there got their passbook once — pushed on top — and then landed
/// in the group's record book on the very next launch, seeing every member's
/// savings, loans and meeting PINs. Signing out changed nothing at the root
/// either, because nobody being signed in was not a state it could express.

const _member = StoredAccount(
  role: 'MEMBER',
  name: 'Naomi Wairimu',
  identifier: '254720100101',
);
const _agent = StoredAccount(
  role: 'VILLAGE_AGENT',
  name: 'Field Agent',
  identifier: '254720100102',
);
const _group = StoredAccount(
  role: 'GROUP_ACCOUNT',
  name: 'Demo Group Account',
  identifier: '254720100100',
);

RootDestination destinationFor({
  required AppStatus status,
  required StoredAccount? account,
  bool themeReady = true,
  bool localeReady = true,
  bool sessionReady = true,
  bool hasSignedInBefore = false,
}) =>
    rootDestinationFor(
      themeReady: themeReady,
      localeReady: localeReady,
      sessionReady: sessionReady,
      status: status,
      account: account,
      hasSignedInBefore: hasSignedInBefore,
    );

void main() {
  group('a member is never given the group app', () {
    test('goes to their passbook even when this phone holds a group book', () {
      expect(
        destinationFor(status: AppStatus.ready, account: _member),
        RootDestination.memberPassbook,
      );
    });

    test('needs no group of their own to use the app', () {
      // The point of a member account: sign in, see your savings. No group
      // setup wizard, no group to create first.
      expect(
        destinationFor(status: AppStatus.needsSetup, account: _member),
        RootDestination.memberPassbook,
      );
    });
  });

  group('a field agent is never given the group app', () {
    test('goes to their caseload even when this phone holds a group book', () {
      expect(
        destinationFor(status: AppStatus.ready, account: _agent),
        RootDestination.agentHome,
      );
    });

    test('needs no group of their own', () {
      expect(
        destinationFor(status: AppStatus.needsSetup, account: _agent),
        RootDestination.agentHome,
      );
    });
  });

  group('the group record book belongs to the group account', () {
    test('opens once a group has been set up on this phone', () {
      expect(
        destinationFor(status: AppStatus.ready, account: _group),
        RootDestination.groupShell,
      );
    });

    test('offers setup when this phone has no group yet', () {
      expect(
        destinationFor(status: AppStatus.needsSetup, account: _group),
        RootDestination.welcome,
      );
    });
  });

  group('signed out', () {
    test('the group book does not open, even though it is still on disk', () {
      // The regression that started this: sign out used to leave the whole
      // group app running underneath a pushed login screen.
      expect(
        destinationFor(status: AppStatus.ready, account: null),
        RootDestination.welcome,
      );
    });

    test('a phone with no group shows the welcome screen', () {
      expect(
        destinationFor(status: AppStatus.needsSetup, account: null),
        RootDestination.welcome,
      );
    });

    test('asks which kind of account is signing in', () {
      // Signing out of the group account is how a treasurer switches to their
      // own member account on the same handset. Sending them back to the
      // account they just left would make that impossible.
      expect(
        destinationFor(
          status: AppStatus.ready,
          account: null,
          hasSignedInBefore: true,
        ),
        RootDestination.chooseAccount,
      );
      expect(
        destinationFor(
          status: AppStatus.needsSetup,
          account: null,
          hasSignedInBefore: true,
        ),
        RootDestination.chooseAccount,
      );
    });

    test('a brand new phone is offered account creation instead', () {
      expect(
        destinationFor(
          status: AppStatus.needsSetup,
          account: null,
          hasSignedInBefore: false,
        ),
        RootDestination.welcome,
      );
    });
  });

  group('nothing is decided before the app knows who is signed in', () {
    test('waits while the stored session is still being restored', () {
      // Routing before this point would flash the group shell at a member.
      expect(
        destinationFor(
          status: AppStatus.ready,
          account: null,
          sessionReady: false,
        ),
        RootDestination.splash,
      );
    });

    test('waits while the local group is still being read', () {
      expect(
        destinationFor(status: AppStatus.loading, account: _group),
        RootDestination.splash,
      );
    });

    test('waits for theme and locale', () {
      expect(
        destinationFor(
          status: AppStatus.ready,
          account: _group,
          themeReady: false,
        ),
        RootDestination.splash,
      );
      expect(
        destinationFor(
          status: AppStatus.ready,
          account: _group,
          localeReady: false,
        ),
        RootDestination.splash,
      );
    });
  });

  group('role comes from the backend, not from a guess', () {
    test('an unrecognised role is not handed the group book', () {
      // A role this build has never heard of must not fall through to the
      // record book. Only GROUP_ACCOUNT opens it.
      const unknown = StoredAccount(
        role: 'SOMETHING_NEW',
        name: 'Future Role',
        identifier: '254700000000',
      );
      expect(
        destinationFor(status: AppStatus.ready, account: unknown),
        isNot(RootDestination.groupShell),
      );
    });
  });
}
