import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/poll_models.dart';
import '../../data/models/remote/remote_models.dart';
import '../../providers/connection_provider.dart';
import '../../providers/poll_provider.dart';
import '../../shared/widgets/common.dart';
import 'polls_screen.dart';

/// One vote in full: the question, every choice with its live tally, and the
/// button to cast your ballot. A closed vote is read-only and shows only the
/// result the group agreed on.
class PollDetailScreen extends StatefulWidget {
  const PollDetailScreen({super.key, required this.pollId});

  final String pollId;

  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  String? _selectedOptionId;

  /// Which member the ballot is being recorded for. A member signed in on
  /// their own phone is always themselves; the shared group tablet must say
  /// who is voting.
  String? _votingMemberId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PollProvider>().refreshPoll(widget.pollId);
    });
  }

  RemotePoll? get _poll => context.watch<PollProvider>().byId(widget.pollId);

  Future<void> _castVote(RemotePoll poll, String? ownMemberId) async {
    final optionId = _selectedOptionId;
    if (optionId == null) {
      showAppSnack(context, 'Choose one first, then cast your vote.',
          error: true);
      return;
    }
    final memberId = ownMemberId ?? _votingMemberId;
    if (memberId == null) {
      showAppSnack(context, 'Say which member is voting.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context
          .read<PollProvider>()
          .vote(poll.id, optionId, memberId: memberId);
      if (!mounted) return;
      setState(() {
        _selectedOptionId = null;
        _votingMemberId = null;
      });
      showAppSnack(context, 'Vote recorded. Thank you.');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmClose(RemotePoll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close this vote?', style: TextStyle(fontSize: 17)),
        content: const Text(
          'No more votes can be cast after this, and the result is written '
          'into the group records. This cannot be undone.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Open'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.defaulted,
              foregroundColor: const Color(0xFF3A0D09),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Close Vote'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final closed = await context.read<PollProvider>().close(poll.id);
      if (!mounted) return;
      showAppSnack(context, closed.resultSummary ?? 'Vote closed.');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final poll = _poll;

    if (poll == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vote')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ownMemberId = connection.signedInUser?.memberId;
    // The shared group tablet has no member identity of its own, so it both
    // records other members' ballots and closes the vote.
    final isGroupAccount = ownMemberId == null;
    final members =
        connection.members.where((m) => m.isActive).toList(growable: false);
    final alreadyVoted = poll.hasVoted && !isGroupAccount;

    return Scaffold(
      appBar: AppBar(title: const Text('Vote')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<PollProvider>().refreshPoll(poll.id);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Row(
              children: [
                PollTypeChip(poll: poll),
                const SizedBox(width: 8),
                PollStatusPill(poll: poll),
              ],
            ),
            const SizedBox(height: 10),
            Text(poll.title,
                style: Theme.of(context).textTheme.headlineSmall),
            if (poll.description != null && poll.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(poll.description!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(
              [
                if (poll.isElection && poll.targetRoleLabel != null)
                  'For the position of ${poll.targetRoleLabel}',
                poll.totalVotes == 1
                    ? '1 vote cast'
                    : '${poll.totalVotes} votes cast',
                if (poll.secretBallot) 'Secret ballot',
                if (poll.meetingTitle != null) poll.meetingTitle!,
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (poll.isClosed) _ResultBanner(poll: poll),
            const SectionLabel('Choices'),
            for (final option in poll.options)
              _OptionRow(
                poll: poll,
                option: option,
                selected: _selectedOptionId == option.id,
                myChoice: poll.myVote == option.id,
                enabled: poll.isOpen && !alreadyVoted && !_busy,
                onTap: () => setState(() => _selectedOptionId = option.id),
              ),
            if (poll.isOpen) ...[
              const SizedBox(height: 6),
              if (alreadyVoted)
                _VotedNote(secret: poll.secretBallot)
              else ...[
                if (isGroupAccount) ...[
                  const SectionLabel('Who is voting?'),
                  _MemberPicker(
                    members: members,
                    value: _votingMemberId,
                    onChanged: (id) => setState(() => _votingMemberId = id),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  onPressed:
                      _busy ? null : () => _castVote(poll, ownMemberId),
                  icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                  label: Text(isGroupAccount ? 'Record Vote' : 'Cast My Vote'),
                ),
              ],
              if (isGroupAccount) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.defaulted,
                    side: BorderSide(
                        color: AppColors.defaulted.withValues(alpha: 0.4)),
                  ),
                  onPressed: _busy ? null : () => _confirmClose(poll),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Close Vote'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Closing counts the votes and writes the result into the '
                  'group records.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            if (poll.isClosed && poll.closedAt != null) ...[
              const SizedBox(height: 14),
              Text(
                'Closed on ${Formatters.fullDate(poll.closedAt!)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The frozen outcome, shown at the top of a closed vote.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.poll});

  final RemotePoll poll;

  @override
  Widget build(BuildContext context) {
    final tie = poll.isTie;
    final color = tie ? AppColors.pending : AppColors.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tie ? Icons.balance : Icons.verified_outlined,
              size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              poll.resultSummary ?? 'This vote is closed.',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice: name, tally count and a proportion bar.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.poll,
    required this.option,
    required this.selected,
    required this.myChoice,
    required this.enabled,
    required this.onTap,
  });

  final RemotePoll poll;
  final RemotePollOption option;
  final bool selected;
  final bool myChoice;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final winning = poll.isClosed && poll.isWinning(option);
    final highlight = selected || myChoice || winning;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlight ? AppColors.primary : AppColors.outline,
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : myChoice || winning
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                    size: 18,
                    color: highlight
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                highlight ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (myChoice) ...[
                          const SizedBox(height: 1),
                          Text('Your choice',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ] else if (option.memberRoleLabel != null &&
                            option.memberId != null) ...[
                          const SizedBox(height: 1),
                          Text(option.memberRoleLabel!,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    option.voteCount == 1
                        ? '1 vote'
                        : '${option.voteCount} votes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: highlight
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: poll.share(option),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceRaised,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VotedNote extends StatelessWidget {
  const _VotedNote({required this.secret});

  final bool secret;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                secret
                    ? 'You have voted. This is a secret ballot, so your '
                        'choice is not shown to anyone.'
                    : 'You have voted. Each member votes once.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown of the group's active members, for the shared tablet recording
/// someone's ballot at the meeting table.
class _MemberPicker extends StatelessWidget {
  const _MemberPicker({
    required this.members,
    required this.value,
    required this.onChanged,
  });

  final List<RemoteMember> members;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'No members loaded for this group yet.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Member casting this vote',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final member in members)
          DropdownMenuItem(
            value: member.id,
            child: Text(member.fullName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
