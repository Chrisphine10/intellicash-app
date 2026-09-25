import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_schedule_repository.dart';
import 'package:intellicash_mobile/data/services/meeting_schedule_sync.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A server that keeps one group's schedule, like the real one.
class _Server extends RemoteWriteApi {
  _Server()
      : super(ApiClient(
            credentials: () => const ApiCredentials(baseUrl: '', apiKey: '')));

  String? frequency;
  List<int>? days;
  String? time;
  bool reminders = true;
  int puts = 0;

  @override
  Future<void> putMeetingSchedule({
    required String groupId,
    required String frequency,
    required List<int> days,
    required String time,
    required bool remindersEnabled,
  }) async {
    puts++;
    this.frequency = frequency;
    this.days = days;
    this.time = time;
    reminders = remindersEnabled;
  }

  RemoteGroup group() => RemoteGroup(
        id: 'srv-g',
        name: 'Upendo',
        code: 'QA-M-1',
        phase: 'INTENSIVE',
        county: 'Kisumu',
        shareValue: 100,
        maxSharesPerMeeting: 10,
        cycleNumber: 1,
        meetingFrequency: frequency,
        meetingDays: days,
        meetingTime: time,
        remindersEnabled: reminders,
      );
}

/// Found on the emulator: a group loaded onto a new phone pushed the phone's
/// default schedule (Monday 14:00) over the group's real one, moving every
/// member's reminders. The schedule now syncs both ways.
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late IdMapRepository idMap;
  late _Server server;
  late MeetingScheduleSync sync;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_schedule_sync');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    idMap = IdMapRepository(db);
    server = _Server();
    sync = MeetingScheduleSync(
      schedule: MeetingScheduleRepository(db),
      idMap: idMap,
      writeApi: server,
      remoteMeetings: (_) async => const [],
      remoteGroup: (_) async => server.group(),
      saveLocalGroup: groups.updateGroup,
    );
  });

  tearDown(() async {
    await db.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Future<Group> phoneGroup() => groups.createGroup(
        name: 'Upendo',
        cycleNumber: 1,
        savingsMode: SavingsMode.fixed,
        shareValue: 100,
        maxSharesPerMeeting: 10,
        socialFundAmount: 50,
        interestRate: 10,
        interestType: InterestType.flat,
        loanMultiplier: 3,
        defaultLoanTermMonths: 1,
        meetingFrequency: MeetingFrequency.weekly,
        meetingDays: const [DateTime.monday],
        memberNames: const ['Akinyi'],
      );

  test('a phone that has never synced takes the server schedule, not its default', () async {
    server
      ..frequency = 'WEEKLY'
      ..days = [4, 5]
      ..time = '15:00';
    final group = await phoneGroup();

    await sync.syncGroup(group, 'srv-g');

    expect(server.puts, 0, reason: 'the default must not overwrite the real schedule');
    final local = (await groups.currentGroup())!;
    expect(local.meetingDays, [4, 5]);
    expect(local.meetingTime, '15:00');
    expect(sync.localGroupChanged, isTrue);
  });

  test('a server with no schedule gets the phone one', () async {
    final group = await phoneGroup();
    await sync.syncGroup(group, 'srv-g');
    expect(server.puts, 1);
    expect(server.days, [DateTime.monday]);
    expect(server.time, '14:00');
  });

  test('then an edit on either side reaches the other, and nothing repeats', () async {
    server
      ..frequency = 'WEEKLY'
      ..days = [4]
      ..time = '15:00';
    await sync.syncGroup(await phoneGroup(), 'srv-g');

    // Edited on the phone.
    var local = (await groups.currentGroup())!;
    await groups.updateGroup(local.copyWith(meetingTime: '16:30'));
    await sync.syncGroup((await groups.currentGroup())!, 'srv-g');
    expect(server.time, '16:30');
    expect(server.puts, 1);

    // Nothing changed: nothing sent.
    await sync.syncGroup((await groups.currentGroup())!, 'srv-g');
    expect(server.puts, 1);

    // Edited on the console.
    server.days = [2];
    await sync.syncGroup((await groups.currentGroup())!, 'srv-g');
    local = (await groups.currentGroup())!;
    expect(local.meetingDays, [2]);
    expect(local.meetingTime, '16:30');
    expect(server.puts, 1);
  });
}
