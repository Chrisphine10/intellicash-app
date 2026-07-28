import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/app.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';
import 'package:intellicash_mobile/providers/app_state.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';
import 'package:intellicash_mobile/providers/locale_controller.dart';
import 'package:intellicash_mobile/providers/theme_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('intellicash_widget');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('first run boots into the welcome screen with role options',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // connectivity_plus has no test implementation; its EventChannel reports
    // a MissingPluginException through FlutterError during activation, which
    // the app already tolerates (manual sync still works) — ignore it here.
    final FlutterExceptionHandler? previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    final db = AppDatabase.instance;
    final appState = AppState(
      groupRepository: GroupRepository(db),
      syncService: SyncService(SyncRepository(db)),
    );
    final themeController = ThemeController();
    final localeController = LocaleController();
    // No secure storage plugin in tests: the store falls back to defaults,
    // so the connection bootstraps into "no session" without any network.
    final connection = ConnectionProvider(
      store: CredentialStore(),
      api: RemoteApi(ApiClient(
          credentials: () => ApiCredentials(
              baseUrl: ApiConfig.defaultBaseUrl(), apiKey: ''))),
      applyCredentials: (_) {},
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: themeController),
          ChangeNotifierProvider.value(value: localeController),
          ChangeNotifierProvider.value(value: connection),
        ],
        child: const IntelliCashApp(),
      ),
    );
    // Real database/prefs IO must run outside the fake-async test zone.
    await tester.runAsync(() async {
      await appState.bootstrap();
      await themeController.bootstrap();
      await localeController.bootstrap();
      await connection.bootstrap();
    });
    await tester.pumpAndSettle();

    // No local group and no session: the account comes first — a group is
    // only set up after signing in.
    expect(find.text('Welcome to Intelli-Cash'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Set up my group on this phone'), findsNothing);

    // Create Account leads to the friendly account-type picker.
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this account for?'), findsOneWidget);
    expect(find.text('Our Group'), findsOneWidget);
    expect(find.text('Just Me'), findsOneWidget);
    expect(find.text('Field Agent'), findsOneWidget);

    // Back out, then Sign In must offer the same three account types — this
    // is where a shared phone lands after someone signs out.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Who is signing in?'), findsOneWidget);
    expect(find.text('Our Group'), findsOneWidget);
    expect(find.text('Just Me'), findsOneWidget);
    expect(find.text('Field Agent'), findsOneWidget);

    // Choosing one opens the sign-in form, titled for that account type.
    await tester.tap(find.text('Just Me'));
    await tester.pumpAndSettle();
    expect(find.text('Phone number or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
