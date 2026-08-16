import 'package:flutter/material.dart';

import '../../shared/widgets/common.dart';

/// What the signed-in person needs to know about their own account, in one
/// place.
///
/// It exists because identity and session controls were scattered. An agent's
/// name was decoration on top of their caseload list; signing out was an
/// unlabelled icon wedged between two other unlabelled icons in the toolbar,
/// so the one destructive action was the easiest to hit by accident. Language
/// was a toolbar icon for an agent but a row buried in a 561-line settings
/// screen for a group account — the same setting in two unrelated places
/// depending on who held the phone. Appearance lived only in that settings
/// screen, which an agent never sees, so agents had no way to change the theme
/// at all.
///
/// Deliberately a **pure widget over a value object**: it takes data and
/// callbacks, reads no providers and performs no I/O. That is what lets it be
/// rendered and checked without a device, the same reasoning as
/// `welcomeOptionFor` in the onboarding flow.
@immutable
class AccountSummary {
  const AccountSummary({
    required this.name,
    required this.roleLabel,
    this.phone,
    this.email,
    this.scopeLabel,
    this.serverLabel,
    this.appVersion,
    this.languageLabel,
    this.themeLabel,
  });

  final String name;
  final String roleLabel;
  final String? phone;
  final String? email;

  /// What this account covers — "12 groups" for an agent, the group's name for
  /// a member. Null when there is no scope worth naming.
  final String? scopeLabel;

  /// Which backend this phone talks to. Worth surfacing: a phone pointed at the
  /// wrong server looks exactly like one with no data.
  final String? serverLabel;

  final String? appVersion;
  final String? languageLabel;
  final String? themeLabel;
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.summary,
    required this.onSignOut,
    this.onLanguage,
    this.onTheme,
    this.onServer,
  });

  final AccountSummary summary;

  /// Confirmation belongs to the caller: what signing out costs differs by
  /// role, and this screen should not have to know.
  final VoidCallback onSignOut;

  final VoidCallback? onLanguage;
  final VoidCallback? onTheme;
  final VoidCallback? onServer;

  bool get _hasContacts =>
      (summary.phone?.isNotEmpty ?? false) || (summary.email?.isNotEmpty ?? false);
  bool get _hasPreferences => onLanguage != null || onTheme != null;
  bool get _hasPhoneInfo =>
      summary.serverLabel != null || summary.appVersion != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _identityCard(theme),
          if (_hasContacts) ...[
            const SectionLabel('Contact details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    /*
                     * Not `KeyValueRow`. That widget is shaped for money — its
                     * value never flexes, deliberately, because truncating a
                     * figure would show a member the wrong number. An email
                     * address is free text and has to wrap; reusing the money
                     * row here overflowed a 320px screen by 129 pixels.
                     */
                    if (summary.phone?.isNotEmpty ?? false)
                      _ContactRow(label: 'Phone', value: summary.phone!),
                    if (summary.email?.isNotEmpty ?? false)
                      _ContactRow(label: 'Email', value: summary.email!),
                  ],
                ),
              ),
            ),
          ],
          // Each section is omitted entirely when it has nothing in it. A
          // heading above an empty card is the debris that makes a settings
          // screen feel unfinished.
          if (_hasPreferences) ...[
            const SectionLabel('Preferences'),
            Card(child: Column(children: _preferenceRows(theme))),
          ],
          if (_hasPhoneInfo) ...[
            const SectionLabel('This phone'),
            Card(child: Column(children: _phoneRows(theme))),
          ],
          const SizedBox(height: 20),
          /*
           * Sign out sits at the bottom, full width and labelled, rather than
           * as an icon in the toolbar. It ends the session on a phone that is
           * shared and often handed over mid-task, so reaching it should be
           * deliberate and it should be impossible to mistake for anything else.
           */
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }

  /// Who you are. One card, at the top, where a person looks first.
  Widget _identityCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                _initials(summary.name),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(summary.roleLabel, style: theme.textTheme.bodySmall),
                  if (summary.scopeLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(summary.scopeLabel!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _preferenceRows(ThemeData theme) {
    final rows = <Widget>[];
    if (onLanguage != null) {
      rows.add(ListTile(
        leading: const Icon(Icons.translate, size: 20),
        title: const Text('Language', style: TextStyle(fontSize: 14)),
        subtitle: summary.languageLabel == null
            ? null
            : Text(summary.languageLabel!, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onLanguage,
      ));
    }
    if (onLanguage != null && onTheme != null) {
      rows.add(const Divider(indent: 16, endIndent: 16, height: 1));
    }
    if (onTheme != null) {
      rows.add(ListTile(
        leading: const Icon(Icons.brightness_6_outlined, size: 20),
        title: const Text('Appearance', style: TextStyle(fontSize: 14)),
        subtitle: summary.themeLabel == null
            ? null
            : Text(summary.themeLabel!, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTheme,
      ));
    }
    return rows;
  }

  List<Widget> _phoneRows(ThemeData theme) {
    final rows = <Widget>[];
    if (summary.serverLabel != null) {
      rows.add(ListTile(
        leading: const Icon(Icons.cloud_outlined, size: 20),
        title: const Text('Server', style: TextStyle(fontSize: 14)),
        subtitle: Text(summary.serverLabel!, style: theme.textTheme.bodySmall),
        trailing:
            onServer == null ? null : const Icon(Icons.chevron_right, size: 20),
        onTap: onServer,
      ));
    }
    if (summary.serverLabel != null && summary.appVersion != null) {
      rows.add(const Divider(indent: 16, endIndent: 16, height: 1));
    }
    if (summary.appVersion != null) {
      rows.add(ListTile(
        leading: const Icon(Icons.info_outline, size: 20),
        title: const Text('App version', style: TextStyle(fontSize: 14)),
        subtitle: Text(summary.appVersion!, style: theme.textTheme.bodySmall),
      ));
    }
    return rows;
  }

  /// Up to two initials. Falls back to a dash rather than an empty circle,
  /// which reads as a loading state that never resolves.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '—';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          // Expanded, so a long address wraps onto a second line rather than
          // running off the side of a narrow handset.
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
