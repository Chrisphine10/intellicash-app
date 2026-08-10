import 'package:flutter/material.dart';

import '../../core/utils/action_item_state.dart';
import '../../data/repositories/mentorship_repository.dart';

/// What the group still owes from last time, shown at the START of a visit.
///
/// This is the whole point of the action plan. A commitment recorded at one
/// visit and not surfaced at the next is a note in a database nobody reads;
/// surfacing it before the agent begins is the difference between a follow-up
/// and repeating last month's conversation.
///
/// It reads from the LOCAL cache, never the network. The moment it matters is
/// the moment an agent walks up to a group, which is usually somewhere with no
/// signal — an item that needs a request to appear would appear exactly when it
/// is not needed.
class OpenActionItemsCard extends StatefulWidget {
  const OpenActionItemsCard({
    super.key,
    required this.remoteGroupId,
    required this.visitId,
    required this.mentorship,
    this.onChanged,
  });

  final String remoteGroupId;

  /// The visit being recorded, so closing an item records where it was closed.
  final String visitId;
  final MentorshipRepository mentorship;
  final VoidCallback? onChanged;

  @override
  State<OpenActionItemsCard> createState() => _OpenActionItemsCardState();
}

class _OpenActionItemsCardState extends State<OpenActionItemsCard> {
  List<LocalActionItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.mentorship.openItemsFor(widget.remoteGroupId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _close(LocalActionItem item) async {
    await widget.mentorship.setStatus(
      id: item.id,
      status: 'DONE',
      closedAtVisitId: widget.visitId,
    );
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final theme = Theme.of(context);

    if (_items.isEmpty) {
      // Said out loud rather than hidden. "Nothing outstanding" is information
      // an agent wants; an absent card just looks like a feature that failed.
      return Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: const Text('Nothing outstanding'),
          subtitle: Text(
            'This group has no open actions from previous visits.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    final overdue = _items.where((item) => item.state.state == ActionItemState.overdue).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_late_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'From the last visit',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              overdue > 0
                  ? '${_items.length} still open, $overdue overdue. Go through these first.'
                  : '${_items.length} still open.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final item in _items) _ActionRow(item: item, onDone: () => _close(item)),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item, required this.onDone});

  final LocalActionItem item;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = item.state;
    final late = state.state == ActionItemState.overdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.textTheme.bodyMedium),
                Text(
                  [
                    if (item.owner != null) item.owner,
                    late
                        ? '${state.daysOverdue} days overdue'
                        : state.dueDate == null
                            ? 'No date'
                            : state.label,
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: late ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}
