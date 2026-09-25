import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/notifications/meeting_alerts.dart';
import 'package:intellicash_mobile/core/utils/meeting_schedule.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/models/group.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_schedule_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Meetings start only when an official starts them. A schedule exists to
/// remind people - these tests hold both halves of that.
void main() {
  // 2026-09-24 is a Thursday.
  final thursdayMorning = DateTime(2026, 9, 24, 9);

  group('next meeting from the schedule', () {
    test('later today when the meeting time has not passed', () {
      expect(
        nextMeetingSlot(
            frequency: MeetingFrequency.weekly,
            days: const [DateTime.thursday],
            time: '14:00',
            now: thursdayMorning),
        DateTime(2026, 9, 24, 14),
      );
    });

    test('next week once today has passed, and never a day already met', () {
      expect(
        nextMeetingSlot(
            frequency: MeetingFrequency.weekly,
            days: const [DateTime.thursday],
            time: '14:00',
            now: thursdayMorning,
            lastMeetingAt: DateTime(2026, 9, 24, 8)),
        DateTime(2026, 10, 1, 14),
      );
    });

    test('fortnightly skips the week after the last meeting', () {
      expect(
        nextMeetingSlot(
            frequency: MeetingFrequency.biweekly,
            days: const [DateTime.thursday],
            time: '14:00',
            now: thursdayMorning,
            lastMeetingAt: DateTime(2026, 9, 17, 14)),
        DateTime(2026, 10, 1, 14),
      );
    });

    test('monthly is the first week of the month', () {
      expect(
        nextMeetingSlot(
            frequency: MeetingFrequency.monthly,
            days: const [DateTime.monday],
            time: '10:30',
            now: thursdayMorning),
        DateTime(2026, 10, 5, 10, 30),
      );
    });
  });

  group('reminder times', () {
    final meeting = DateTime(2026, 9, 25, 14);

    test('the day before and two hours before, while still ahead', () {
      final times = reminderTimes(meeting, DateTime(2026, 9, 24, 9));
      expect(times.map((r) => r.at),
          [DateTime(2026, 9, 24, 14), DateTime(2026, 9, 25, 12)]);
    });

    test('none once the meeting time has come', () {
      expect(reminderTimes(meeting, meeting), isEmpty);
    });
  });

  group('status in plain words', () {
    test('a scheduled meeting whose time passed reads "Not started"', () {
      final now = DateTime(2026, 9, 24, 12);
      expect(
          meetingStatusLabel('SCHEDULED',
              scheduledAt: DateTime(2026, 9, 23), now: now),
          'Not started');
      expect(
          meetingStatusLabel('SCHEDULED',
              scheduledAt: DateTime(2026, 9, 25), now: now),
          'Scheduled');
      expect(meetingStatusLabel('IN_PROGRESS'), 'In progress');
      expect(meetingStatusLabel('SEALED'), 'Closed');
      expect(meetingStatusLabel('CANCELLED'), 'Cancelled');
      expect(meetingStatusLabel('SYNC_CONFLICT'), 'Needs review');
    });
  });

  group('with a database', () {
    late Directory tempDir;
    late AppDatabase db;
    late GroupRepository groups;
    late MeetingRepository meetings;
    late MeetingScheduleRepository schedule;

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ic_meeting_schedule');
      AppDatabase.overrideFactory = databaseFactoryFfi;
      AppDatabase.overridePath = tempDir.path;
      db = AppDatabase.instance;
      groups = GroupRepository(db);
      meetings = MeetingRepository(db);
      schedule = MeetingScheduleRepository(db);
    });

    tearDown(() async {
      await db.close();
      AppDatabase.overrideFactory = null;
      AppDatabase.overridePath = null;
      await tempDir.delete(recursive: true);
    });

    Future<Group> makeGroup() => groups.createGroup(
          name: 'Tujijenge',
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
          meetingDays: const [DateTime.thursday],
          meetingTime: '15:30',
          memberNames: const ['Achieng'],
        );

    test('the meeting time is kept with the group', () async {
      await makeGroup();
      final group = await groups.currentGroup();
      expect(group!.meetingTime, '15:30');
      expect(group.remindersEnabled, isTrue);
    });

    test('plans from the server never open a meeting on the phone', () async {
      final group = await makeGroup();
      final now = DateTime.now();
      final changed = await schedule.mergeFromServer(
        group.id,
        [
          RemoteMeeting(
            id: 'srv-1',
            title: 'Planned by the console',
            status: 'SCHEDULED',
            scheduledAt: now.subtract(const Duration(hours: 1)),
            unlockStatus: 'PENDING',
            transactionTotal: 0,
          ),
          RemoteMeeting(
            id: 'srv-2',
            title: 'Next week',
            status: 'SCHEDULED',
            scheduledAt: now.add(const Duration(days: 7)),
            unlockStatus: 'PENDING',
            transactionTotal: 0,
            source: 'AUTO_SCHEDULE',
          ),
        ],
        ownMeetings: const {},
        now: now,
      );
      expect(changed, 2);
      expect(await meetings.openMeeting(group.id), isNull,
          reason: 'a plan whose time has come is still only a plan');

      final pending = await schedule.pending(group.id);
      expect(pending, hasLength(2));
      expect(pending.first.isOverdue(now), isTrue);
    });

    test("starting a meeting takes over today's plan and its server meeting", () async {
      final group = await makeGroup();
      final now = DateTime.now();
      await schedule.mergeFromServer(
        group.id,
        [
          RemoteMeeting(
            id: 'srv-today',
            title: 'Today',
            status: 'SCHEDULED',
            scheduledAt: DateTime(now.year, now.month, now.day, 23, 59),
            unlockStatus: 'PENDING',
            transactionTotal: 0,
          ),
        ],
        ownMeetings: const {},
        now: now,
      );

      final meeting = await meetings.startMeeting(group);
      final remoteId = await schedule.linkTodaysPlan(
          groupId: group.id, meetingId: meeting.id, now: now);

      expect(remoteId, 'srv-today');
      expect(await schedule.remoteIdForMeeting(meeting.id), 'srv-today');
      expect(await schedule.pending(group.id), isEmpty);
    });

    test("an old missed plan is not taken over by today's meeting", () async {
      final group = await makeGroup();
      final now = DateTime.now();
      await schedule.add(
          groupId: group.id,
          scheduledAt: now.subtract(const Duration(days: 3)),
          title: 'Missed');
      final meeting = await meetings.startMeeting(group);
      expect(
          await schedule.linkTodaysPlan(
              groupId: group.id, meetingId: meeting.id, now: now),
          isNull);
      expect(await schedule.pending(group.id), hasLength(1),
          reason: 'it waits for an official to cancel it');
    });

    test('a cancelled plan stays cancelled and is sent up', () async {
      final group = await makeGroup();
      final plan = await schedule.add(
          groupId: group.id,
          scheduledAt: DateTime.now().add(const Duration(days: 2)),
          title: 'Extra meeting');
      await schedule.markSent(plan.id, remoteId: 'srv-9');
      await schedule.cancel(plan.id, 'Public holiday');

      expect(await schedule.pending(group.id), isEmpty);
      final unsent = await schedule.unsent(group.id);
      expect(unsent.single.status, ScheduledMeetingStatus.cancelled);
      expect(unsent.single.cancelReason, 'Public holiday');

      // The server still says SCHEDULED until it hears: the phone's unsent
      // cancel wins.
      await schedule.mergeFromServer(
        group.id,
        [
          RemoteMeeting(
            id: 'srv-9',
            title: 'Extra meeting',
            status: 'SCHEDULED',
            scheduledAt: DateTime.now().add(const Duration(days: 2)),
            unlockStatus: 'PENDING',
            transactionTotal: 0,
          ),
        ],
        ownMeetings: const {},
        now: DateTime.now(),
      );
      expect(await schedule.pending(group.id), isEmpty);
    });

    test('a plan the server withdrew is dropped, a phone plan is kept', () async {
      final group = await makeGroup();
      final now = DateTime.now();
      RemoteMeeting auto(String id) => RemoteMeeting(
            id: id,
            title: 'Planned from the schedule',
            status: 'SCHEDULED',
            scheduledAt: now.add(const Duration(days: 3)),
            unlockStatus: 'PENDING',
            transactionTotal: 0,
            source: 'AUTO_SCHEDULE',
          );
      await schedule.mergeFromServer(group.id, [auto('srv-old')],
          ownMeetings: const {}, now: now);
      await schedule.add(
          groupId: group.id,
          scheduledAt: now.add(const Duration(days: 5)),
          title: 'Planned on the phone');
      expect(await schedule.pending(group.id), hasLength(2));

      // The meeting days changed: the server withdrew its old plan.
      await schedule.mergeFromServer(group.id, [auto('srv-new')],
          ownMeetings: const {}, now: now);
      final titles = (await schedule.pending(group.id)).map((p) => p.remoteId);
      expect(titles, containsAll(<String?>['srv-new', null]));
      expect(titles, isNot(contains('srv-old')));
    });

    test('the phone plans reminders for plans and the next meeting day', () async {
      final group = await makeGroup();
      final now = DateTime(2026, 9, 24, 9); // Thursday
      final alerts = planMeetingAlerts(group: group, plans: const [], now: now);
      // Thursday 15:30 today: the day-before reminder is past, the 2-hour one is not.
      expect(alerts.map((a) => a.at), [DateTime(2026, 9, 24, 13, 30)]);
      expect(alerts.single.title, 'Meeting today');

      final off = planMeetingAlerts(
          group: group.copyWith(remindersEnabled: false),
          plans: const [],
          now: now);
      expect(off, isEmpty);
    });

    test('v11 phones keep their group and gain the schedule', () async {
      await makeGroup();
      final raw = await db.database;
      await raw.execute('DROP TABLE meeting_schedule');
      await raw.execute('ALTER TABLE groups DROP COLUMN meeting_time');
      await raw.execute('ALTER TABLE groups DROP COLUMN reminders_enabled');
      await raw.execute('PRAGMA user_version = 11');
      await db.close();

      final group = await GroupRepository(AppDatabase.instance).currentGroup();
      expect(group!.name, 'Tujijenge');
      expect(group.meetingTime, '14:00');
      expect(group.remindersEnabled, isTrue);
      expect(await MeetingScheduleRepository(AppDatabase.instance).pending(group.id),
          isEmpty);
    });
  });
}
