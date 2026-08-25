import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/remote/credit_rating.dart';
import 'package:intellicash_mobile/data/models/remote/group_report.dart';
import 'package:intellicash_mobile/data/models/remote/member_passbook.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/features/agent/agent_group_detail_screen.dart';
import 'package:intellicash_mobile/features/reports/member_report_screen.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';
import '../support/localized_app.dart';

/// Renders the two screens the earlier pass could not reach: the agent's
/// financial panel and the member report with its download button.
///
/// Both need a signed-in connection with cached group data, so the fake below
/// overrides the getters those screens read rather than driving real network
/// and database calls.

class _FakeApi extends RemoteApi {
  _FakeApi({this.rating, this.report, this.passbook})
      : super(ApiClient(
          credentials: () => ApiCredentials(
            baseUrl: ApiConfig.defaultBaseUrl(),
            apiKey: '',
          ),
        ));

  final RemoteCreditRating? rating;
  final GroupReport? report;
  final MemberPassbook? passbook;

  @override
  Future<RemoteCreditRating> creditRating(String groupId) async {
    final r = rating;
    if (r == null) throw Exception('no rating');
    return r;
  }

  @override
  Future<GroupReport?> groupReport(String groupId) async => report;

  @override
  Future<MemberPassbook?> myPassbook() async => passbook;

  @override
  Future<List<Map<String, dynamic>>> ledger(String groupId) async => const [];
}

class _FakeConnection extends ConnectionProvider {
  _FakeConnection({
    required super.store,
    required super.api,
    required super.applyCredentials,
    this.fakeMembers = const [],
    this.fakeMeetings = const [],
    this.fakeGroup,
    this.fakeUser,
  });

  final List<RemoteMember> fakeMembers;
  final List<RemoteMeeting> fakeMeetings;
  final RemoteGroup? fakeGroup;
  final RemoteUser? fakeUser;

  @override
  List<RemoteMember> get members => fakeMembers;
  @override
  List<RemoteMeeting> get meetings => fakeMeetings;
  @override
  RemoteGroup? get selectedGroup => fakeGroup;
  @override
  RemoteUser? get signedInUser => fakeUser;
  @override
  bool get hasSession => fakeUser != null;
}

RemoteGroup _group({String name = 'Tujijenge Women VSLA'}) => RemoteGroup(
      id: 'g-1',
      name: name,
      code: 'IWL-KBU-0001',
      phase: 'ACTIVE',
      county: 'Kiambu',
      shareValue: 200,
      maxSharesPerMeeting: 5,
      cycleNumber: 3,
    );

RemoteCreditRating _rating() => const RemoteCreditRating(
      score: 73,
      band: 'B',
      bandLabel: 'Good standing',
      rated: true,
      governance: 38,
      compliance: 35,
      termsSummary: 'Eligible for group credit at a 20% deposit.',
      depositRateBps: 2000,
      factors: [],
      recommendations: ['Hold meetings weekly', 'Record fines the same day'],
    );

GroupReport _report({double attendance = 0.78}) => GroupReport.fromJson({
      'generatedAt': '2026-07-20T10:00:00.000Z',
      'group': {'name': 'Tujijenge Women VSLA', 'meetingCount': 9},
      'ledger': [
        {'type': 'SHARE_PURCHASE', 'direction': 'CREDIT', 'totalCents': 185000000},
        {'type': 'SOCIAL_CONTRIBUTION', 'direction': 'CREDIT', 'totalCents': 4200000},
        {'type': 'INTERNAL_LOAN_DISBURSEMENT', 'direction': 'DEBIT', 'totalCents': 92000000},
        {'type': 'LOAN_REPAYMENT', 'direction': 'CREDIT', 'totalCents': 31000000},
      ],
      'members': const [],
      'meetings': {'attendanceRate': attendance},
    });

MemberPassbook _passbook() => MemberPassbook.fromJson({
      'member': {
        'id': 'm-1',
        'fullName': 'Wanjiru Kamau',
        'group': {'id': 'g-1', 'name': 'Tujijenge Women VSLA', 'code': 'IWL-KBU-0001'}
      },
      'summary': {
        'sharesCents': 1250000,
        'socialCents': 300000,
        'finesCents': 15000,
        'totalPaidInCents': 1565000,
        'loansReceivedCents': 800000,
        'loansRepaidCents': 250000,
        'loanOutstandingCents': 550000,
      },
      'attendance': {'present': 7, 'total': 9, 'rate': 0.78},
      'recentEntries': const [],
    });

Future<void> _pump(
  WidgetTester tester,
  ConnectionProvider connection,
  Widget screen, {
  Size size = const Size(320, 480),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(size.width * 2, size.height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<ConnectionProvider>.value(
      value: connection,
      child: localizedApp(
        theme: ThemeData(brightness: brightness),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The button carrying [label].
///
/// `find.byType` matches the exact runtime type, and `FilledButton.icon`
/// builds a private subclass — so match on the base class instead.
ButtonStyleButton _buttonFor(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

_FakeConnection _connection(RemoteApi api,
        {List<RemoteMember> members = const [],
        List<RemoteMeeting> meetings = const [],
        RemoteGroup? group,
        RemoteUser? user}) =>
    _FakeConnection(
      store: CredentialStore(),
      api: api,
      applyCredentials: (_) {},
      fakeMembers: members,
      fakeMeetings: meetings,
      fakeGroup: group,
      fakeUser: user,
    );

void main() {
  group("Agent's view of a group on their caseload", () {
    testWidgets('shows where the money stands, not just the credit band',
        (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(rating: _rating(), report: _report()),
            members: const [
              RemoteMember(
                  id: 'm-1',
                  fullName: 'Mary Njeri',
                  role: 'CHAIRPERSON',
                  kycStatus: 'VERIFIED',
                  status: 'ACTIVE'),
            ]),
        AgentGroupDetailScreen(group: _group()),
      );

      // The credit card is tall, so the money panel sits below the fold on a
      // small phone — scrolling to it also proves the page scrolls cleanly.
      await tester.scrollUntilVisible(
          find.text('WHERE THE MONEY STANDS'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('WHERE THE MONEY STANDS'), findsOneWidget);
      // The figures an agent needs before visiting a struggling group.
      expect(find.text('Total savings'), findsOneWidget);
      expect(find.text('Still owed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flags weak attendance, which moves before the band does',
        (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(rating: _rating(), report: _report(attendance: 0.42))),
        AgentGroupDetailScreen(group: _group()),
      );
      await tester.scrollUntilVisible(find.text('Meeting attendance'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('42%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('still renders when the report cannot be loaded',
        (tester) async {
      // The rating alone must not take the whole screen down with it.
      await _pump(
        tester,
        _connection(_FakeApi(rating: _rating(), report: null)),
        AgentGroupDetailScreen(group: _group()),
      );
      expect(find.text('WHERE THE MONEY STANDS'), findsNothing);
      expect(find.text('CREDIT RATING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out with a very long group name on a small phone',
        (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(rating: _rating(), report: _report())),
        AgentGroupDetailScreen(
            group: _group(
                name:
                    'Tujijenge Women Empowerment and Savings Association of Kiambu')),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out in dark mode', (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(rating: _rating(), report: _report())),
        AgentGroupDetailScreen(group: _group()),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group("Member's own report and its download", () {
    RemoteUser user() => const RemoteUser(
        id: 'u-1', name: 'Wanjiru Kamau', role: 'MEMBER', memberId: 'm-1');

    testWidgets('offers Download beside Share once server figures are in',
        (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(passbook: _passbook()),
            group: _group(), user: user()),
        const MemberReportScreen(),
      );

      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      // Enabled, because the passbook came from the server.
      expect(_buttonFor(tester, 'Download').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disables Download when only on-phone sums are available',
        (tester) async {
      // A downloadable statement must carry the group's figures, not the
      // phone's arithmetic, so the button stays dead rather than lying.
      await _pump(
        tester,
        _connection(_FakeApi(passbook: null), group: _group(), user: user()),
        const MemberReportScreen(),
      );
      expect(_buttonFor(tester, 'Download').onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the figures on a small phone without overflowing',
        (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(passbook: _passbook()),
            group: _group(), user: user()),
        const MemberReportScreen(),
      );
      expect(find.text('Wanjiru Kamau'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tells an unauthenticated visitor to sign in', (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(passbook: null)),
        const MemberReportScreen(),
      );
      expect(find.text('Not signed in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out in dark mode', (tester) async {
      await _pump(
        tester,
        _connection(_FakeApi(passbook: _passbook()),
            group: _group(), user: user()),
        const MemberReportScreen(),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
