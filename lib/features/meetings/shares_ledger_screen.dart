import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meeting.dart';
import '../../data/models/transactions.dart';
import '../../providers/meeting_provider.dart';
import '../../shared/widgets/common.dart';

/// Every share purchase this meeting, per member, with the social fund
/// tallied separately — the real-time replacement for the paper register.
class SharesLedgerScreen extends StatelessWidget {
  const SharesLedgerScreen({super.key, required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeetingProvider>();
    final totals = provider.totals;

    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      body: FutureBuilder<List<LedgerEntry>>(
        future: context.read<MeetingProvider>().ledger(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <LedgerEntry>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text('Share Records',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                'Meeting #${meeting.number} · '
                '${Formatters.fullDate(meeting.date)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // The count yields on a narrow screen; the amount
                      // collected stays whole.
                      Flexible(
                        child: Text(
                          '${totals.sharesCount} shares collected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        Formatters.moneyCompact(totals.sharesAmount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.done &&
                  entries.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No purchases yet',
                  message: 'Share purchases land here the moment '
                      'they are recorded.',
                ),
              for (final entry in entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    leading: MemberAvatar(entry.memberName),
                    title: Text(
                      entry.memberName,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${entry.shares} share(s)'
                      '${entry.paymentSummary.isNotEmpty ? ' · ${entry.paymentSummary}' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    trailing: Text(
                      Formatters.moneyCompact(entry.amount),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  child: KeyValueRow(
                    'Social fund collected',
                    Formatters.money(totals.socialFund),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
