import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';

/// Shown when a group account signs in on a phone that holds ANOTHER group's
/// record book.
///
/// The book on a phone belongs to the group it is linked to. Signing out is
/// meant to close it, but a person with the handset could otherwise create a
/// fresh group account - free, needing only a network - and be handed the
/// previous group's members, savings and loans. So the book stays shut, and the
/// only way on is to sign out. Nothing is changed or sent anywhere.
class WrongBookScreen extends StatelessWidget {
  const WrongBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final groupName = context.select<AppState, String>((s) => s.group?.name ?? '');
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  l10n.wrongBookTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.wrongBookBody(groupName),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.read<ConnectionProvider>().disconnect(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
