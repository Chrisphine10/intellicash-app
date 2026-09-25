import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../shared/widgets/common.dart';
import '../onboarding/group_setup_wizard.dart';
import '../settings/cycles_screen.dart';
import '../settings/group_policy_screen.dart';
import 'meeting_security_screen.dart';
import 'more_tiles.dart';

/// Everything about how the group runs, in one place: its set-up, meeting
/// security, rules, members' own accounts, and the online loan rules and
/// saving cycles. These used to be seven rows on More, alongside reports and
/// the cloud account, which made More a list to read rather than a menu.
class GroupSettingsScreen extends StatelessWidget {
  const GroupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final group = context.watch<AppState>().group;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupSettings)),
      body: group == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                SectionLabel(l10n.moreSectionOnThisPhone),
                Card(
                  child: Column(
                    children: [
                      NavTile(
                        title: l10n.moreEditSetUp,
                        subtitle: l10n.groupSettingsSubtitle,
                        icon: Icons.tune,
                        screen: GroupSetupWizard(existing: group),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      NavTile(
                        title: l10n.meetingSecurity,
                        subtitle: group.requireThreeKey
                            ? l10n.moreMeetingSecurityOn
                            : l10n.moreMeetingSecurityOff,
                        icon: Icons.key_outlined,
                        screen: const MeetingSecurityScreen(),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.rule, size: 20),
                        title: Text(l10n.groupRules, style: moreTileTitleStyle),
                        subtitle: Text(
                          l10n.moreGroupRulesSummary(
                            Formatters.moneyCompact(group.shareValue),
                            group.maxSharesPerMeeting,
                            Formatters.moneyCompact(group.socialFundAmount),
                            plainNumber(group.interestRate),
                            plainNumber(group.loanMultiplier),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                SectionLabel(l10n.moreSectionOnline),
                Card(
                  child: Column(
                    children: [
                      OnlineOnlyTile(
                        title: l10n.groupPolicyOnlineLoanRules,
                        subtitle: l10n.moreLoanRulesSubtitle,
                        icon: Icons.rule_outlined,
                        screen: const GroupPolicyScreen(),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      OnlineOnlyTile(
                        title: l10n.moreSavingCycles,
                        subtitle: l10n.moreSavingCyclesSubtitle,
                        icon: Icons.event_repeat_outlined,
                        screen: const CyclesScreen(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
