import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/meeting.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/module_switches.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';
import 'package:intellicash_mobile/features/meetings/meeting_hub_screen.dart';
import 'package:intellicash_mobile/providers/app_state.dart';
import 'package:intellicash_mobile/providers/meeting_provider.dart';
import 'package:intellicash_mobile/providers/member_provider.dart';

import '../support/localized_app.dart';

/// Intelli-Store and Voting appear in the meeting only when the group's
/// programme has them switched on, and the store appears once — it used to
/// be offered twice on the same screen.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('intellicash_hub');
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

  Future<void> pumpHub(WidgetTester tester, {GroupModules? modules, bool linked = true}) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.instance;
    final appState = AppState(groupRepository: GroupRepository(db), syncService: SyncService(SyncRepository(db)));
    final switches = ModuleSwitches(remoteIdFor: (_) async => linked ? 'remote-g' : null);
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
        memberNames: const ['Alice Achieng'],
      );
      meeting = await MeetingRepository(db).startMeeting(group);
      await appState.bootstrap();
      if (modules != null) await switches.remember('remote-g', modules);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: switches),
          ChangeNotifierProvider(create: (_) => MeetingProvider(MeetingRepository(db))),
          ChangeNotifierProvider(create: (_) => MemberProvider(MemberRepository(db))),
        ],
        child: localizedApp(home: MeetingHubScreen(meeting: meeting)),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  Finder store() => find.text('Intelli-Stores');
  Finder voting() => find.text('Voting');

  testWidgets('hides the store and voting until the programme switches them on', (tester) async {
    await pumpHub(tester);
    expect(store(), findsNothing);
    expect(voting(), findsNothing);
    expect(find.text('External Loans'), findsOneWidget, reason: 'outside finance stays');
  });

  testWidgets('shows the store once, and voting, when both are on', (tester) async {
    await pumpHub(tester, modules: const GroupModules(store: true, voting: true));
    expect(store(), findsOneWidget);
    expect(find.text('Intelli-Store'), findsNothing, reason: 'the duplicate tile is gone');
    expect(voting(), findsOneWidget);
  });

  testWidgets('a book not linked to the server gets neither', (tester) async {
    await pumpHub(tester, modules: const GroupModules(store: true, voting: true), linked: false);
    expect(store(), findsNothing);
    expect(voting(), findsNothing);
  });
}
