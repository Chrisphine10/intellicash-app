import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/network/api_exception.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// Whether this group's members may sign in on their own phones to see their
/// savings and loans.
///
/// The setting belongs to the GROUP and lives on the server, so every phone of
/// the group, the console and the member's own sign-in all obey the same
/// switch. It can only be changed with signal; offline it shows what it last
/// was and says why it cannot be changed.
class MemberSignInsSwitch extends StatefulWidget {
  const MemberSignInsSwitch({super.key, required this.localGroupId});

  final String localGroupId;

  @override
  State<MemberSignInsSwitch> createState() => _MemberSignInsSwitchState();
}

class _MemberSignInsSwitchState extends State<MemberSignInsSwitch> {
  String? _remoteGroupId;
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionProvider>();
    final remote = await IdMapRepository(AppDatabase.instance).remoteId(MapEntity.group, widget.localGroupId);
    if (!mounted) return;
    setState(() => _remoteGroupId = remote);
    if (remote == null || !connection.isConnected) return;
    try {
      final enabled = await connection.api.memberAccountsEnabled(remote);
      if (mounted) setState(() => _enabled = enabled);
    } on ApiException {
      // Shown as unknown; the switch stays disabled until it can be read.
    }
  }

  Future<void> _set(bool value) async {
    final remote = _remoteGroupId;
    if (remote == null) return;
    final connection = context.read<ConnectionProvider>();
    final l10n = L10n.of(context);
    setState(() => _busy = true);
    try {
      final saved = await connection.api.setMemberAccountsEnabled(remote, value);
      if (!mounted) return;
      setState(() => _enabled = saved);
      showAppSnack(context, saved ? l10n.memberSignInsNowOn : l10n.memberSignInsNowOff);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final online = context.watch<ConnectionProvider>().isConnected;
    final ready = online && _remoteGroupId != null && _enabled != null && !_busy;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.phone_android_outlined, size: 20),
      title: Text(l10n.memberSignInsTitle, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        ready || (_busy && online) ? l10n.memberSignInsSubtitle : l10n.memberSignInsNeedsConnection,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      value: _enabled ?? false,
      onChanged: ready ? _set : null,
    );
  }
}
