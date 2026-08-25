import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import 'member_report_local_screen.dart';

/// Pick a member to generate their report — the group can hand every member
/// a statement of their savings, contributions and loans.
class MemberReportsScreen extends StatefulWidget {
  const MemberReportsScreen({super.key});

  @override
  State<MemberReportsScreen> createState() => _MemberReportsScreenState();
}

class _MemberReportsScreenState extends State<MemberReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = context.read<AppState>().group;
      if (group != null) {
        context.read<MemberProvider>().load(group.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final members = context.watch<MemberProvider>().members;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberReports)),
      body: members.isEmpty
          ? EmptyState(
              icon: Icons.person_outline,
              title: l10n.groupReportNoMembersYet,
              message: l10n.groupReportMembersAppearHereOnceThey,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  l10n.memberReportsTapAMemberToSee,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                for (final f in members)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      leading: MemberAvatar(f.member.name, radius: 18),
                      title: Text(f.member.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Saved ${Formatters.moneyCompact(f.totalSavings)}'
                        '${f.activeLoanBalance > 0 ? ' · owes ${Formatters.moneyCompact(f.activeLoanBalance)}' : ''}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing:
                          const Icon(Icons.description_outlined, size: 20),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemberReportLocalScreen(
                                memberId: f.member.id),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
