import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/remote_payment_providers_api.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// Where this group's money is collected.
///
/// Deliberately plain-language: the people reading this are treasurers, not
/// integrators. "Using the platform's account" is stated as a normal state,
/// not an error, because most groups will never configure anything here.
class PaymentProvidersScreen extends StatefulWidget {
  const PaymentProvidersScreen({super.key});

  @override
  State<PaymentProvidersScreen> createState() => _PaymentProvidersScreenState();
}

class _PaymentProvidersScreenState extends State<PaymentProvidersScreen> {
  GroupPaymentProviders? _data;
  String? _error;
  bool _loading = true;
  String? _busyProvider;

  static const _fieldLabels = <String, String>{
    'MPESA_CONSUMER_KEY': 'Consumer key',
    'MPESA_CONSUMER_SECRET': 'Consumer secret',
    'MPESA_SHORTCODE': 'Shortcode / till number',
    'MPESA_PASSKEY': 'Passkey',
    'MPESA_INITIATOR_NAME': 'Initiator name',
    'MPESA_SECURITY_CREDENTIAL': 'Security credential',
    'MPESA_ENVIRONMENT': 'Environment (SANDBOX or LIVE)',
    'PAYSTACK_SECRET_KEY': 'Secret key',
    'PAYSTACK_PUBLIC_KEY': 'Public key',
  };

  bool _isSecret(String key) =>
      key.contains('SECRET') || key.contains('PASSKEY') || key.contains('CREDENTIAL');

  RemotePaymentProvidersApi _api(BuildContext context) =>
      context.read<RemotePaymentProvidersApi>();

  String? _groupId(BuildContext context) =>
      context.read<ConnectionProvider>().selectedGroup?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final groupId = _groupId(context);
    if (groupId == null) {
      setState(() {
        _loading = false;
        _error = 'Choose your group under Cloud Account first.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api(context).list(groupId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _edit(GroupPaymentProvider provider) async {
    final l10n = L10n.of(context);
    final controllers = <String, TextEditingController>{
      for (final key in provider.values.keys) key: TextEditingController(),
    };

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(provider.label, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                l10n.paymentProvidersLeaveABoxEmptyTo,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final key in provider.values.keys) ...[
                TextField(
                  controller: controllers[key],
                  obscureText: _isSecret(key),
                  decoration: InputDecoration(
                    labelText: _fieldLabels[key] ?? key,
                    // Never show a stored secret; say it exists.
                    hintText: provider.isSecretSet(key)
                        ? 'Saved — type to replace'
                        : (provider.values[key] ?? 'Not set'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(l10n.paymentProvidersSave),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !mounted) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }

    // Only send what was typed — an empty box means "leave it alone", not
    // "erase it".
    final entered = <String, String>{
      for (final entry in controllers.entries)
        if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text.trim(),
    };
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (entered.isEmpty) return;

    await _run(provider.provider, () async {
      await _api(context).save(
        groupId: _groupId(context)!,
        provider: provider.provider,
        credentials: entered,
      );
    }, 'Saved. This group now collects into its own account.');
  }

  Future<void> _revert(GroupPaymentProvider provider) async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.paymentProvidersUseThePlatformAccount),
        content: Text(
          'Remove this group\'s own ${provider.label} details. '
          'Money collected will go to the platform account instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.groupSetupWizardRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(provider.provider, () async {
      await _api(context).revert(groupId: _groupId(context)!, provider: provider.provider);
    }, 'This group now uses the platform account.');
  }

  Future<void> _run(String provider, Future<void> Function() action, String okMessage) async {
    setState(() => _busyProvider = provider);
    try {
      await action();
      await _load();
      if (!mounted) return;
      showAppSnack(context, okMessage);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentProvidersPaymentProviders)),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l10n = L10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [Text(_error!, style: TextStyle(color: AppColors.defaulted))],
      );
    }
    final data = _data;
    if (data == null) {
      // Never render nothing. This branch is supposed to be unreachable —
      // every path that clears _loading also sets _data or _error — but it was
      // reached on a device, and an empty screen tells the person holding the
      // phone that the feature is missing rather than that something failed.
      // Say so, and give them the one control that can recover it.
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Could not load this group\'s payment settings.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.cyclesPullDownToTryAgainIf,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: Text(l10n.welfareTryAgain)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Where money paid by members is received for ${data.groupName}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.paymentProvidersMPesaClassicNeedsNothingHere,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        if (!data.canConfigure)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              l10n.paymentProvidersYouCanSeeThisButNot,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (final provider in data.providers) _providerCard(data, provider),
      ],
    );
  }

  Widget _providerCard(GroupPaymentProviders data, GroupPaymentProvider provider) {
    final l10n = L10n.of(context);
    final busy = _busyProvider == provider.provider;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(provider.label,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Text(
                  provider.configured ? 'Own account' : 'Platform account',
                  style: TextStyle(
                    fontSize: 12,
                    color: provider.configured ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // The honest, and easily missed, state: half-filled means the
            // platform still collects the money.
            if (provider.configured && !provider.isComplete)
              Text(
                l10n.paymentProvidersStillNeeded(provider.missingKeys
                    .map((k) => _fieldLabels[k] ?? k)
                    .join(', ')),
                style: TextStyle(fontSize: 12, color: AppColors.pending),
              )
            else
              Text(
                provider.configured
                    ? 'Money from members comes to this group\'s own account.'
                    : 'Money from members comes to the platform account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (data.canConfigure) ...[
              const SizedBox(height: 10),
              // Both buttons must be Expanded, not bare. The app theme gives
              // filled and outlined buttons a minimumSize of Size.fromHeight,
              // whose width is double.infinity — that is what makes them fill
              // their parent. A Row hands its children an unbounded width, so
              // nothing clamps that infinity and the button asks to be
              // infinitely wide; layout stops there and the whole screen
              // renders blank, with no exception logged. Expanded gives each
              // button a finite width, which is what every other Row of
              // buttons in this app already does.
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => _edit(provider),
                      child: Text(provider.configured ? 'Update' : 'Set up'),
                    ),
                  ),
                  if (provider.configured) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => _revert(provider),
                        child: Text(l10n.paymentProvidersUsePlatform),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
