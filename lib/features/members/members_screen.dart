import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import 'add_member_sheet.dart';
import 'join_requests_screen.dart';
import 'member_detail_screen.dart';

/// Member directory: every member with their live savings and loan position.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _query = '';

  /// People waiting to be let into the group. Surfaced as a badge so requests
  /// don't sit unanswered.
  ///
  /// Null means "not known" - offline, or the count request failed. That is a
  /// different thing from zero, and the difference decides whether the badge
  /// shows a number, not whether the way in exists at all.
  int? _pendingJoins;

  /// The sync this list was last loaded after — a sync can add members the
  /// server admitted, so the list reloads when one finishes.
  int _loadedRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final group = context.read<AppState>().group;
    if (group == null) return;
    await context.read<MemberProvider>().load(group.id);
    await _loadPendingJoins();
  }

  Future<void> _loadPendingJoins() async {
    final connection = context.read<ConnectionProvider>();
    final remoteGroup = connection.selectedGroup;
    if (remoteGroup == null) return;
    try {
      final requests = await connection.api.joinRequests(remoteGroup.id);
      if (mounted) setState(() => _pendingJoins = requests.length);
    } catch (_) {
      // Offline, or a login without members:write. The count is unknown; the
      // action stays, because an official who cannot see a badge still has to
      // be able to go and look.
      if (mounted) setState(() => _pendingJoins = null);
    }
  }

  Future<void> _openJoinRequests() async {
    final remoteGroup = context.read<ConnectionProvider>().selectedGroup;
    if (remoteGroup == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JoinRequestsScreen(groupId: remoteGroup.id),
      ),
    );
    await _loadPendingJoins();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final group = appState.group;
    final provider = context.watch<MemberProvider>();
    if (appState.syncRevision != _loadedRevision) {
      final first = _loadedRevision == -1;
      _loadedRevision = appState.syncRevision;
      // The first build already loads in initState.
      if (!first) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      }
    }
    // The persisted role, so this is right at cold start with no coverage.
    final isGroupAccount =
        context.watch<ConnectionProvider>().account?.isGroupAccount == true;
    final members = provider.members
        .where((f) =>
            _query.isEmpty ||
            f.member.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMembers),
        actions: [
          // Always present for a group account, badge or no badge. It used to
          // appear only when the count was above zero AND the request for it
          // had succeeded, so an official who wanted to check found nothing to
          // tap and no way to know whether that meant "none" or "offline".
          if (isGroupAccount)
            IconButton(
              tooltip: l10n.membersRequestsToJoin,
              onPressed: _openJoinRequests,
              // The badge's own text ("2") used to replace the button's spoken
              // name, so a screen reader said just "2".
              icon: (_pendingJoins ?? 0) > 0
                  ? Semantics(
                      label: '${l10n.membersRequestsToJoin}: $_pendingJoins',
                      excludeSemantics: true,
                      child: Badge(
                        label: Text('$_pendingJoins'),
                        child: const Icon(Icons.person_add_alt, size: 20),
                      ),
                    )
                  : const Icon(Icons.person_add_alt, size: 20),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addMemberAddMember,
        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddMemberSheet(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        // Pull to refresh does the same run as reconnecting: send this phone's
        // members up, bring the server's down, then show the result.
        onRefresh: () async {
          if (context.read<ConnectionProvider>().hasSession) {
            await appState.syncService.pushNow();
          }
          await _load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
          children: [
            Text(l10n.navMembers, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              '${provider.members.length} active · ${group?.name ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: l10n.membersSearchMembers,
                prefixIcon: Icon(Icons.search,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            if (members.isEmpty && !provider.loading)
              EmptyState(
                icon: Icons.people_outline,
                title: l10n.membersNoMembersFound,
                // Searching and finding nothing is not "you have no members".
                message: _query.isEmpty
                    ? l10n.membersAddMembersWithTheButtonBelow
                    : 'Nobody matches "$_query". Check the spelling, or clear the search.',
              ),
            for (final financials in members)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: MemberAvatar(financials.member.name),
                  title: Text(
                    financials.member.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Savings ${Formatters.moneyCompact(financials.totalSavings)} · '
                    '${financials.hasActiveLoan ? 'Loan ${Formatters.moneyCompact(financials.activeLoanBalance)}' : 'No active loan'}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: financials.hasDefaultedLoan
                      ? StatusChip.loan(LoanStatus.defaulted)
                      : financials.hasActiveLoan
                          ? StatusChip.loan(LoanStatus.active)
                          : null,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemberDetailScreen(
                            memberId: financials.member.id),
                      ),
                    );
                    await _load();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
