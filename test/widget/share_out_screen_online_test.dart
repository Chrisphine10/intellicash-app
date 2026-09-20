import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/core/network/api_exception.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/member.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/share_out_repository.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/share_out_sync_service.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';
import 'package:intellicash_mobile/features/shareout/share_out_screen.dart';
import 'package:intellicash_mobile/providers/app_state.dart';
import 'package:intellicash_mobile/providers/share_out_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/localized_app.dart';

/// The share-out screen as a treasurer meets it: what it says about a share-out
/// that has not reached the online record, what it offers, and why the button is
/// off while a meeting is still open.
///
/// Rendered with the real provider, repositories and a real (ffi) database - only
/// the network is a stand-in - so a layout overflow or a wrong string fails here.
class _FakeApi extends RemoteWriteApi {
  _FakeApi()
      : super(ApiClient(credentials: () => const ApiCredentials(baseUrl: '', apiKey: '')));

  ApiException? failWith;
  final List<bool> forced = [];

  @override
  Future<RecordedShareOut> recordShareOut({
    required String groupId,
    required String shareOutId,
    required int cycleNumber,
    required List<ShareOutLineInput> lines,
    bool force = false,
  }) async {
    forced.add(force);
    final problem = failWith;
    if (problem != null) throw problem;
    return const RecordedShareOut(replayed: false, closedCycleId: 'cyc-1');
  }
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late _FakeApi api;
  late IdMapRepository idMap;
  late ShareOutSyncService sync;
  late Group group;
  late List<Member> roster;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_shareout_screen');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    api = _FakeApi();
    idMap = IdMapRepository(db);
    sync = ShareOutSyncService(db: db, idMap: idMap, writeApi: api);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  /// A group that has shared out cycle 1 and has 1,000 in shares in cycle 2.
  /// Linked to an online group unless [linked] is false.
  Future<void> arrange({bool linked = true, bool openMeeting = false}) async {
    final groups = GroupRepository(db);
    await groups.createGroup(
      name: 'Umoja Women Group',
      cycleNumber: 1,
      savingsMode: SavingsMode.fixed,
      shareValue: 100,
      maxSharesPerMeeting: 20,
      socialFundAmount: 50,
      interestRate: 10,
      interestType: InterestType.flat,
      loanMultiplier: 3,
      defaultLoanTermMonths: 1,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [DateTime.sunday],
      memberNames: const ['Ann', 'Ben'],
    );
    await groups.updateGroup((await groups.currentGroup())!.copyWith(cycleStartDate: DateTime(2026, 1, 1)));
    group = (await groups.currentGroup())!;
    roster = await MemberRepository(db).membersForGroup(group.id);

    final meetings = MeetingRepository(db);
    final first = await meetings.startMeeting(group);
    for (final m in roster) {
      await meetings.recordSharePurchase(meeting: first, group: group, memberId: m.id, shares: 5);
    }
    await meetings.closeMeeting(first);
    group = await ShareOutRepository(db).commit(group, await ShareOutRepository(db).preview(group));

    // Cycle 2: 1,000 of shares, in a meeting that is closed - or still open.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = await meetings.startMeeting(group);
    await meetings.recordSharePurchase(meeting: second, group: group, memberId: roster.first.id, shares: 10);
    if (!openMeeting) await meetings.closeMeeting(second);

    if (linked) {
      await idMap.put(MapEntity.group, group.id, 'remote-g', groupId: 'remote-g');
      for (final m in roster) {
        await idMap.put(MapEntity.member, m.id, 'remote-${m.id}', groupId: 'remote-g');
      }
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    // connectivity_plus has no test implementation; the app already tolerates that.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    // A tall screen, so the whole list is built: a ListView only builds what is on
    // (or near) the screen, and the history sits far below the payout table.
    tester.view.physicalSize = const Size(360, 4000); // a narrow phone
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final appState = AppState(
      groupRepository: GroupRepository(db),
      syncService: SyncService(SyncRepository(db)),
    );
    final provider = ShareOutProvider(ShareOutRepository(db), sync: sync);
    await tester.runAsync(() => appState.bootstrap());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: provider),
      ],
      child: localizedApp(home: const ShareOutScreen()),
    ));
    // The screen loads in a post-frame callback, through several database calls.
    // Each needs real time, and each continuation needs a frame to run in, so the
    // two alternate until what the tests look for has appeared.
    for (var i = 0; i < 40; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      if (find.text('Past share-outs').evaluate().isNotEmpty) break;
    }
    await tester.pump();
  }

  testWidgets('a share-out that has not been sent says so, and offers to send it', (tester) async {
    await tester.runAsync(() => arrange());
    await pumpScreen(tester);

    expect(find.text('Cycle 1 share-out'), findsOneWidget);
    expect(find.text('Waiting to be sent online'), findsOneWidget);
    expect(find.text('Send now'), findsOneWidget);
    expect(find.text('Send anyway'), findsNothing);
  });

  testWidgets('a refusal shows the server\'s reason, and the override only where it is allowed', (tester) async {
    await tester.runAsync(() async {
      await arrange();
      api.failWith = const ApiException(
        'The online record does not hold the same share purchases as this phone.',
        statusCode: 409,
        code: 'SHARE_OUT_OUT_OF_STEP',
      );
      await sync.send((await sync.unsent(group.id)).single);
    });
    await pumpScreen(tester);

    expect(find.textContaining('does not hold the same share purchases'), findsOneWidget);
    expect(find.text('Send now'), findsOneWidget);
    expect(find.text('Send anyway'), findsOneWidget);

    // Asking to send anyway is put in words first, and can be backed out of.
    await tester.tap(find.text('Send anyway'));
    await tester.pumpAndSettle();
    expect(find.text('Send this share-out anyway?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.forced, [false], reason: 'only the first, ordinary attempt was made');
  });

  testWidgets('a refusal that is not the phone\'s to override offers no "send anyway"', (tester) async {
    await tester.runAsync(() async {
      await arrange();
      api.failWith = const ApiException(
        'Only a platform admin or the group\'s own account may close a cycle.',
        statusCode: 403,
      );
      await sync.send((await sync.unsent(group.id)).single);
    });
    await pumpScreen(tester);

    expect(find.textContaining('may close a cycle'), findsOneWidget);
    expect(find.text('Send anyway'), findsNothing);
  });

  testWidgets('a share-out already recorded online shows as recorded and offers nothing', (tester) async {
    await tester.runAsync(() async {
      await arrange();
      await sync.send((await sync.unsent(group.id)).single);
    });
    await pumpScreen(tester);

    expect(find.text('Recorded online'), findsOneWidget);
    expect(find.text('Send now'), findsNothing);
  });

  testWidgets('one made before it could be sent is marked as history, not as waiting', (tester) async {
    await tester.runAsync(() async {
      await arrange();
      await idMap.put(MapEntity.shareOut, '${group.id}#1', ShareOutSyncService.beforeOnlineRecordingMarker);
    });
    await pumpScreen(tester);

    expect(find.text('Made before share-outs could be sent online'), findsOneWidget);
    expect(find.text('Send now'), findsNothing);
  });

  testWidgets('a meeting still open switches the button off and says which one to close', (tester) async {
    await tester.runAsync(() => arrange(openMeeting: true));
    await pumpScreen(tester);

    expect(find.textContaining('Close Meeting #2 before sharing out'), findsOneWidget);
    // FilledButton.icon builds a private subclass, so match by "is a", not by type.
    final button = tester.widget<FilledButton>(find.ancestor(
      of: find.textContaining('Distribute & close Cycle 2'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    ));
    expect(button.onPressed, isNull);
  });

  testWidgets('the confirmation says the payouts will be sent, or that this group cannot send them', (tester) async {
    await tester.runAsync(() => arrange());
    await pumpScreen(tester);
    await tester.ensureVisible(find.textContaining('Distribute & close Cycle 2'));
    await tester.tap(find.textContaining('Distribute & close Cycle 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sent to the online record when there is a signal'), findsOneWidget);
    expect(find.textContaining('Cycle 2 is closed there too'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('for a group that is not linked online it says the payouts are not sent', (tester) async {
    await tester.runAsync(() => arrange(linked: false));
    await pumpScreen(tester);
    // Nothing to send to, so no status line on the share-out either.
    expect(find.text('Waiting to be sent online'), findsNothing);

    await tester.ensureVisible(find.textContaining('Distribute & close Cycle 2'));
    await tester.tap(find.textContaining('Distribute & close Cycle 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not linked to the online record, so they are not sent'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
