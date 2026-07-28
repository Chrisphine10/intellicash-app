import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../dashboard/widgets/stat_card.dart';

/// Live, read-only view of the tenant's real data on the IntelliCash backend:
/// the selected group's fund balances, credit score, roster and meetings —
/// everything a MOBILE_CORE key is allowed to read.
class CloudDashboardScreen extends StatefulWidget {
  const CloudDashboardScreen({super.key});

  @override
  State<CloudDashboardScreen> createState() => _CloudDashboardScreenState();
}

class _CloudDashboardScreenState extends State<CloudDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ConnectionProvider>().refreshAll(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final group = connection.selectedGroup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: connection.busy
                ? null
                : () => context.read<ConnectionProvider>().refreshAll(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ConnectionProvider>().refreshAll(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (connection.busy && group == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (connection.groups.length > 1)
              _GroupSelector(connection: connection),
            if (group != null) ...[
              Text(group.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                '${group.code} · ${group.county} · Cycle ${group.cycleNumber}'
                '${group.creditScore != null ? ' · Credit score ${group.creditScore}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SectionLabel('Fund balances'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  StatCard(
                    value: Formatters.moneyCompact(group.savingsBalance),
                    label: 'Savings Fund',
                    icon: Icons.savings_outlined,
                  ),
                  StatCard(
                    value: Formatters.moneyCompact(group.internalLoanBalance),
                    label: 'Internal Loans',
                    icon: Icons.payments_outlined,
                  ),
                  StatCard(
                    value: Formatters.moneyCompact(group.socialFundBalance),
                    label: 'Social Fund',
                    icon: Icons.favorite_outline,
                  ),
                  StatCard(
                    value: '${group.memberCount ?? connection.members.length}',
                    label: 'Members',
                    icon: Icons.people_outline,
                  ),
                ],
              ),
            ],
            _MembersSection(connection: connection),
            _MeetingsSection(connection: connection),
            _NotificationsSection(connection: connection),
          ],
        ),
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({required this.connection});

  final ConnectionProvider connection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: connection.selectedGroup?.id,
        decoration: const InputDecoration(labelText: 'Group'),
        dropdownColor: AppColors.surfaceRaised,
        items: [
          for (final g in connection.groups)
            DropdownMenuItem(
              value: g.id,
              child: Text(g.name, style: const TextStyle(fontSize: 14)),
            ),
        ],
        onChanged: connection.busy
            ? null
            : (id) {
                if (id != null) {
                  context.read<ConnectionProvider>().selectGroup(id);
                }
              },
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.connection});

  final ConnectionProvider connection;

  @override
  Widget build(BuildContext context) {
    final members = connection.members;
    if (members.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Members · ${members.length}'),
        for (final m in members.take(30))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: MemberAvatar(m.fullName),
              title: Text(m.fullName,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${m.roleLabel}${m.phone != null ? ' · ${m.phone}' : ''}',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              trailing: Icon(
                m.isActive ? Icons.check_circle : Icons.remove_circle_outline,
                size: 18,
                color: m.isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _MeetingsSection extends StatelessWidget {
  const _MeetingsSection({required this.connection});

  final ConnectionProvider connection;

  @override
  Widget build(BuildContext context) {
    final meetings = connection.meetings;
    if (meetings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Meetings'),
        for (final meeting in meetings.take(15))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              title: Text(meeting.title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                meeting.scheduledAt != null
                    ? Formatters.fullDate(meeting.scheduledAt!)
                    : meeting.status,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              trailing: Text(
                meeting.status,
                style: TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.connection});

  final ConnectionProvider connection;

  @override
  Widget build(BuildContext context) {
    final items = connection.notifications.items;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Notifications'
          '${connection.unreadNotifications > 0 ? ' · ${connection.unreadNotifications} unread' : ''}',
        ),
        for (final n in items.take(10))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Icon(
                n.isUnread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
                size: 18,
                color: n.isUnread ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(n.title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                n.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}
