import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/common.dart';
import '../server/local_data_vault_screen.dart';
import '../settings/payment_providers_screen.dart';
import 'more_tiles.dart';

/// The cloud account and the settings a treasurer rarely needs: where
/// members' money is received, and copies of old local data. Kept off the
/// main More list so everyday options are not buried under them.
class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreCloudAndAdvanced)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          SectionLabel(l10n.sectionCloudBackup),
          Card(
            child: Column(
              children: [
                const CloudConnectionTile(),
                const Divider(indent: 16, endIndent: 16),
                OnlineOnlyTile(
                  title: l10n.morePaymentProviders,
                  subtitle: l10n.morePaymentProvidersSubtitle,
                  icon: Icons.account_balance_wallet_outlined,
                  screen: const PaymentProvidersScreen(),
                ),
                const Divider(indent: 16, endIndent: 16),
                NavTile(
                  title: l10n.localVaultTitle,
                  subtitle: l10n.signInRecoverLocalData,
                  icon: Icons.inventory_2_outlined,
                  screen: const LocalDataVaultScreen(),
                ),
              ],
            ),
          ),
          SectionLabel(l10n.sectionAbout),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/branding/logo_mark.png', width: 22, height: 22),
                      const SizedBox(width: 8),
                      Text(
                        l10n.moreIntelliCash,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.moreYourGroupSSavingsAndLoans,
                    style: Theme.of(context).textTheme.bodySmall,
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
