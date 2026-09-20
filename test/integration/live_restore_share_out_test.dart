@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/repositories/share_out_repository.dart';
import 'package:intellicash_mobile/data/services/auto_sync_coordinator.dart';
import 'package:intellicash_mobile/data/services/group_history_importer.dart';
import 'package:intellicash_mobile/data/services/group_restore_service.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/share_out_sync_service.dart';
import 'package:intellicash_mobile/data/services/write_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A group's whole life across two phones, against a RUNNING server: load it onto
/// a phone, record a meeting, share out, and load it again on a fresh phone.
///
/// The unit tests use fakes for the network, which cannot catch the mistake that
/// matters most here - the phone and the server disagreeing about a field name or
/// a number - so this drives the real client against the real API and reads the
/// server back.
///
/// The group is seeded by `node qa/05-phone-share-out.mjs seed` (three members,
/// one past meeting: shares 5,000 / 3,000 / 2,000, and a 1,000 loan half repaid).
/// A group can be shared out once, so seed a new one for each run.
///
///   flutter test test/integration/live_restore_share_out_test.dart --tags live \
///     --dart-define=QA_LOGIN=0712922300 --dart-define=QA_PASSWORD=... \
///     --dart-define=QA_BASE=http://localhost:4100/api/v1
void main() {
  const base = String.fromEnvironment('QA_BASE', defaultValue: 'http://localhost:4100/api/v1');
  const login = String.fromEnvironment('QA_LOGIN');
  const password = String.fromEnvironment('QA_PASSWORD');

  late Directory tempDir;
  ApiCredentials creds = const ApiCredentials(baseUrl: base, apiKey: '');
  late ApiClient client;
  late RemoteApi remote;
  late String remoteGroupId;

  setUpAll(sqfliteFfiInit);

  Future<void> freshPhone() async {
    await AppDatabase.instance.close();
    tempDir = await Directory.systemTemp.createTemp('ic_live_phone');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
  }

  tearDownAll(() async {
    await AppDatabase.instance.close();
  });

  GroupRestoreService restoreService(AppDatabase db) => GroupRestoreService(
        api: RemoteApiRestoreAdapter(remote),
        groups: GroupRepository(db),
        members: MemberRepository(db),
        idMap: IdMapRepository(db),
        history: GroupHistoryImporter(db: db),
      );

  test('load, record, share out, and load again', () async {
    client = ApiClient(credentials: () => creds);
    remote = RemoteApi(client);

    final session = await remote.login(login, password);
    creds = ApiCredentials(baseUrl: base, apiKey: session.token);
    remoteGroupId = session.user.groupId!;

    // ---- phone 1: load the group ------------------------------------------------
    await freshPhone();
    final db = AppDatabase.instance;
    final restored = await restoreService(db).restore(remoteGroupId);

    expect(restored.alreadyPresent, isFalse);
    expect(restored.membersRestored, 3);
    expect(restored.history, isNotNull, reason: 'the server must send the restore bundle');
    expect(restored.history!.imported, isTrue);
    expect(restored.history!.meetings, 1);
    // three share purchases + three social + one repayment
    expect(restored.history!.records, 7);
    expect(restored.history!.loans, 1);
    expect(restored.history!.skipped, 0);

    final group = restored.group!;
    expect(group.shareValue, 500);
    expect(group.interestRate, 10.0, reason: 'the rate the group set online, not a default');
    expect(group.defaultLoanTermMonths, 1);

    // What the phone now holds is what the server holds: shares 10,000, social 150,
    // loan 1,000 out and 300 back = 10,000 + 300 - 1,000 in the loan fund.
    final meetings = MeetingRepository(db);
    final roster = await MemberRepository(db).membersForGroup(group.id);
    final byName = {for (final m in roster) m.name.split(' ').first: m};
    expect(await meetings.cashBoxBalance(group.id), 10000 + 150 + 300 - 1000);

    // ---- phone 1: record a meeting and send it ---------------------------------
    final meeting = await meetings.startMeeting(group);
    for (final m in roster) {
      await meetings.setAttendance(meeting: meeting, memberId: m.id, present: true);
    }
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: byName['Amina']!.id, shares: 2);
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: byName['Baraka']!.id, shares: 1);
    await meetings.closeMeeting(meeting);

    final idMap = IdMapRepository(db);
    final writeApi = RemoteWriteApi(client);
    final shareOutSync = ShareOutSyncService(db: db, idMap: idMap, writeApi: writeApi);
    final coordinator = AutoSyncCoordinator(
      idMap: idMap,
      meetings: meetings,
      writeSync: WriteSyncService(db: db, idMap: idMap, writeApi: writeApi),
      shareOutSync: shareOutSync,
    );
    await coordinator.syncBoundGroups();
    expect(await coordinator.pendingMeetings(), 0, reason: 'the meeting reached the server');

    // ---- phone 1: share out -------------------------------------------------------
    // Cycle: Amina 6,000  Baraka 3,500  Chege 2,000 = capital 11,500. Baraka's loan
    // (1,000 + 10 % for one month = 1,100, 300 repaid) leaves 800 owing, so the
    // pool is 11,500 + 100 of interest = 11,600, split 6,052.17 / 3,530.44 / 2,017.39
    // (the spare cent goes to the largest remainder), with 800 taken off Baraka.
    final shareOut = ShareOutRepository(db);
    final preview = await shareOut.preview(group);
    expect(preview.shareCapitalCents, 1150000);
    expect(preview.savingsPoolCents, 1160000);
    final baraka = preview.lines.firstWhere((l) => l.memberId == byName['Baraka']!.id);
    expect(baraka.loanOffsetCents, 80000);
    expect(baraka.grossPayoutCents, 353044);
    expect(baraka.netPayoutCents, 353044 - 80000);
    expect(preview.lines.map((l) => l.grossPayoutCents).reduce((a, b) => a + b), 1160000);

    final next = await shareOut.commit(group, preview);
    expect(next.cycleNumber, 2);

    // Nothing is sent by commit itself; the sync does it, in order.
    expect(await coordinator.pendingShareOuts(), 1);
    await coordinator.syncBoundGroups();
    expect(await coordinator.pendingShareOuts(), 0, reason: 'the server recorded the share-out');
    expect(await coordinator.shareOutAttention(), isNull);
    expect((await shareOutSync.statuses(group.id))[1]!.state, ShareOutSyncState.sent);

    // ---- the server, read back ---------------------------------------------------------
    final bundle = (await remote.restoreBundle(remoteGroupId))!;
    expect(bundle.cycleNumber, 2, reason: 'the share-out closed cycle 1 and opened cycle 2');
    final payouts = bundle.entries.where((e) => e.type == 'SHARE_OUT_PAYOUT').toList();
    expect(payouts.map((e) => e.amountCents).toList()..sort(), [201739, 353044, 605217]);
    expect(payouts.every((e) => e.cycleNumber == 1), isTrue);
    final settlement =
        bundle.entries.singleWhere((e) => e.description.startsWith('Loan settled from share-out'));
    expect(settlement.amountCents, 80000);
    expect(bundle.loans.single.status, 'REPAID');

    // ---- phone 2: a fresh handset loads the group again ---------------------------
    await freshPhone();
    final db2 = AppDatabase.instance;
    final again = await restoreService(db2).restore(remoteGroupId);

    expect(again.history!.imported, isTrue);
    expect(again.history!.meetings, 2);
    expect(again.history!.shareOuts, 1);
    final group2 = again.group!;
    expect(group2.cycleNumber, 2);

    // The share-out is in its history, the new cycle starts with nothing, and the
    // share-out is not waiting to be sent again.
    final history = await ShareOutRepository(db2).history(group2.id);
    expect(history.single.cycleNumber, 1);
    expect(history.single.payouts, hasLength(3));
    final barakaPaid = history.single.payouts.firstWhere((p) => p.memberName.startsWith('Baraka'));
    expect(barakaPaid.grossPayout, 3530.44);
    expect(barakaPaid.loanOffset, 800.0);
    expect(barakaPaid.netPayout, 2730.44);
    final service2 = ShareOutSyncService(
        db: db2, idMap: IdMapRepository(db2), writeApi: RemoteWriteApi(client));
    expect(await service2.unsent(group2.id), isEmpty);
    // The loan fund was shared out to the cent; what is left is the welfare fund
    // (150.00 of social contributions), which this share-out did not distribute.
    expect(await MeetingRepository(db2).cashBoxBalance(group2.id), 150.0);
  },
      timeout: const Timeout(Duration(minutes: 3)),
      skip: login.isEmpty ? 'live test: pass --dart-define=QA_LOGIN=... and QA_PASSWORD=...' : false);
}
