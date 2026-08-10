import 'package:flutter/material.dart';

import '../../core/utils/action_item_state.dart';
import '../../data/repositories/mentorship_repository.dart';
import '../../data/services/mentorship_catalogue.dart';

/// Recording the coaching given, then handing the phone over to be scored.
///
/// Two halves with different authors, and the screen says so out loud:
///
///  - The agent writes what they coached on.
///  - The GROUP scores it. An agent rating their own session gives 4 or 5 every
///    time and the aggregate means nothing; the representative is already
///    holding the phone for the sign-off PIN, so asking them costs nothing.
///
/// Everything is written as it is entered and works with no signal.
class VisitMentorshipScreen extends StatefulWidget {
  const VisitMentorshipScreen({
    super.key,
    required this.visitId,
    required this.groupName,
    required this.mentorship,
    this.catalogue,
  });

  final String visitId;
  final String groupName;
  final MentorshipRepository mentorship;
  final MentorshipCatalogueStore? catalogue;

  @override
  State<VisitMentorshipScreen> createState() => _VisitMentorshipScreenState();
}

class _VisitMentorshipScreenState extends State<VisitMentorshipScreen> {
  late final MentorshipCatalogueStore _catalogue =
      widget.catalogue ?? MentorshipCatalogueStore();

  MentorshipCatalogue? _lists;
  Map<String, LocalMentorshipSession> _sessions = {};
  Map<String, int> _scores = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lists = await _catalogue.load();
    final sessions = await widget.mentorship.sessionsFor(widget.visitId);
    final ratings = await widget.mentorship.ratingsFor(widget.visitId);

    if (!mounted) return;
    setState(() {
      _lists = lists;
      _sessions = {for (final session in sessions) session.topicKey: session};
      _scores = {for (final rating in ratings) rating.dimensionKey: rating.score};
      _loading = false;
    });
  }

  Future<void> _toggleTopic(MentorshipEntry topic) async {
    if (_sessions.containsKey(topic.key)) {
      await widget.mentorship
          .removeSession(visitId: widget.visitId, topicKey: topic.key);
    } else {
      await widget.mentorship.recordSession(
        visitId: widget.visitId,
        topicKey: topic.key,
        topicTitle: topic.title,
      );
    }
    await _load();
  }

  Future<void> _setNotes(MentorshipEntry topic, String notes) async {
    await widget.mentorship.recordSession(
      visitId: widget.visitId,
      topicKey: topic.key,
      topicTitle: topic.title,
      notes: notes.trim().isEmpty ? null : notes.trim(),
    );
    await _load();
  }

  Future<void> _score(MentorshipEntry dimension, int score) async {
    await widget.mentorship.recordRating(
      visitId: widget.visitId,
      dimensionKey: dimension.key,
      score: score,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mentorship')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lists = _lists!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mentorship')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('What did you coach on?', style: theme.textTheme.titleMedium),
          Text(
            'Tap a topic to record it, then add what you advised.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final topic in lists.topics)
            _TopicTile(
              topic: topic,
              session: _sessions[topic.key],
              onToggle: () => _toggleTopic(topic),
              onNotes: (notes) => _setNotes(topic, notes),
            ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.pan_tool_alt_outlined,
                        size: 18,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Now hand the phone to the group',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "These answers are the group's, not yours. Let an official "
                    'tap them.',
                    // Set explicitly against the container. Left at its default
                    // muted grey this was dark grey on saturated green —
                    // legible enough on a desk, and not at all on a handset in
                    // sunlight, which is the only place it is ever read.
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final dimension in lists.dimensions)
            _RatingTile(
              dimension: dimension,
              score: _scores[dimension.key],
              onScore: (score) => _score(dimension, score),
            ),
          const SizedBox(height: 16),
          Text(
            _scores.isEmpty
                ? 'Not scored yet. A visit can be recorded without it, but the '
                    'group\'s view is the only useful measure of the coaching.'
                : 'Scored on ${_scores.length} of ${lists.dimensions.length}.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            // Nothing is submitted here — it is already on disk. The visit's own
            // Finish step is what queues the whole document.
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatefulWidget {
  const _TopicTile({
    required this.topic,
    required this.session,
    required this.onToggle,
    required this.onNotes,
  });

  final MentorshipEntry topic;
  final LocalMentorshipSession? session;
  final VoidCallback onToggle;
  final ValueChanged<String> onNotes;

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile> {
  late final TextEditingController _notes =
      TextEditingController(text: widget.session?.notes ?? '');

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.session != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: (_) => widget.onToggle(),
            title: Text(widget.topic.title),
            subtitle: widget.topic.description == null
                ? null
                : Text(widget.topic.description!,
                    style: Theme.of(context).textTheme.bodySmall),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'What you advised',
                  alignLabelWithHint: true,
                ),
                // Saved when the field loses focus rather than on every
                // keystroke: an agent typing a paragraph should not cause a
                // database write per character on a low-end handset.
                onTapOutside: (_) => widget.onNotes(_notes.text),
                onSubmitted: widget.onNotes,
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.dimension,
    required this.score,
    required this.onScore,
  });

  final MentorshipEntry dimension;
  final int? score;
  final ValueChanged<int> onScore;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dimension.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            // Wrap, not Row: five chips plus labels overflow a 320px screen,
            // which is the handset these are actually answered on.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var value = minMentorshipRating;
                    value <= maxMentorshipRating;
                    value++)
                  ChoiceChip(
                    label: Text('$value'),
                    selected: score == value,
                    onSelected: (_) => onScore(value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
