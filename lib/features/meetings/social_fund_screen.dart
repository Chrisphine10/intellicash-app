import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meeting.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';

/// Social-fund collection as a per-member checklist. The amount is the same
/// for everyone (the group's standing social-fund amount), so each member is
/// just a paid / not-paid toggle.
class SocialFundScreen extends StatefulWidget {
  const SocialFundScreen({super.key, required this.meeting});

  final Meeting meeting;

  @override
  State<SocialFundScreen> createState() => _SocialFundScreenState();
}

class _SocialFundScreenState extends State<SocialFundScreen> {
  Set<String> _paid = {};
  bool _loaded = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final memberProvider = context.read<MemberProvider>();
    final meetingProvider = context.read<MeetingProvider>();
    final group = context.read<AppState>().group;
    if (group != null) {
      await memberProvider.load(group.id);
    }
    final payers = await meetingProvider.socialFundPayers();
    if (!mounted) return;
    setState(() {
      _paid = payers;
      _loaded = true;
    });
  }

  Future<void> _toggle(String memberId, bool paid) async {
    final appState = context.read<AppState>();
    final provider = context.read<MeetingProvider>();
    final group = appState.group!;
    setState(() {
      _busy.add(memberId);
      if (paid) {
        _paid.add(memberId);
      } else {
        _paid.remove(memberId);
      }
    });
    try {
      await provider.setSocialFundPaid(
          group: group, memberId: memberId, paid: paid);
      await appState.refreshPendingSync();
    } on DomainException catch (e) {
      if (mounted) {
        setState(() {
          // revert
          if (paid) {
            _paid.remove(memberId);
          } else {
            _paid.add(memberId);
          }
        });
        showAppSnack(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(memberId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final group = appState.group;
    final members = context.watch<MemberProvider>().members;
    final isOpen = widget.meeting.isOpen;
    if (group == null) return const SizedBox.shrink();

    final amount = group.socialFundAmount;
    final paidCount = members
        .where((f) => _paid.contains(f.member.id))
        .length;
    final collected = paidCount * amount;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.meetingHubSocialFund)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Card(
                  color: AppColors.surfaceRaised,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${Formatters.money(amount)} per member',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          '$paidCount of ${members.length} paid · '
                          '${Formatters.money(collected)} collected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isOpen) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.socialFundThisMeetingIsClosedThe,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SectionLabel('Members'),
                if (members.isEmpty)
                  EmptyState(
                    icon: Icons.group_off_outlined,
                    title: l10n.socialFundNoMembers,
                    message: l10n.socialFundAddMembersToTheGroup,
                  ),
                for (final f in members)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      secondary: MemberAvatar(f.member.name, radius: 16),
                      title: Text(f.member.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _paid.contains(f.member.id)
                            ? 'Paid ${Formatters.money(amount)}'
                            : 'Not paid',
                        style: TextStyle(
                          fontSize: 11,
                          color: _paid.contains(f.member.id)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      value: _paid.contains(f.member.id),
                      onChanged: (isOpen && !_busy.contains(f.member.id))
                          ? (v) => _toggle(f.member.id, v)
                          : null,
                    ),
                  ),
              ],
            ),
    );
  }
}
