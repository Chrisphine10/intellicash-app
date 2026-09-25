import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../members/invite_screen.dart';
import '../members/join_requests_screen.dart';
import 'more_tiles.dart';

/// Two halves of one job: hand out the group's invite link, then answer the
/// requests that come back. One row on More opens both.
class InviteAndRequestsScreen extends StatefulWidget {
  const InviteAndRequestsScreen({super.key});

  @override
  State<InviteAndRequestsScreen> createState() => _InviteAndRequestsScreenState();
}

class _InviteAndRequestsScreenState extends State<InviteAndRequestsScreen> {
  int? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCount());
  }

  /// A courtesy only: it decorates the row and never gates it.
  Future<void> _loadCount() async {
    final count = await pendingJoinRequests(context.read<ConnectionProvider>());
    if (mounted) setState(() => _pending = count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final group = context.watch<ConnectionProvider>().selectedGroup;
    final pending = _pending;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreInviteAndRequests)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: group != null,
                  leading: const Icon(Icons.qr_code_2_rounded, size: 20),
                  title: Text(l10n.inviteTitle, style: moreTileTitleStyle),
                  subtitle: Text(l10n.inviteTileSubtitle, style: Theme.of(context).textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: group == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => InviteScreen(groupId: group.id)),
                          ),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  enabled: group != null,
                  leading: const Icon(Icons.how_to_reg_outlined, size: 20),
                  title: Text(l10n.joinRequestsTileTitle, style: moreTileTitleStyle),
                  subtitle: Text(
                    joinRequestsSummary(l10n, pending),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: CountChevron(count: pending),
                  onTap: group == null
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => JoinRequestsScreen(groupId: group.id)),
                          );
                          await _loadCount();
                        },
                ),
              ],
            ),
          ),
          if (group == null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l10n.moreLockedSignIn, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// How many people are waiting to join, or null when it cannot be known now.
Future<int?> pendingJoinRequests(ConnectionProvider connection) async {
  final group = connection.selectedGroup;
  if (group == null) return null;
  try {
    return (await connection.api.joinRequests(group.id)).length;
  } catch (_) {
    return null;
  }
}

String joinRequestsSummary(L10n l10n, int? pending) => pending == null
    ? l10n.joinRequestsTileSubtitle
    : pending == 0
        ? l10n.joinRequestsNoneWaiting
        : pending == 1
            ? l10n.joinRequestsOneWaiting
            : l10n.joinRequestsWaitingCount(pending);
