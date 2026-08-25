import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/poll_models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../providers/poll_provider.dart';
import '../../shared/widgets/common.dart';
import '../server/server_settings_screen.dart';
import 'create_poll_sheet.dart';
import 'poll_detail_screen.dart';

/// Voting — every election and decision the group has taken, newest first.
/// Votes belong to meetings: the group opens one at the table, everyone
/// present votes, and closing it writes the result into the minute book.
class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key, this.meetingId});

  /// When opened from inside a meeting, new votes are tied to that meeting.
  final String? meetingId;

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final connection = context.read<ConnectionProvider>();
    final groupId = connection.selectedGroup?.id;
    if (!connection.isConnected || groupId == null) return;
    await context.read<PollProvider>().load(groupId);
  }

  Future<void> _newVote() async {
    final groupId = context.read<ConnectionProvider>().selectedGroup?.id;
    if (groupId == null) {
      showAppSnack(context, 'Choose a group first.', error: true);
      return;
    }
    await showCreatePollSheet(context,
        groupId: groupId, meetingId: widget.meetingId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connected = context.watch<ConnectionProvider>().isConnected;
    final provider = context.watch<PollProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.meetingHubVoting)),
      floatingActionButton: connected
          ? FloatingActionButton.extended(
              onPressed: _newVote,
              icon: const Icon(Icons.how_to_vote_outlined),
              label: Text(l10n.pollsNewVote),
            )
          : null,
      body: !connected
          ? _NeedsConnection()
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                children: [
                  Text(l10n.pollsGroupVotes,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    l10n.pollsElectYourLeadersAndDecideTogether,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  if (provider.loading && provider.polls.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (provider.error != null && provider.polls.isEmpty)
                    EmptyState(
                      icon: Icons.how_to_vote_outlined,
                      title: l10n.pollsCouldNotLoadTheVotes,
                      message: provider.error!,
                    ),
                  if (!provider.loading &&
                      provider.error == null &&
                      provider.polls.isEmpty)
                    EmptyState(
                      icon: Icons.how_to_vote_outlined,
                      title: l10n.pollsNoVotesYet,
                      message: l10n.pollsTapNewVoteToElectA,
                    ),
                  for (final poll in provider.polls) _PollCard(poll: poll),
                ],
              ),
            ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll});

  final RemotePoll poll;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PollDetailScreen(pollId: poll.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      poll.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PollStatusPill(poll: poll),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  PollTypeChip(poll: poll),
                  const SizedBox(width: 8),
                  Icon(Icons.people_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    poll.totalVotes == 1
                        ? '1 vote cast'
                        : '${poll.totalVotes} votes cast',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  if (poll.secretBallot) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.visibility_off_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(l10n.pollsSecret,
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ],
              ),
              if (poll.isOpen && poll.hasVoted) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(l10n.pollsYouHaveVoted,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ],
              if (poll.isClosed && poll.resultSummary != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    poll.resultSummary!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
              ],
              if (poll.createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  Formatters.shortDate(poll.createdAt!),
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `Election` / `Decision` chip.
class PollTypeChip extends StatelessWidget {
  const PollTypeChip({super.key, required this.poll});

  final RemotePoll poll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: AppColors.surfaceRaised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            poll.isElection ? Icons.emoji_events_outlined : Icons.gavel_outlined,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            poll.typeLabel,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// `Open` (green) / `Closed` (grey) pill.
class PollStatusPill extends StatelessWidget {
  const PollStatusPill({super.key, required this.poll});

  final RemotePoll poll;

  @override
  Widget build(BuildContext context) {
    final color = poll.isOpen ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: color.withValues(alpha: 0.13),
      ),
      child: Text(
        poll.statusLabel,
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _NeedsConnection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_vote_outlined,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(l10n.pollsConnectToVote,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              l10n.pollsVotingIsKeptOnTheIntelli,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ServerSettingsScreen()),
              ),
              child: Text(l10n.storeOpenCloudAccount),
            ),
          ],
        ),
      ),
    );
  }
}
