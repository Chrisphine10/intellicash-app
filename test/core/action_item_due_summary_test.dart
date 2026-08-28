import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/action_item_state.dart';
import 'package:intellicash_mobile/l10n/app_localizations.dart';
import 'package:intellicash_mobile/l10n/app_localizations_en.dart';

/// The one line under an action, in the agent's terms.
///
/// Both action cards built this by hand and both fell back to `state.label`,
/// which for an item due in a month is the word "Open". Caught on the emulator,
/// not in a test: an action was recorded with a due date of 30/9/2026 and every
/// screen afterwards said "Treasurer · Open" — the date the agent had just
/// chosen appeared nowhere.
void main() {
  // The English strings, read the way the widgets read them.
  final L10n l10n = L10nEn();

  ActionItemStatus statusFor({
    required String status,
    DateTime? dueDate,
    DateTime? now,
  }) =>
      actionItemStatusOf(status: status, dueDate: dueDate, now: now);

  final now = DateTime(2026, 8, 28);

  group('dueSummary', () {
    test('names the date when it is far enough off to be worth a date', () {
      final summary = dueSummary(
        statusFor(status: 'OPEN', dueDate: DateTime(2026, 9, 30), now: now),
        l10n,
      );

      // The format the date picker itself writes, rather than a spelled month:
      // the app ships in five languages and an English "Sep" inside a Dholuo
      // sentence is worse than a number.
      expect(summary, 'Due 30/9/2026');
    });

    test('counts down inside the week it becomes urgent', () {
      expect(
        dueSummary(statusFor(status: 'OPEN', dueDate: DateTime(2026, 9, 1), now: now), l10n),
        'Due in 4 days',
      );
    });

    test('says today and tomorrow rather than in 0 days', () {
      expect(
        dueSummary(statusFor(status: 'OPEN', dueDate: DateTime(2026, 8, 28), now: now), l10n),
        'Due today',
      );
      expect(
        dueSummary(statusFor(status: 'OPEN', dueDate: DateTime(2026, 8, 29), now: now), l10n),
        'Due tomorrow',
      );
    });

    test('counts the days once it is late, and gets the singular right', () {
      expect(
        dueSummary(statusFor(status: 'OPEN', dueDate: DateTime(2026, 8, 17), now: now), l10n),
        '11 days overdue',
      );
      expect(
        dueSummary(statusFor(status: 'OPEN', dueDate: DateTime(2026, 8, 27), now: now), l10n),
        '1 day overdue',
      );
    });

    test('says so plainly when nobody set a date', () {
      expect(dueSummary(statusFor(status: 'OPEN', now: now), l10n), 'No date');
    });

    /// A closed item is never overdue, however far past its date it sits.
    /// "You closed this late" is a different report from "this is outstanding".
    test('reads as closed once it is closed, whatever the date says', () {
      expect(
        dueSummary(statusFor(status: 'DONE', dueDate: DateTime(2026, 1, 1), now: now), l10n),
        'Done',
      );
      expect(
        dueSummary(statusFor(status: 'CANCELLED', dueDate: DateTime(2026, 1, 1), now: now), l10n),
        'Dropped',
      );
    });

    test('never returns the bare state word that started this', () {
      final cases = [
        statusFor(status: 'OPEN', dueDate: DateTime(2026, 9, 30), now: now),
        statusFor(status: 'OPEN', dueDate: DateTime(2026, 9, 1), now: now),
        statusFor(status: 'IN_PROGRESS', dueDate: DateTime(2026, 9, 30), now: now),
      ];

      for (final status in cases) {
        expect(dueSummary(status, l10n), isNot('Open'));
        expect(dueSummary(status, l10n), isNot('In progress'));
      }
    });
  });
}
