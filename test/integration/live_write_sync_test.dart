@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/write_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end write-path test against a RUNNING backend.
///
/// Exercises the real ApiClient -> RemoteWriteApi -> WriteSyncService against
/// `localhost:4000` with a seeded `MOBILE_CORE` key, then reads the backend
/// ledger back to prove the share purchase landed with the right cents and
/// payment reference.
///
/// Excluded from the default suite (tagged `live`). Run explicitly with the
/// backend up:
///   flutter test test/integration/live_write_sync_test.dart --tags live \
///     --dart-define=IC_TOKEN=ic_sk_...
void main() {
  const baseUrl = 'http://localhost:4000/api/v1';
  const token = String.fromEnvironment('IC_TOKEN');
  // Seed group IWL-KBU-0001 (Tujijenge) and its chairperson Mary Njeri.
  const remoteGroupId = 'cmrkfdvx00018v0fcpaekt1m7';
  const remoteMaryId = 'cmrkfdxie001ev0fcdg15b03l';

  late Directory tempDir;
  late AppDatabase db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_live');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('syncs a local meeting to the live backend and reads it back', () async {
    final groups = GroupRepository(db);
    final members = MemberRepository(db);
    final meetings = MeetingRepository(db);
    final idMap = IdMapRepository(db);

    // Local group + one member we will bind to Mary.
    final group = await groups.createGroup(
      name: 'Live Sync Group',
      cycleNumber: 1,
      savingsMode: SavingsMode.fixed,
      shareValue: 100,
      maxSharesPerMeeting: 10,
      socialFundAmount: 50,
      interestRate: 5,
      interestType: InterestType.reducingBalance,
      loanMultiplier: 2,
      defaultLoanTermMonths: 3,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [DateTime.sunday],
      memberNames: ['Mary Njeri'],
    );
    final local = (await members.membersForGroup(group.id)).single;

    // A meeting with a mobile-money share purchase.
    final meeting = await meetings.startMeeting(group);
    await meetings.setAttendance(
        meeting: meeting, memberId: local.id, present: true);
    await meetings.recordSharePurchase(
      meeting: meeting,
      group: group,
      memberId: local.id,
      shares: 4, // 400.00 -> 40000 cents
      paymentMethod: PaymentMethod.mpesa,
      paymentReference: 'LIVETEST-REF',
    );

    // Bind to the real backend group + member.
    await idMap.put(MapEntity.group, group.id, remoteGroupId);
    await idMap.put(MapEntity.member, local.id, remoteMaryId);

    // Real network stack.
    final client = ApiClient(
      credentials: () =>
          const ApiCredentials(baseUrl: baseUrl, apiKey: token),
    );
    final service = WriteSyncService(
      db: db,
      idMap: idMap,
      writeApi: RemoteWriteApi(client),
    );

    final result = await service.syncMeeting(meeting);
    expect(result.conflicts, isEmpty,
        reason: 'no conflicts expected for a mapped member');
    expect(result.syncedCount, greaterThanOrEqualTo(2)); // attendance + share

    // Read the ledger back from the backend and find our entry.
    final ledger = await client.getList(
      '/groups/$remoteGroupId/ledger',
      query: {'meetingId': result.remoteMeetingId},
    );
    final share = ledger.cast<Map<String, dynamic>>().firstWhere(
          (e) => e['type'] == 'SHARE_PURCHASE',
          orElse: () => {},
        );
    expect(share['amountCents'], 40000);
    expect(share['direction'], 'CREDIT');
    expect(share['externalReference'], 'LIVETEST-REF');
    expect((share['fundAccount'] as Map)['type'], 'INTERNAL_LOAN');

    client.close();
  }, skip: token.isEmpty ? 'live test: pass --dart-define=IC_TOKEN=ic_sk_…' : false);
}
