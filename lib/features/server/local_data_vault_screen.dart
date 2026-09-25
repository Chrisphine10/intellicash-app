import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../data/services/local_data_vault.dart';
import '../../l10n/app_localizations.dart';

class LocalDataVaultScreen extends StatefulWidget {
  const LocalDataVaultScreen({super.key});

  @override
  State<LocalDataVaultScreen> createState() => _LocalDataVaultScreenState();
}

class _LocalDataVaultScreenState extends State<LocalDataVaultScreen> {
  late final LocalDataVault _vault;
  List<LocalArchive> _archives = const [];
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _vault = LocalDataVault(AppDatabase.instance);
    _load();
  }

  Future<void> _load() async {
    final archives = await _vault.list();
    if (mounted) {
      setState(() {
        _archives = archives;
        _busy = false;
      });
    }
  }

  /// Sends a copy of the archive off the phone through the system share
  /// sheet — to a computer, email, or IntelliCash support.
  Future<void> _export(LocalArchive archive) async {
    final l10n = L10n.of(context);
    try {
      final file = await _vault.fileFor(archive.id);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/gzip', name: 'intellicash-${archive.id}.json.gz')],
        subject: l10n.localVaultExportSubject(archive.label),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.localVaultExportFailed)));
      }
    }
  }

  Future<void> _recover(LocalArchive archive) async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localVaultRecoverTitle),
        content: Text(l10n.localVaultRecoverBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.localVaultRecover),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _vault.recover(archive.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.localVaultRecovered)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(LocalArchive archive) async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localVaultDeleteTitle),
        content: Text(l10n.localVaultDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.localVaultDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _vault.delete(archive.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.localVaultTitle)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _archives.isEmpty
          ? Center(child: Text(l10n.localVaultEmpty))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.localVaultNote,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final archive in _archives)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: Text(archive.label),
                      subtitle: Text(
                        '${archive.createdAt.toLocal()} · ${archive.bytes} bytes',
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: l10n.localVaultExport,
                            onPressed: () => _export(archive),
                            icon: const Icon(Icons.ios_share),
                          ),
                          IconButton(
                            tooltip: l10n.localVaultRecover,
                            onPressed: () => _recover(archive),
                            icon: const Icon(Icons.restore),
                          ),
                          IconButton(
                            tooltip: l10n.localVaultDelete,
                            onPressed: () => _delete(archive),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
