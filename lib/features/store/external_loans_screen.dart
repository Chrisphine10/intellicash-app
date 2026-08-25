import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/external_loan_models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../providers/external_loans_provider.dart';
import '../../shared/widgets/common.dart';
import '../agent/credit_band_chip.dart';
import '../server/server_settings_screen.dart';
import 'external_loan_apply_sheet.dart';

/// Icon for an external-loan category code (falls back to a generic bank
/// icon so new categories never look broken).
IconData externalLoanCategoryIcon(String category) =>
    switch (category.toUpperCase()) {
      'WORKING_CAPITAL' => Icons.storefront_outlined,
      'ASSET_FINANCE' => Icons.agriculture_outlined,
      'AGRI_INPUTS' => Icons.grass_outlined,
      'EMERGENCY' => Icons.medical_services_outlined,
      'EDUCATION' => Icons.school_outlined,
      'BUSINESS_GROWTH' => Icons.trending_up,
      _ => Icons.account_balance_outlined,
    };

/// Opens the apply bottom sheet for a partner loan product.
Future<void> showExternalLoanApplySheet(
    BuildContext context, ExternalLoanProduct product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExternalLoanApplySheet(product: product),
  );
}

/// Credit Ventures — loan offers from external lending partners (banks,
/// MFIs, SACCOs) that the group can apply for, plus the group's past
/// applications and their status.
class ExternalLoansScreen extends StatefulWidget {
  const ExternalLoansScreen({super.key});

  @override
  State<ExternalLoansScreen> createState() => _ExternalLoansScreenState();
}

class _ExternalLoansScreenState extends State<ExternalLoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connection = context.read<ConnectionProvider>();
      if (connection.isConnected) {
        context
            .read<ExternalLoansProvider>()
            .load(groupId: connection.selectedGroup?.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final loans = context.watch<ExternalLoansProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.meetingHubExternalLoans)),
      body: !connection.isConnected
          ? _NeedsConnection()
          : RefreshIndicator(
              onRefresh: () => context
                  .read<ExternalLoansProvider>()
                  .load(groupId: connection.selectedGroup?.id),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(l10n.externalLoansCreditVentures,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    l10n.storeLoanOffersFromLendingPartners,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  if (loans.loading && loans.products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (loans.error != null && loans.products.isEmpty)
                    EmptyState(
                      icon: Icons.account_balance_outlined,
                      title: l10n.externalLoansCouldNotLoadLoanOffers,
                      message: loans.error!,
                    ),
                  if (!loans.loading &&
                      loans.error == null &&
                      loans.products.isEmpty)
                    EmptyState(
                      icon: Icons.account_balance_outlined,
                      title: l10n.externalLoansNoLoanOffersRightNow,
                      message: l10n.externalLoansCheckBackLaterPartnersAddNew,
                    ),
                  for (final product in loans.products)
                    _LoanProductCard(product: product),
                  if (loans.myApplications.isNotEmpty) ...[
                    const SectionLabel('My applications'),
                    for (final a in loans.myApplications.take(20))
                      _ApplicationTile(application: a),
                  ],
                ],
              ),
            ),
    );
  }
}

class _LoanProductCard extends StatelessWidget {
  const _LoanProductCard({required this.product});

  final ExternalLoanProduct product;

  @override
  Widget build(BuildContext context) {
    final minBand = product.minCreditBand;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showExternalLoanApplySheet(context, product),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        if (product.partner != null) ...[
                          const SizedBox(height: 2),
                          Text(product.partner!.name,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  if (minBand != null) _MinBandChip(band: minBand),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(externalLoanCategoryIcon(product.category),
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(product.categoryLabel,
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  Icon(Icons.percent, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(product.interestLabel,
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Up to ${product.termMonths} months, '
                '${product.frequencyLabel} repayments',
                style:
                    TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                '${Formatters.moneyCompact(product.minAmount)} – '
                '${Formatters.moneyCompact(product.maxAmount)}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small "Band B or better" pill using the band's status colour.
class _MinBandChip extends StatelessWidget {
  const _MinBandChip({required this.band});
  final String band;

  @override
  Widget build(BuildContext context) {
    final c = creditBandColor(band.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Band ${band.toUpperCase()} or better',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c.color,
        ),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application});

  final ExternalLoanApplication application;

  @override
  Widget build(BuildContext context) {
    final a = application;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(Icons.account_balance_outlined,
            size: 20, color: AppColors.primary),
        title: Text(a.productName ?? 'Loan application',
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${Formatters.moneyCompact(a.amount)}'
          '${a.createdAt != null ? ' · ${Formatters.shortDate(a.createdAt!)}' : ''}',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: _ApplicationStatusPill(status: a.status),
      ),
    );
  }
}

class _ApplicationStatusPill extends StatelessWidget {
  const _ApplicationStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final color = s == 'APPROVED' || s == 'DISBURSED'
        ? AppColors.primary
        : s == 'REJECTED'
            ? AppColors.defaulted
            : AppColors.pending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: color.withValues(alpha: 0.13),
      ),
      child: Text(
        status.toLowerCase().replaceAll('_', ' '),
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _NeedsConnection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(l10n.externalLoansConnectToSeeLoanOffers,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              l10n.externalLoansExternalLoansLoadFromTheIntelli,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ServerSettingsScreen()),
              ),
              child: Text(l10n.storeOpenCloudAccount),
            ),
          ],
        ),
      ),
    );
  }
}
