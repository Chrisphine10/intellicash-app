import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';
import 'package:intellicash_mobile/features/more/more_screen.dart';
import 'package:intellicash_mobile/providers/app_state.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';

import '../support/localized_app.dart';

class _FakeApi extends RemoteApi {
  _FakeApi()
      : super(ApiClient(
          credentials: () => ApiCredentials(baseUrl: ApiConfig.defaultBaseUrl(), apiKey: ''),
        ));

  @override
  Future<({RemoteUser user, String token})> login(String identifier, String password) async => (
        user: const RemoteUser(id: 'u1', name: 'Umoja Treasurer', role: 'GROUP_ACCOUNT', groupId: 'g1'),
        token: 't',
      );

  @override
  Future<List<RemoteGroup>> groups() async => const [];

  @override
  Future<RemoteNotifications> notifications() async => const RemoteNotifications(items: [], unreadCount: 0);

}

/// More used to be seven sections and about sixteen rows. It is now three
/// short sections, with the detailed settings one level down, and sign-out
/// kept where people look for it.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('intellicash_more');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Future<(AppState, ConnectionProvider)> pumpMore(WidgetTester tester) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.instance;
    final appState = AppState(groupRepository: GroupRepository(db), syncService: SyncService(SyncRepository(db)));
    final connection = ConnectionProvider(store: CredentialStore(), api: _FakeApi(), applyCredentials: (_) {});
    await tester.runAsync(() async {
      await GroupRepository(db).createGroup(
        name: 'Umoja Women Group',
        cycleNumber: 2,
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
        memberNames: const [],
      );
      await appState.bootstrap();
      await connection.signInWithPassword(baseUrl: ApiConfig.defaultBaseUrl(), identifier: '0712000001', password: 'pw');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: connection),
        ],
        child: localizedApp(home: const MoreScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return (appState, connection);
  }

  testWidgets('shows three short sections and keeps sign-out on the screen', (tester) async {
    await pumpMore(tester);

    expect(find.text('Umoja Women Group'), findsOneWidget);
    expect(find.text('GROUP'), findsOneWidget);
    expect(find.text('REPORTS & SHARE-OUT'), findsOneWidget);
    expect(find.text('ACCOUNT & SYNC'), findsOneWidget);
    expect(find.text('Group Settings'), findsOneWidget);
    expect(find.text('Invite & join requests'), findsOneWidget);
    expect(find.text('Cloud & advanced'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    // The detailed rows moved one level down.
    expect(find.text('Meeting Security'), findsNothing);
    expect(find.text('Payment providers'), findsNothing);
    expect(find.text('Saving cycles'), findsNothing);
  });

  testWidgets('Group settings holds set-up, security, rules, loans and cycles', (tester) async {
    await pumpMore(tester);
    await tester.tap(find.text('Group Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Edit group set-up'), findsOneWidget);
    expect(find.text('Meeting Security'), findsOneWidget);
    expect(find.text('Share cycles'), findsOneWidget);
    expect(find.textContaining('per share'), findsOneWidget);
  });

  testWidgets('Cloud & advanced holds the cloud account and payment providers', (tester) async {
    await pumpMore(tester);
    await tester.tap(find.text('Cloud & advanced'));
    await tester.pumpAndSettle();

    expect(find.text('Payment providers'), findsOneWidget);
    expect(find.text('Old local data'), findsOneWidget);
  });
}
