import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/remote/member_overview.dart';
import 'package:intellicash_mobile/data/models/remote/membership.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/features/member/join_group_screen.dart';
import 'package:intellicash_mobile/features/members/join_requests_screen.dart';
import 'package:intellicash_mobile/features/reports/my_savings_screen.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';
import '../support/localized_app.dart';

/// These screens had never been rendered — only their models and pure
/// functions were covered. Pumping them catches what unit tests cannot: a null
/// blowing up in `build`, a Column overflowing its box, a missing provider, or
/// an `AppColors` getter used inside a `const` widget.
///
/// A RenderFlex overflow raises a FlutterError during pump, so any of these
/// failing to lay out fails the test rather than passing silently.

class _FakeApi extends RemoteApi {
  _FakeApi({this.overview, this.requests = const []})
      : super(ApiClient(
          credentials: () => ApiCredentials(
            baseUrl: ApiConfig.defaultBaseUrl(),
            apiKey: '',
          ),
        ));

  final MemberOverview? overview;
  final List<JoinRequest> requests;

  @override
  Future<MemberOverview?> myOverview() async => overview;

  @override
  Future<List<JoinRequest>> joinRequests(String groupId, {bool all = false}) async =>
      requests;

  @override
  Future<Map<String, dynamic>> decideJoinRequest(
    String groupId,
    String requestId, {
    required bool approve,
    String? notes,
    String? confirmMemberId,
  }) async =>
      const {'matchedExistingMember': false};
}

ConnectionProvider _connection(RemoteApi api) => ConnectionProvider(
      store: CredentialStore(),
      api: api,
      applyCredentials: (_) {},
    );

Future<void> _pump(WidgetTester tester, RemoteApi api, Widget screen) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ConnectionProvider>.value(
      value: _connection(api),
      child: localizedApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _passbookJson(String group, {bool active = false}) => {
      'member': {
        'id': 'm-$group',
        'fullName': 'Wanjiru Kamau',
        'group': {'id': 'g-$group', 'name': group, 'code': 'IWL-$group'}
      },
      'summary': {
        'sharesCents': 500000,
        'socialCents': 100000,
        'finesCents': 0,
        'totalPaidInCents': 600000,
        'loansReceivedCents': 300000,
        'loansRepaidCents': 100000,
        'loanOutstandingCents': 200000,
      },
      'attendance': {'present': 7, 'total': 9, 'rate': 0.78},
      'recentEntries': const [],
      'isActive': active,
    };

MemberOverview _overviewWith(int groupCount) => MemberOverview.fromJson({
      'member': {'name': 'Wanjiru Kamau'},
      'combined': {
        'sharesCents': 500000 * groupCount,
        'socialCents': 100000 * groupCount,
        'finesCents': 0,
        'totalPaidInCents': 600000 * groupCount,
        'loansReceivedCents': 300000 * groupCount,
        'loansRepaidCents': 100000 * groupCount,
        'loanOutstandingCents': 200000 * groupCount,
      },
      'groups': [
        for (var i = 0; i < groupCount; i++)
          _passbookJson('Group${i + 1}', active: i == 0),
      ],
    });

void main() {
  group('My Savings (all groups)', () {
    testWidgets('renders a member who saves with two groups', (tester) async {
      await _pump(tester, _FakeApi(overview: _overviewWith(2)),
          const MySavingsScreen());

      expect(find.text('My Savings'), findsOneWidget);
      expect(find.text('Saving with 2 groups'), findsOneWidget);
      // SectionLabel upper-cases what it is given.
      expect(find.text('EVERYTHING TOGETHER'), findsOneWidget);
      expect(find.text('Viewing'), findsOneWidget);
      // The download stays pinned in the bottom bar, not scrolled away.
      expect(find.text('Download my report'), findsOneWidget);

      // Each group also appears on its own so the totals can be checked.
      // The second is below the fold on a small screen, so scroll to it —
      // which also proves the list scrolls rather than overflowing.
      expect(find.text('Group1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Group2'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Group2'), findsOneWidget);
    });

    testWidgets('explains that debt does not net off across groups',
        (tester) async {
      await _pump(tester, _FakeApi(overview: _overviewWith(2)),
          const MySavingsScreen());
      expect(
        find.textContaining('does not reduce what you owe in another'),
        findsOneWidget,
      );
    });

    testWidgets('drops the cross-group caveat for a single group',
        (tester) async {
      // With one group the warning would be noise.
      await _pump(tester, _FakeApi(overview: _overviewWith(1)),
          const MySavingsScreen());
      expect(find.text('Saving with 1 group'), findsOneWidget);
      expect(
        find.textContaining('does not reduce what you owe in another'),
        findsNothing,
      );
    });

    testWidgets('shows an invitation, not an error, when in no group yet',
        (tester) async {
      await _pump(tester, _FakeApi(overview: _overviewWith(0)),
          const MySavingsScreen());
      expect(find.text('No groups yet'), findsOneWidget);
      // Nothing to download, so the button is gone rather than dead.
      expect(find.text('Download my report'), findsNothing);
    });

    testWidgets('handles the server being unreachable', (tester) async {
      await _pump(tester, _FakeApi(overview: null), const MySavingsScreen());
      expect(find.textContaining('Could not load'), findsOneWidget);
    });
  });

  group('Join a group', () {
    testWidgets('states plainly that asking is not joining', (tester) async {
      await _pump(tester, _FakeApi(), const JoinGroupScreen());
      expect(find.text('Join a group'), findsOneWidget);
      expect(find.text('Group code'), findsOneWidget);
      expect(
        find.textContaining('an official has to accept you first'),
        findsOneWidget,
      );
    });

    testWidgets('refuses to send an empty code', (tester) async {
      await _pump(tester, _FakeApi(), const JoinGroupScreen());
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the group code first.'), findsOneWidget);
    });
  });

  group('renders on the phones members actually carry', () {
    /// A small, low-resolution Android handset, which is what most of this
    /// userbase has. Overflow shows up here long before it does on a tablet.
    Future<void> pumpSmall(WidgetTester tester, Widget screen,
        {Brightness brightness = Brightness.light}) async {
      tester.view.physicalSize = const Size(320 * 2, 480 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionProvider>.value(
          value: _connection(_FakeApi(overview: _overviewWith(3))),
          child: localizedApp(
            theme: ThemeData(brightness: brightness),
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('My Savings lays out on a 320x480 screen', (tester) async {
      // Three groups plus the combined block is the tallest this gets.
      await pumpSmall(tester, const MySavingsScreen());
      expect(find.text('Saving with 3 groups'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('My Savings lays out in dark mode', (tester) async {
      await pumpSmall(tester, const MySavingsScreen(),
          brightness: Brightness.dark);
      expect(find.text('My Savings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('My Savings survives a very long group name', (tester) async {
      // Group names are free text and people are generous with them.
      final long = MemberOverview.fromJson({
        'member': {'name': 'Wanjiru Kamau'},
        'combined': {'sharesCents': 100000, 'totalPaidInCents': 100000},
        'groups': [
          _passbookJson(
              'Tujijenge Women Empowerment and Savings Association of Kiambu County',
              active: true),
        ],
      });
      await _pump(tester, _FakeApi(overview: long), const MySavingsScreen());
      expect(tester.takeException(), isNull);
    });
  });

  group('Requests to join (officials)', () {
    JoinRequest request({String? linksTo}) => JoinRequest.fromJson({
          'id': 'req-1',
          'requestedName': 'Not Agnes',
          'phone': '254700000203',
          'status': 'PENDING',
          'createdAt': DateTime.now().toIso8601String(),
          'willLinkToMemberId': linksTo == null ? null : 'member-agnes',
          'willLinkToMemberName': linksTo,
        });

    testWidgets('renders someone waiting to be let in', (tester) async {
      await _pump(
        tester,
        _FakeApi(requests: [request()]),
        const JoinRequestsScreen(groupId: 'g-1'),
      );
      expect(find.text('Not Agnes'), findsOneWidget);
      expect(find.textContaining('254700000203'), findsOneWidget);
    });

    testWidgets('shows an empty queue without looking broken', (tester) async {
      await _pump(
        tester,
        _FakeApi(requests: const []),
        const JoinRequestsScreen(groupId: 'g-1'),
      );
      // The EmptyState, not a spinner or a blank screen.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders a request that would take over existing savings',
        (tester) async {
      // The riskiest row in the app: accepting hands over someone's passbook.
      await _pump(
        tester,
        _FakeApi(requests: [request(linksTo: 'Agnes Muthoni')]),
        const JoinRequestsScreen(groupId: 'g-1'),
      );
      expect(find.text('Not Agnes'), findsOneWidget);
    });
  });
}
