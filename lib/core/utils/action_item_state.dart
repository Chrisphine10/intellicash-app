/// Dart mirror of the server's `domain/action-plan.ts`.
///
/// An agent opening their follow-up queue in a valley with no signal has to see
/// the same "overdue" the office sees. So the rule lives on both sides, and —
/// exactly as on the server — **OVERDUE is derived, never stored**. Nothing
/// here reads a status column for lateness; it reads the date.
///
/// If the two ever disagree the server wins, but the arithmetic is small enough
/// that they should not: a subtraction and two comparisons.
library;

import '../../l10n/app_localizations.dart';

/// What somebody did about the item. Stored.
const actionItemStatuses = ['OPEN', 'IN_PROGRESS', 'DONE', 'CANCELLED'];

/// What a reader should see. Derived. Note OVERDUE, which is never stored.
enum ActionItemState {
  overdue('Overdue'),
  dueSoon('Due soon'),
  open('Open'),
  inProgress('In progress'),
  done('Done'),
  cancelled('Cancelled');

  const ActionItemState(this.label);
  final String label;
}

/// Inside this window an item is worth raising before it slips.
const int dueSoonDays = 7;

class ActionItemStatus {
  const ActionItemStatus({
    required this.state,
    required this.status,
    required this.dueDate,
    required this.daysUntilDue,
    required this.daysOverdue,
    required this.open,
  });

  final ActionItemState state;
  final String status;
  final DateTime? dueDate;

  /// Negative once past. Null when the item has no due date.
  final int? daysUntilDue;

  /// How late it is, in days. Zero unless overdue.
  final int daysOverdue;

  /// Still requires somebody to do something.
  final bool open;

  String get label => state.label;
}

/// Resolves the state a reader should see.
///
/// A DONE or CANCELLED item is never overdue, however far past its date it
/// sits. "You closed this late" is a different report from "this is
/// outstanding", and merging them fills the follow-up queue with finished work.
ActionItemStatus actionItemStatusOf({
  required String status,
  DateTime? dueDate,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  // Whole days, floored, so an item due later today is not already "yesterday".
  final daysUntilDue = dueDate == null
      ? null
      : _floorDays(dueDate.difference(at).inMilliseconds);

  if (status == 'DONE' || status == 'CANCELLED') {
    return ActionItemStatus(
      state: status == 'DONE' ? ActionItemState.done : ActionItemState.cancelled,
      status: status,
      dueDate: dueDate,
      daysUntilDue: daysUntilDue,
      daysOverdue: 0,
      open: false,
    );
  }

  final overdue = daysUntilDue != null && daysUntilDue < 0;
  final dueSoon = daysUntilDue != null && daysUntilDue >= 0 && daysUntilDue <= dueSoonDays;

  final state = overdue
      ? ActionItemState.overdue
      : dueSoon
          ? ActionItemState.dueSoon
          : status == 'IN_PROGRESS'
              ? ActionItemState.inProgress
              : ActionItemState.open;

  return ActionItemStatus(
    state: state,
    status: status,
    dueDate: dueDate,
    daysUntilDue: daysUntilDue,
    // Whole days ELAPSED since the date, not the absolute value of a floored
    // negative. Something due 12 days and 14 hours ago has been overdue for 12
    // days; `floor(-12.58).abs()` reported 13 — a number an agent reads off the
    // screen and repeats to a group. Mirrors the server exactly.
    daysOverdue:
        overdue ? _floorDays(at.difference(dueDate!).inMilliseconds) : 0,
    open: true,
  );
}

int _floorDays(int milliseconds) {
  const msPerDay = 24 * 60 * 60 * 1000;
  // Dart's ~/ truncates towards zero, which would round -0.5 days up to 0 and
  // make something overdue look merely due today.
  return (milliseconds / msPerDay).floor();
}

/// Most overdue first, then due soonest, then undated, then closed.
///
/// Undated items sort after dated ones deliberately: an item somebody put a
/// date against is one they committed to.
int byUrgency(ActionItemStatus a, ActionItemStatus b) {
  if (a.open != b.open) return a.open ? -1 : 1;
  if (a.daysUntilDue == null && b.daysUntilDue == null) return 0;
  if (a.daysUntilDue == null) return 1;
  if (b.daysUntilDue == null) return -1;
  return a.daysUntilDue!.compareTo(b.daysUntilDue!);
}

/// The 1-5 scale the GROUP scores the coaching on.
///
/// Collected from the group's representative, not the agent — an agent rating
/// their own session gives 4 or 5 every time. The representative is already
/// holding the phone for the sign-off PIN.
const int minMentorshipRating = 1;
const int maxMentorshipRating = 5;

bool isValidMentorshipRating(int score) =>
    score >= minMentorshipRating && score <= maxMentorshipRating;

/// How an item's timing reads on one line.
///
/// The two action cards each built this by hand and both landed on
/// `state.label`, which for an item due in a month is the word "Open". An agent
/// who had just set a due date saw no date anywhere afterwards — the one piece
/// of information they had gone to the trouble of entering.
///
/// Takes the localisations rather than reading them: this file has no
/// BuildContext, the same reason the PDF builders are handed their strings.
///
/// The date itself is written the way the picker writes it (`30/9/2026`)
/// rather than with a spelled month: the app ships in five languages and an
/// English "Sep" in a Dholuo sentence would be worse than a number.
String dueSummary(ActionItemStatus status, L10n l10n) {
  switch (status.state) {
    case ActionItemState.overdue:
      final days = status.daysOverdue;
      return days == 1
          ? l10n.actionOneDayOverdue
          : l10n.actionDaysOverdue(days);
    case ActionItemState.done:
      return l10n.joinGroupDone;
    case ActionItemState.cancelled:
      return l10n.actionDropped;
    case ActionItemState.dueSoon:
    case ActionItemState.open:
    case ActionItemState.inProgress:
      final due = status.dueDate;
      if (due == null) return l10n.actionNoDueDate;

      final days = status.daysUntilDue ?? 0;
      if (days == 0) return l10n.actionDueToday;
      if (days == 1) return l10n.actionDueTomorrow;
      if (days <= dueSoonDays) return l10n.actionDueInDays(days);
      return l10n.agreedActionsDueOn(formatDueDate(due));
  }
}

/// `30/9/2026`. Shared so the picker button and the rows agree.
String formatDueDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
