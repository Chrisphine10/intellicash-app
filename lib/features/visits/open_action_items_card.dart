import 'package:flutter/material.dart';

import '../../core/utils/action_item_state.dart';
import '../../data/repositories/mentorship_repository.dart';
import '../../data/services/mentorship_sync_service.dart';
import '../../l10n/app_localizations.dart';

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
    this.remoteVisitId,
    this.sync,
    this.onChanged,
  });

  final String remoteGroupId;

  /// The visit being recorded, so closing an item records where it was closed.
  final String visitId;

  /// The same visit's server id, once it has one.
  ///
  /// A refresh rewrites a row's `visit_id` from the local id to this one, so
  /// filtering on the local id alone stops working the moment the visit syncs
  /// — and this card would start listing the visit's own work as though the
  /// group had owed it all along.
  final String? remoteVisitId;
  final MentorshipRepository mentorship;

  /// Pulls the server's items into the local cache when there is signal.
  ///
  /// Optional so the card can be tested without a network stack — but without
  /// it in the app, work raised at a previous visit never reaches this phone
  /// and the card reads "Nothing outstanding" forever.
  final MentorshipSyncService? sync;
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
    _loadThenRefresh();
  }

  /// Local first, then the network.
  ///
  /// The cached list renders immediately and is the only thing available in a
  /// field with no signal. A refresh, when it succeeds, fills in anything
  /// raised at a previous visit or by the office — without it the card is
  /// permanently empty for every item this phone did not itself create.
  Future<void> _loadThenRefresh() async {
    await _load();

    final sync = widget.sync;
    if (sync == null) return;
    final written = await sync.refreshOpenItems(widget.remoteGroupId);
    // Only re-read when something actually changed; a failed refresh (no
    // signal) leaves the cached list exactly as it was.
    if (written > 0 && mounted) await _load();
  }

  Future<void> _load() async {
    // This card answers "what did the group owe when this visit began", so
    // anything agreed during the visit itself belongs to the other card.
    final items = await widget.mentorship.openItemsFor(
      widget.remoteGroupId,
      excludingVisitIds: [widget.visitId, ?widget.remoteVisitId],
    );
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
    final l10n = L10n.of(context);
    if (_loading) return const SizedBox.shrink();

    final theme = Theme.of(context);

    if (_items.isEmpty) {
      // Said out loud rather than hidden. "Nothing outstanding" is information
      // an agent wants; an absent card just looks like a feature that failed.
      return Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: Text(l10n.openActionItemsNothingOutstanding),
          subtitle: Text(
            l10n.openActionItemsThisGroupHasNoOpen,
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
                    l10n.openActionItemsFromTheLastVisit,
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
    final l10n = L10n.of(context);
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
                    dueSummary(state, l10n),
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: late ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onDone, child: Text(l10n.joinGroupDone)),
        ],
      ),
    );
  }
}
