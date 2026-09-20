import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/app.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/core/theme/app_colors.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/auto_sync_coordinator.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';
import 'package:intellicash_mobile/features/dashboard/widgets/link_proposal_card.dart';
import 'package:intellicash_mobile/providers/app_state.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';
import 'package:intellicash_mobile/providers/locale_controller.dart';
import 'package:intellicash_mobile/providers/theme_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/localized_app.dart';

/// Three small behaviours that only show up on screen:
///  - a book that may belong to the signed-in group is put to the person;
///  - choosing a theme repaints the app WHERE IT IS, not from the first screen;
///  - the phone knows when it has no network.
class _FakeLinkSource implements LinkProposalSource {
  _FakeLinkSource(this._proposal);

  LinkProposal? _proposal;
  int confirmed = 0;
  int dismissed = 0;

  @override
  LinkProposal? get linkProposal => _proposal;

  @override
  Future<bool> confirmLinkProposal() async {
    confirmed++;
    _proposal = null;
    // Reports "did not link" so the test does not start a real sync.
    return false;
  }

  @override
  Future<void> dismissLinkProposal() async {
    dismissed++;
    _proposal = null;
  }
}

void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('intellicash_widget2');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    await tempDir.delete(recursive: true);
  });

  AppState appStateWith(LinkProposalSource? source, {SyncService? sync}) {
    final db = AppDatabase.instance;
    return AppState(
      groupRepository: GroupRepository(db),
      syncService: sync ?? SyncService(SyncRepository(db)),
      linkSource: source,
    );
  }

  group('linking a book to a group', () {
    testWidgets('shows both names and asks; nothing is shown when nothing is proposed',
        (tester) async {
      final source = _FakeLinkSource(const LinkProposal(
        localGroupId: 'local-1',
        localName: 'Tsunami SHG',
        remoteGroupId: 'remote-9',
        remoteName: 'Marui Women Group',
      ));
      final appState = appStateWith(source);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: appState,
        child: localizedApp(home: const Scaffold(body: LinkProposalCard())),
      ));
      await tester.pump();

      expect(find.text('Link these records to Marui Women Group?'), findsOneWidget);
      expect(find.textContaining('“Tsunami SHG”'), findsOneWidget);
      expect(find.textContaining('“Marui Women Group”'), findsWidgets);
      expect(find.text('Link them'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      final quiet = appStateWith(_FakeLinkSource(null));
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: quiet,
        child: localizedApp(home: const Scaffold(body: LinkProposalCard())),
      ));
      await tester.pump();
      expect(find.text('Link them'), findsNothing);
    });

    testWidgets('"Link them" and "Not now" reach the coordinator, and the card goes away',
        (tester) async {
      final source = _FakeLinkSource(const LinkProposal(
        localGroupId: 'local-1',
        localName: 'Tsunami SHG',
        remoteGroupId: 'remote-9',
        remoteName: 'Marui Women Group',
      ));
      final appState = appStateWith(source);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: appState,
        child: localizedApp(home: const Scaffold(body: LinkProposalCard())),
      ));
      await tester.pump();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(source.dismissed, 1);
      expect(source.confirmed, 0);
      expect(find.text('Link them'), findsNothing);

      final again = _FakeLinkSource(const LinkProposal(
        localGroupId: 'local-1',
        localName: 'Tsunami SHG',
        remoteGroupId: 'remote-9',
        remoteName: 'Marui Women Group',
      ));
      final other = appStateWith(again);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: other,
        child: localizedApp(home: const Scaffold(body: LinkProposalCard())),
      ));
      await tester.pump();
      await tester.tap(find.text('Link them'));
      await tester.pumpAndSettle();
      expect(again.confirmed, 1);
      expect(find.text('Link them'), findsNothing);
    });
  });

  test('the app knows when the phone has no network, and when it is back', () {
    final sync = SyncService(SyncRepository(AppDatabase.instance));
    final appState = appStateWith(null, sync: sync);
    var notified = 0;
    appState.addListener(() => notified++);

    expect(appState.isOnline, isTrue);
    sync.onOnlineChanged!(false);
    expect(appState.isOnline, isFalse);
    sync.onOnlineChanged!(true);
    expect(appState.isOnline, isTrue);
    expect(notified, 2, reason: 'screens describing the connection must rebuild');
  });

  testWidgets('choosing a theme repaints the app without sending it back to the first screen',
      (tester) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    final db = AppDatabase.instance;
    final appState = AppState(
      groupRepository: GroupRepository(db),
      syncService: SyncService(SyncRepository(db)),
    );
    final themeController = ThemeController();
    final localeController = LocaleController();
    final connection = ConnectionProvider(
      store: CredentialStore(),
      api: RemoteApi(ApiClient(
          credentials: () => ApiCredentials(baseUrl: ApiConfig.defaultBaseUrl(), apiKey: ''))),
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
    await tester.runAsync(() async {
      await appState.bootstrap();
      await themeController.bootstrap();
      await localeController.bootstrap();
      await connection.bootstrap();
    });
    await tester.pumpAndSettle();

    // Two screens deep, as if the person had walked to a settings screen.
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this account for?'), findsOneWidget);

    // Start from a known look, then switch to the other one.
    await tester.runAsync(() => themeController.setMode(ThemeMode.light));
    await tester.pumpAndSettle();
    final lightBackground = AppColors.background;
    await tester.runAsync(() => themeController.setMode(ThemeMode.dark));
    await tester.pumpAndSettle();

    // Still on the same screen - not thrown back to "Welcome to Intelli-Cash".
    expect(find.text('Who is this account for?'), findsOneWidget);
    expect(find.text('Welcome to Intelli-Cash'), findsNothing);

    // And it really did repaint: the palette changed under it.
    expect(AppColors.background, isNot(lightBackground));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final painted = scaffold.backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
    expect(painted, AppColors.background);

    // Going back still works, on the same history.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Intelli-Cash'), findsOneWidget);
  });
}
