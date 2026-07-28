import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/connection_provider.dart';
import '../../providers/poll_provider.dart';
import '../../shared/widgets/common.dart';

/// Offices a group elects, in plain language.
const Map<String, String> kElectableRoles = {
  'CHAIRPERSON': 'Chairperson',
  'SECRETARY': 'Secretary',
  'TREASURER': 'Treasurer',
  'MEMBER': 'Member',
};

/// Opens the "start a vote" sheet for [groupId]. When [meetingId] is given
/// the vote is tied to that meeting.
Future<void> showCreatePollSheet(
  BuildContext context, {
  required String groupId,
  String? meetingId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CreatePollSheet(groupId: groupId, meetingId: meetingId),
  );
}

/// Start a new vote: either elect someone to an office, or put a question to
/// the group. Deliberately short — a group starts this at the meeting table.
class CreatePollSheet extends StatefulWidget {
  const CreatePollSheet({super.key, required this.groupId, this.meetingId});

  final String groupId;
  final String? meetingId;

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();

  bool _isElection = true;
  String _role = 'CHAIRPERSON';
  final Set<String> _candidateIds = {};

  /// Free-text answers for a decision. Yes / No is what most groups want.
  final List<TextEditingController> _answerCtrls = [
    TextEditingController(text: 'Yes'),
    TextEditingController(text: 'No'),
  ];

  bool _secretBallot = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final controller in _answerCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The election question writes itself once a role is picked.
  String get _electionTitle =>
      'Who should be ${kElectableRoles[_role]?.toLowerCase() ?? 'chosen'}?';

  @override
  Widget build(BuildContext context) {
    // Candidates come from the connected group's members — the server needs
    // the backend's own member ids to record a candidacy.
    final members = context
        .watch<ConnectionProvider>()
        .members
        .where((m) => m.isActive)
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Start a Vote',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                'Everyone present votes once. Nobody can vote twice.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.emoji_events_outlined, size: 16),
                    label: Text('Choose a leader'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.gavel_outlined, size: 16),
                    label: Text('Decide something'),
                  ),
                ],
                selected: {_isElection},
                onSelectionChanged: (s) =>
                    setState(() => _isElection = s.first),
              ),
              const SizedBox(height: 16),
              if (_isElection) ...[
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                      labelText: 'Which position?'),
                  dropdownColor: AppColors.surfaceRaised,
                  items: [
                    for (final entry in kElectableRoles.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value,
                            style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'CHAIRPERSON'),
                ),
                const SizedBox(height: 14),
                Text(_electionTitle,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SectionLabel('Who is standing?'),
                if (members.isEmpty)
                  Text(
                    'No members loaded for this group yet. Connect and open '
                    'the group first.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final member in members)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            value: _candidateIds.contains(member.id),
                            title: Text(member.fullName,
                                style: const TextStyle(fontSize: 13.5)),
                            subtitle: Text(member.roleLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _candidateIds.add(member.id);
                              } else {
                                _candidateIds.remove(member.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Tick at least two people.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What is the question?',
                    hintText: 'Should we buy a group water tank?',
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Write the question'
                      : null,
                ),
                const SectionLabel('Answers'),
                for (var i = 0; i < _answerCtrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _answerCtrls[i],
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                                labelText: 'Answer ${i + 1}'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Write an answer or remove it'
                                : null,
                          ),
                        ),
                        if (_answerCtrls.length > 2)
                          IconButton(
                            tooltip: 'Remove',
                            icon: Icon(Icons.close,
                                size: 18, color: AppColors.textSecondary),
                            onPressed: () => setState(() {
                              _answerCtrls.removeAt(i).dispose();
                            }),
                          ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _answerCtrls.length >= 10
                        ? null
                        : () => setState(
                            () => _answerCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add another answer'),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _secretBallot,
                title: const Text('Secret vote',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Nobody sees who voted for what. The counts are still '
                  'shown to everyone.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                onChanged: (v) => setState(() => _secretBallot = v),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _create,
                icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                label: const Text('Open the Vote'),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final List<Map<String, dynamic>> options;
    final String title;
    if (_isElection) {
      if (_candidateIds.length < 2) {
        showAppSnack(context, 'Tick at least two people to stand.',
            error: true);
        return;
      }
      title = _electionTitle;
      options = [
        for (final id in _candidateIds) {'memberId': id},
      ];
    } else {
      final answers = _answerCtrls
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (answers.length < 2) {
        showAppSnack(context, 'Give at least two answers.', error: true);
        return;
      }
      title = _titleCtrl.text.trim();
      options = [
        for (final answer in answers) {'label': answer},
      ];
    }

    setState(() => _saving = true);
    final provider = context.read<PollProvider>();
    try {
      await provider.createPoll(
        groupId: widget.groupId,
        type: _isElection ? 'ROLE_ELECTION' : 'DECISION',
        title: title,
        targetRole: _isElection ? _role : null,
        meetingId: widget.meetingId,
        secretBallot: _secretBallot,
        options: options,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'The vote is open. Everyone can vote now.');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
