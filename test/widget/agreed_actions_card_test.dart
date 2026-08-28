import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/repositories/mentorship_repository.dart';
import 'package:intellicash_mobile/features/visits/agreed_actions_card.dart';
import '../support/localized_app.dart';

/// Agreeing an action, from the sheet to the stored row.
///
/// The repository is faked in memory: a widget test runs in a fake-async zone
/// where real file I/O never completes, so a card backed by real sqflite would
/// sit unloaded until the test timed out. What the database does with a row is
/// proved in `test/data/mentorship_repository_test.dart`; what is under test
/// here is everything BETWEEN the agent's taps and that call.
///
/// Which is where a bug lived. On the emulator an action recorded with a due
/// date of 30/9/2026 came back reading "Treasurer · Open" — the date appeared
/// on no screen afterwards. Two candidates: the row never carried it, or the
/// row carried it and nothing rendered it. Only a test across the seam tells
/// them apart.
void main() {
  late _FakeMentorship mentorship;

  setUp(() => mentorship = _FakeMentorship());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: AgreedActionsCard(
            remoteGroupId: 'remote-g1',
            visitId: 'v1',
            mentorship: mentorship,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('invites the first action rather than showing an empty box',
      (tester) async {
    await pump(tester);

    expect(find.textContaining('Nothing agreed yet'), findsOneWidget);
    expect(find.text('Agree an action'), findsOneWidget);
  });

  testWidgets('carries the title, owner and due date through to the row',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Agree an action'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'What was agreed'),
      'Open a group bank account',
    );
    await tester.tap(find.text('Treasurer'));
    await tester.pump();

    // The date picker, driven the way an agent drives it.
    await tester.tap(find.textContaining('Set a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to the plan'));
    await tester.pumpAndSettle();

    final raised = mentorship.raised.single;
    expect(raised.title, 'Open a group bank account');
    expect(raised.owner, 'Treasurer');
    // The whole point of the picker. A null here is the bug.
    expect(raised.dueDate, isNotNull);
  });

  testWidgets('shows the date on the row, not the word "Open"', (tester) async {
    mentorship.items.add(
      LocalActionItem(
        id: 'a1',
        remoteGroupId: 'remote-g1',
        visitId: 'v1',
        title: 'Open a group bank account',
        owner: 'Treasurer',
        status: 'OPEN',
        isDirty: false,
        dueDate: DateTime.now().add(const Duration(days: 33)),
      ),
    );

    await pump(tester);

    expect(find.textContaining('Due '), findsOneWidget);
    expect(find.textContaining('Treasurer · Open'), findsNothing);
  });

  testWidgets('records nothing when the sheet is cancelled', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Agree an action'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What was agreed'),
      'Something discussed but not agreed',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(mentorship.raised, isEmpty);
    expect(find.textContaining('Nothing agreed yet'), findsOneWidget);
  });

  testWidgets('refuses an action with no title', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Agree an action'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to the plan'));
    await tester.pumpAndSettle();

    expect(mentorship.raised, isEmpty);
    expect(find.textContaining('Say what the group agreed'), findsOneWidget);
  });

  testWidgets('closes against this visit, and clears that on reopen',
      (tester) async {
    mentorship.items.add(
      LocalActionItem(
        id: 'a1',
        remoteGroupId: 'remote-g1',
        visitId: 'v1',
        title: 'Open a group bank account',
        status: 'OPEN',
        isDirty: false,
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump();
    expect(mentorship.statusCalls.last, ('a1', 'DONE', 'v1'));

    await tester.tap(find.text('Reopen'));
    await tester.pump();
    await tester.pump();
    // Reopening must not leave it claiming it was finished at this visit.
    expect(mentorship.statusCalls.last, ('a1', 'OPEN', null));
  });
}

class _FakeMentorship extends MentorshipRepository {
  final List<LocalActionItem> items = [];
  final List<LocalActionItem> raised = [];
  final List<(String, String, String?)> statusCalls = [];

  @override
  Future<List<LocalActionItem>> itemsForVisit(String visitId) async =>
      items.where((item) => item.visitId == visitId).toList();

  @override
  Future<LocalActionItem> raise({
    required String visitId,
    required String remoteGroupId,
    required String title,
    String? detail,
    String? owner,
    DateTime? dueDate,
  }) async {
    final item = LocalActionItem(
      id: 'a${items.length + 1}',
      remoteGroupId: remoteGroupId,
      visitId: visitId,
      title: title,
      detail: detail,
      owner: owner,
      dueDate: dueDate,
      status: 'OPEN',
      isDirty: true,
    );
    raised.add(item);
    items.add(item);
    return item;
  }

  @override
  Future<void> setStatus({
    required String id,
    required String status,
    String? closingNote,
    String? closedAtVisitId,
  }) async {
    statusCalls.add((id, status, closedAtVisitId));
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final existing = items[index];
    items[index] = LocalActionItem(
      id: existing.id,
      remoteGroupId: existing.remoteGroupId,
      visitId: existing.visitId,
      title: existing.title,
      detail: existing.detail,
      owner: existing.owner,
      dueDate: existing.dueDate,
      status: status,
      isDirty: true,
    );
  }
}
