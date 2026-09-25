import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';

/// Confirms, then signs out — but only once this phone has sent what it holds.
///
/// Every sign-out button goes through here so they cannot drift: the work
/// recorded on this phone is synced first, and when it cannot be (no signal,
/// or the server did not take it) the person is told why and stays signed in.
/// Returns true when the phone signed out.
Future<bool> confirmAndSignOut(
  BuildContext context, {
  String? note,
}) async {
  final l10n = L10n.of(context);
  final connection = context.read<ConnectionProvider>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.signOut, style: const TextStyle(fontSize: 17)),
      content: Text(note ?? l10n.signOutKeepsRecords,
          style: const TextStyle(fontSize: 13.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.defaulted,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.signOut),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) return false;

  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text(l10n.signOutSendingFirst)));
  final result = await connection.signOut();
  messenger.hideCurrentSnackBar();

  if (!result.signedOut) {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOutNotYetTitle, style: const TextStyle(fontSize: 17)),
        content: Text(
          result.outcome == SignOutOutcome.pendingOffline
              ? l10n.signOutBlockedOffline(result.pending)
              : l10n.signOutBlockedUnsent(result.pending),
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.signOutUnderstood),
          ),
        ],
      ),
    );
    return false;
  }

  messenger.showSnackBar(SnackBar(content: Text(l10n.signedOut)));
  // Drop every screen and let the root decide what this phone shows now: a
  // login pushed on top would leave the group app alive one back-press away.
  navigator.popUntil((route) => route.isFirst);
  return true;
}
