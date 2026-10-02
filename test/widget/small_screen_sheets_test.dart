import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/meeting.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/loan_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/module_switches.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';
import 'package:intellicash_mobile/features/meetings/meeting_hub_screen.dart';
import 'package:intellicash_mobile/providers/app_state.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';
import 'package:intellicash_mobile/providers/loan_provider.dart';
import 'package:intellicash_mobile/providers/meeting_provider.dart';
import 'package:intellicash_mobile/providers/member_provider.dart';

import '../support/localized_app.dart';

/// The meeting's payment sheets on small phones and with large text.
///
/// Buy Shares used to be a fixed column: with the payment card it was taller
/// than a small phone's screen and could not scroll, so the button that
/// records the purchase was out of reach. Every sheet must now fit or scroll,
/// with no layout overflow, and its action button must be reachable.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('intellicash_small');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpHub(WidgetTester tester, {required Size logical, double textScale = 1.0}) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = logical * 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final db = AppDatabase.instance;
    final appState = AppState(groupRepository: GroupRepository(db), syncService: SyncService(SyncRepository(db)));
    final switches = ModuleSwitches(remoteIdFor: (_) async => null);
    late Meeting meeting;
    await tester.runAsync(() async {
      final group = await GroupRepository(db).createGroup(
        name: 'Umoja Women Group',
        cycleNumber: 1,
        savingsMode: SavingsMode.fixed,
        shareValue: 500,
        maxSharesPerMeeting: 5,
        socialFundAmount: 50,
        interestRate: 10,
        interestType: InterestType.flat,
        loanMultiplier: 3,
        defaultLoanTermMonths: 1,
        meetingFrequency: MeetingFrequency.weekly,
        meetingDays: const [1],
        memberNames: const ['Alice Achieng', 'Beatrice Wambui'],
      );
      meeting = await MeetingRepository(db).startMeeting(group);
      // A member with shares and a loan, so Repayment shows its whole form
      // (with no loan it shows only a short "nothing to repay" note).
      final alice = (await MemberRepository(db).membersForGroup(group.id)).first;
      await MeetingRepository(db).recordSharePurchase(meeting: meeting, group: group, memberId: alice.id, shares: 5);
      await LoanRepository(db).disburse(
        group: group,
        memberId: alice.id,
        principal: 1000,
        dueDate: DateTime.now().add(const Duration(days: 31)),
        meetingId: meeting.id,
      );
      await appState.bootstrap();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: switches),
          ChangeNotifierProvider(create: (_) => MeetingProvider(MeetingRepository(db))),
          ChangeNotifierProvider(create: (_) => MemberProvider(MemberRepository(db))),
          ChangeNotifierProvider(create: (_) => LoanProvider(LoanRepository(db))),
          // Signed out: the sheets offer cash and M-Pesa Classic, as offline.
          ChangeNotifierProvider(
            create: (_) => ConnectionProvider(
              store: CredentialStore(),
              api: RemoteApi(ApiClient(
                  credentials: () => ApiCredentials(baseUrl: ApiConfig.defaultBaseUrl(), apiKey: ''))),
              applyCredentials: (_) {},
            ),
          ),
        ],
        child: localizedApp(home: MeetingHubScreen(meeting: meeting)),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  Future<void> openFromHub(WidgetTester tester, String tile) async {
    final target = find.text(tile);
    await tester.scrollUntilVisible(target, 120, scrollable: find.byType(Scrollable).first);
    await tester.tap(target);
    // The sheet loads from the local database after it opens; that IO only
    // advances inside runAsync, so give it a few real rounds.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pumpAndSettle();
    }
  }

  /// The sheet's last button can be scrolled to and lies wholly on screen.
  Future<void> expectActionReachable(WidgetTester tester, Size logical) async {
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    final button = find.descendant(of: sheet, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(button, findsWidgets);
    final last = button.last;
    final scrollable = find.descendant(of: sheet, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(last, 80, scrollable: scrollable);
    await tester.pumpAndSettle();
    final rect = tester.getRect(last);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(logical.height + 0.5),
        reason: 'the action button must be reachable on a ${logical.width.toInt()}×${logical.height.toInt()} screen');
  }

  const phones = <String, (Size, double)>{
    'a small phone (320×568)': (Size(320, 568), 1.0),
    'a common phone (360×640)': (Size(360, 640), 1.0),
    'a common phone with large text (360×640, 130%)': (Size(360, 640), 1.3),
  };

  for (final entry in phones.entries) {
    final (logical, textScale) = entry.value;
    for (final tile in const ['Buy Shares', 'Record Fine', 'Repayment']) {
      testWidgets('$tile fits or scrolls on ${entry.key}', (tester) async {
        await pumpHub(tester, logical: logical, textScale: textScale);
        await openFromHub(tester, tile);
        expect(tester.takeException(), isNull);
        await expectActionReachable(tester, logical);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
