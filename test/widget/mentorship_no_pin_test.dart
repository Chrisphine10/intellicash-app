import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intellicash_mobile/data/repositories/mentorship_repository.dart';
import 'package:intellicash_mobile/data/services/mentorship_catalogue.dart';
import 'package:intellicash_mobile/features/visits/visit_mentorship_screen.dart';
import 'package:intellicash_mobile/shared/widgets/numeric_keypad.dart';

/// Coaching is scored by asking a person, not by authenticating one.
///
/// The group's 4-digit visit PIN was removed, but the reason this screen hands
/// the phone over was written as "the representative is already holding it for
/// the sign-off PIN". A rationale that outlives its mechanism is how the
/// mechanism comes back, so the property is pinned here rather than left to a
/// comment: nothing in this flow may ask for a PIN.
///
/// The repository is faked in memory, following the house pattern — a widget
/// test runs in a fake-async zone where real sqflite never completes, so a
/// screen backed by the real one would sit unloaded until the test timed out.
void main() {
  late _FakeMentorshipRepository mentorship;

  setUp(() => mentorship = _FakeMentorshipRepository());

  final catalogue = _FakeCatalogueStore();

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VisitMentorshipScreen(
          visitId: 'visit-1',
          groupName: 'Demo Test VSLA',
          mentorship: mentorship,
          catalogue: catalogue,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks for no PIN anywhere', (tester) async {
    await pump(tester);

    // No keypad, and no obscured field standing in for one.
    expect(find.byType(NumericKeypad), findsNothing);
    final obscured = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.obscureText);
    expect(obscured, isEmpty);

    // And nothing that asks for one in words.
    for (final word in ['PIN', 'passcode', 'Unlock', 'unlock']) {
      expect(find.textContaining(word), findsNothing, reason: 'found "$word"');
    }
  });

  testWidgets('renders the topics and the rating questions', (tester) async {
    await pump(tester);
    expect(find.text('Record keeping'), findsOneWidget);
    expect(find.text('Was the advice clear?'), findsOneWidget);
  });
}

class _FakeMentorshipRepository extends MentorshipRepository {
  // Already scoped by the query, so the fake keeps one visit's worth.
  final List<LocalMentorshipSession> sessions = [];
  final List<LocalRating> ratings = [];

  @override
  Future<List<LocalMentorshipSession>> sessionsFor(String visitId) async =>
      sessions;

  @override
  Future<List<LocalRating>> ratingsFor(String visitId) async => ratings;
}

/// Returns a fixed list without touching SharedPreferences or the network.
class _FakeCatalogueStore extends MentorshipCatalogueStore {
  @override
  Future<MentorshipCatalogue> load() async => const MentorshipCatalogue(
        topics: [
          MentorshipEntry(key: 'record_keeping', title: 'Record keeping'),
          MentorshipEntry(key: 'governance', title: 'Governance and leadership'),
        ],
        dimensions: [
          MentorshipEntry(key: 'clarity', title: 'Was the advice clear?'),
          MentorshipEntry(key: 'usefulness', title: 'Was it useful to the group?'),
        ],
      );
}
