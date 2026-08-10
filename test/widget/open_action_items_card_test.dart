import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/repositories/mentorship_repository.dart';
import 'package:intellicash_mobile/features/visits/open_action_items_card.dart';

/// What the agent sees before they start a visit.
///
/// The repository is faked in memory. A widget test runs in a fake-async zone
/// where real file I/O never completes — pumping does not advance it, so a card
/// backed by real sqflite would sit unloaded until the test timed out. The
/// database behaviour is proved against real sqflite in
/// `test/data/mentorship_repository_test.dart`; what is under test here is the
/// card, and the lateness arithmetic it displays, which is the real thing.
void main() {
  late _FakeMentorshipRepository mentorship;

  setUp(() {
    mentorship = _FakeMentorshipRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenActionItemsCard(
            remoteGroupId: 'remote-g1',
            visitId: 'v1',
            mentorship: mentorship,
          ),
        ),
      ),
    );
    // One pump to build, one to apply the setState after the load resolves.
    await tester.pump();
    await tester.pump();
  }

  void give({
    required String title,
    String? owner,
    Duration? overdueBy,
    Duration? dueIn,
  }) {
    mentorship.items.add(
      LocalActionItem(
        id: 'a${mentorship.items.length + 1}',
        remoteGroupId: 'remote-g1',
        visitId: 'v1',
        title: title,
        owner: owner,
        status: 'OPEN',
        isDirty: false,
        dueDate: overdueBy != null
            ? DateTime.now().subtract(overdueBy)
            : dueIn != null
                ? DateTime.now().add(dueIn)
                : null,
      ),
    );
  }

  testWidgets('says plainly when the group owes nothing', (tester) async {
    // An absent card looks like a feature that failed. "Nothing outstanding" is
    // information an agent actually wants before they begin.
    await pump(tester);

    expect(find.text('Nothing outstanding'), findsOneWidget);
  });

  testWidgets('lists what is still open, and leads with how much is late',
      (tester) async {
    give(title: 'Write up the ledger', owner: 'the treasurer', overdueBy: const Duration(days: 12));
    give(title: 'Open a bank account', dueIn: const Duration(days: 40));

    await pump(tester);

    expect(find.text('From the last visit'), findsOneWidget);
    expect(find.textContaining('2 still open, 1 overdue'), findsOneWidget);
    expect(find.text('Write up the ledger'), findsOneWidget);
    expect(find.textContaining('12 days overdue'), findsOneWidget);
    expect(find.textContaining('the treasurer'), findsOneWidget);
  });

  testWidgets('does not cry overdue when nothing is late', (tester) async {
    give(title: 'Open a bank account', dueIn: const Duration(days: 40));

    await pump(tester);

    expect(find.textContaining('1 still open'), findsOneWidget);
    expect(find.textContaining('overdue'), findsNothing);
  });

  testWidgets('closing an item takes it off the list and queues the change',
      (tester) async {
    give(title: 'Write up the ledger', overdueBy: const Duration(days: 3));
    await pump(tester);

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nothing outstanding'), findsOneWidget);
    // Recorded against the visit that closed it, and marked for pushing.
    expect(mentorship.closed, [('a1', 'DONE', 'v1')]);
  });

  testWidgets('renders on a 320x480 handset without overflowing', (tester) async {
    // The field device, not the emulator's default.
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    give(
      title: 'Write up the ledger and reconcile it against the cash box count',
      owner: 'the treasurer and the chairlady together',
      overdueBy: const Duration(days: 3),
    );

    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('From the last visit'), findsOneWidget);
  });
}

/// In-memory stand-in. The lateness arithmetic still comes from the real
/// `LocalActionItem.state`, so the numbers on screen are genuinely computed.
class _FakeMentorshipRepository extends MentorshipRepository {
  final List<LocalActionItem> items = [];
  final List<(String, String, String?)> closed = [];

  @override
  Future<List<LocalActionItem>> openItemsFor(String remoteGroupId) async {
    final open = items
        .where((item) =>
            item.remoteGroupId == remoteGroupId &&
            item.status != 'DONE' &&
            item.status != 'CANCELLED')
        .toList();
    open.sort((a, b) => byUrgencyOf(a, b));
    return open;
  }

  @override
  Future<void> setStatus({
    required String id,
    required String status,
    String? closingNote,
    String? closedAtVisitId,
  }) async {
    closed.add((id, status, closedAtVisitId));
    items.removeWhere((item) => item.id == id);
  }

  int byUrgencyOf(LocalActionItem a, LocalActionItem b) {
    final left = a.state.daysUntilDue;
    final right = b.state.daysUntilDue;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }
}
