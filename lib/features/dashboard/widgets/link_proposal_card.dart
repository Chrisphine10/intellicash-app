import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_state.dart';

/// Asks whether this phone's book belongs to the group the person signed in as.
///
/// Shown only when the two could be the same group but their names do not say
/// so. Linking sends the book's members and meetings into that group's online
/// record, so it is never done silently: both names are shown, and the answer is
/// the person's. "Not now" is remembered.
class LinkProposalCard extends StatefulWidget {
  const LinkProposalCard({super.key});

  @override
  State<LinkProposalCard> createState() => _LinkProposalCardState();
}

class _LinkProposalCardState extends State<LinkProposalCard> {
  bool _busy = false;

  Future<void> _answer(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final proposal = appState.linkProposal;
    if (proposal == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pendingTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pending.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: AppColors.pending),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.linkProposalTitle(proposal.remoteName),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.linkProposalBody(proposal.localName, proposal.remoteName),
            style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _answer(appState.confirmLink),
                child: Text(l10n.linkProposalConfirm),
              ),
              TextButton(
                onPressed: _busy ? null : () => _answer(appState.dismissLink),
                child: Text(l10n.linkProposalDismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
