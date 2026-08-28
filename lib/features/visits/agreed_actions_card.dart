import 'package:flutter/material.dart';

import '../../core/utils/action_item_state.dart';
import '../../l10n/app_localizations.dart';
import '../../data/repositories/mentorship_repository.dart';

/// What the group agreed to do, recorded at THIS visit.
///
/// `MentorshipRepository.raise()` was written, tested and wired into the sync
/// push, and had no caller anywhere in the app. An agent could close work
/// raised at a previous visit and could not record a single new commitment —
/// so the one thing a visit is supposed to produce had to be remembered, or
/// typed into the console by somebody who was not there.
///
/// Everything here is local-first. An agent agrees an action standing in a
/// field with no signal; the row is written to the phone, marked dirty, and
/// pushed by [MentorshipSyncService] when there is a network. Nothing on this
/// screen waits for a server.
///
/// Distinct from [OpenActionItemsCard], which shows what is outstanding for the
/// GROUP before the visit begins. This one is the visit's own output.
class AgreedActionsCard extends StatefulWidget {
  const AgreedActionsCard({
    super.key,
    required this.remoteGroupId,
    required this.visitId,
    required this.mentorship,
    this.onChanged,
  });

  final String remoteGroupId;

  /// The visit being recorded. Every action raised here belongs to it, which is
  /// what ties a commitment to the conversation that produced it.
  final String visitId;
  final MentorshipRepository mentorship;
  final VoidCallback? onChanged;

  @override
  State<AgreedActionsCard> createState() => _AgreedActionsCardState();
}

class _AgreedActionsCardState extends State<AgreedActionsCard> {
  List<LocalActionItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.mentorship.itemsForVisit(widget.visitId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final draft = await showModalBottomSheet<_ActionDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AgreeActionSheet(),
    );
    if (draft == null) return;

    await widget.mentorship.raise(
      visitId: widget.visitId,
      remoteGroupId: widget.remoteGroupId,
      title: draft.title,
      detail: draft.detail,
      owner: draft.owner,
      dueDate: draft.dueDate,
    );
    await _load();
    widget.onChanged?.call();
  }

  Future<void> _setStatus(LocalActionItem item, String status) async {
    await widget.mentorship.setStatus(
      id: item.id,
      status: status,
      // Only when closing. Reopening an item must not leave it claiming it was
      // finished at a visit in the past.
      closedAtVisitId: status == 'DONE' ? widget.visitId : null,
    );
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    if (_loading) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_add_check_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.agreedActionsTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _items.isEmpty
                  ? l10n.agreedActionsNothingYet
                  : l10n.agreedActionsRecordedCount(_items.length),
              style: theme.textTheme.bodySmall,
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in _items)
                _AgreedRow(
                  item: item,
                  onDone: () => _setStatus(item, 'DONE'),
                  onReopen: () => _setStatus(item, 'OPEN'),
                ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _add,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.agreedActionsAgreeAnAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreedRow extends StatelessWidget {
  const _AgreedRow({
    required this.item,
    required this.onDone,
    required this.onReopen,
  });

  final LocalActionItem item;
  final VoidCallback onDone;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final state = item.state;
    final open = state.state != ActionItemState.done &&
        state.state != ActionItemState.cancelled;
    final late = state.state == ActionItemState.overdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            open ? Icons.radio_button_unchecked : Icons.check_circle,
            size: 18,
            color: open ? theme.disabledColor : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: open ? null : TextDecoration.lineThrough,
                    color: open ? null : theme.disabledColor,
                  ),
                ),
                Text(
                  [
                    if (item.owner != null && item.owner!.isNotEmpty) item.owner!,
                    dueSummary(state, l10n),
                    // A row that has not reached the office yet says so, rather
                    // than looking identical to one that has.
                    if (item.isDirty) l10n.agreedActionsNotYetSent,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: late ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: open ? onDone : onReopen,
            child: Text(open ? l10n.joinGroupDone : l10n.agreedActionsReopen),
          ),
        ],
      ),
    );
  }
}

class _ActionDraft {
  const _ActionDraft({
    required this.title,
    this.detail,
    this.owner,
    this.dueDate,
  });

  final String title;
  final String? detail;
  final String? owner;
  final DateTime? dueDate;
}

/// The offices a VSLA actually has.
///
/// Chips rather than a free-text field, because an owner that names a ROLE
/// survives the person leaving the group — and because typing on a handset in
/// a field is the slowest thing an agent can be asked to do.
///
/// Stored in English and shown translated. An owner recorded in Dholuo has to
/// mean the same thing to the office reading it in the console, so the label
/// is a display concern and the value is not.
List<(String, String)> _owners(L10n l10n) => [
      ('Chairperson', l10n.actionOwnerChairperson),
      ('Secretary', l10n.actionOwnerSecretary),
      ('Treasurer', l10n.actionOwnerTreasurer),
      ('Money counter', l10n.actionOwnerMoneyCounter),
      ('Key holder', l10n.actionOwnerKeyHolder),
      ('The group', l10n.actionOwnerTheGroup),
    ];

class _AgreeActionSheet extends StatefulWidget {
  const _AgreeActionSheet();

  @override
  State<_AgreeActionSheet> createState() => _AgreeActionSheetState();
}

class _AgreeActionSheetState extends State<_AgreeActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _detail = TextEditingController();
  String? _owner;
  DateTime? _dueDate;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 30)),
      // A commitment made today cannot fall due yesterday.
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ActionDraft(
        title: _title.text.trim(),
        detail: _detail.text.trim().isEmpty ? null : _detail.text.trim(),
        owner: _owner,
        dueDate: _dueDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Padding(
      // The keyboard covers a bottom sheet on a short handset, which is most of
      // them. Padding by the inset keeps the field being typed into on screen.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.agreedActionsAgreeAnAction,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                l10n.agreedActionsSheetIntro,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.agreedActionsWhatWasAgreed,
                  hintText: l10n.agreedActionsWhatWasAgreedHint,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.agreedActionsNeedTitle
                    : null,
              ),
              const SizedBox(height: 8),
              Text(l10n.agreedActionsWhoIsResponsible,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (value, label) in _owners(l10n))
                    ChoiceChip(
                      label: Text(label),
                      selected: _owner == value,
                      onSelected: (selected) =>
                          setState(() => _owner = selected ? value : null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDue,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _dueDate == null
                      ? l10n.agreedActionsSetADate
                      : l10n.agreedActionsDueOn(formatDueDate(_dueDate!)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detail,
                maxLines: 3,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.agreedActionsDetailOptional,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(l10n.agreedActionsAddToThePlan),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
