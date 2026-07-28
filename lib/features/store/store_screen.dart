import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/external_loan_models.dart';
import '../../data/models/remote/store_models.dart';
import '../../providers/connection_provider.dart';
import '../../providers/external_loans_provider.dart';
import '../../providers/store_provider.dart';
import '../../shared/widgets/common.dart';
import '../server/server_settings_screen.dart';
import 'external_loans_screen.dart';
import 'product_detail_screen.dart';
import 'store_categories.dart';

/// Intelli-Stores — a credit-financed general-products marketplace (farm
/// equipment, solar, electronics, household, business and more). Browse the
/// catalogue and request items on credit — priced by your group's rating.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connection = context.read<ConnectionProvider>();
      if (connection.isConnected) {
        context.read<StoreProvider>().load();
        context
            .read<ExternalLoansProvider>()
            .load(groupId: connection.selectedGroup?.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionProvider>().isConnected;
    final store = context.watch<StoreProvider>();
    final externalLoans = context.watch<ExternalLoansProvider>();
    final categories = store.products.map((p) => p.category).toSet().toList()
      ..sort();
    final visible = _categoryFilter == null
        ? store.products
        : store.products.where((p) => p.category == _categoryFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Intelli-Stores')),
      body: !connected
          ? _NeedsConnection()
          : RefreshIndicator(
              onRefresh: () => Future.wait([
                context.read<StoreProvider>().load(),
                context.read<ExternalLoansProvider>().load(
                    groupId:
                        context.read<ConnectionProvider>().selectedGroup?.id),
              ]),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text('Shop on credit',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Farm, solar, household and business products — priced '
                    'by your group\'s credit rating.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  if (categories.length > 1) ...[
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: 'All',
                            icon: Icons.apps,
                            selected: _categoryFilter == null,
                            onTap: () => setState(() => _categoryFilter = null),
                          ),
                          for (final c in categories)
                            _CategoryChip(
                              label: storeCategoryInfo(c, c).label,
                              icon: storeCategoryInfo(c, c).icon,
                              selected: _categoryFilter == c,
                              onTap: () =>
                                  setState(() => _categoryFilter = c),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (store.loading && store.products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (store.error != null && store.products.isEmpty)
                    EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Could not load the store',
                      message: store.error!,
                    ),
                  if (!store.loading && store.error == null && visible.isEmpty)
                    const EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'No products in this category',
                      message: 'Try a different category or check back later.',
                    ),
                  for (final product in visible)
                    _ProductCard(product: product),
                  if (externalLoans.products.isNotEmpty) ...[
                    const SectionLabel('Credit ventures'),
                    Text(
                      'Loan offers from lending partners — apply as a group.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    for (final p in externalLoans.products.take(5))
                      _ExternalLoanMiniCard(product: p),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ExternalLoansScreen()),
                        ),
                        child: const Text('See all external loans'),
                      ),
                    ),
                  ],
                  if (store.myRequests.isNotEmpty) ...[
                    const SectionLabel('My credit requests'),
                    for (final r in store.myRequests.take(20))
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          leading: Icon(Icons.receipt_long_outlined,
                              size: 20, color: AppColors.primary),
                          title: Text(r.productName ?? 'Credit request',
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Qty ${r.quantity}'
                            '${r.createdAt != null ? ' · ${Formatters.shortDate(r.createdAt!)}' : ''}',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          trailing: _StatusPill(status: r.status),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon,
            size: 15,
            color: selected ? AppColors.primary : AppColors.textSecondary),
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primaryTint,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final StoreProduct product;

  @override
  Widget build(BuildContext context) {
    final category = storeCategoryInfo(product.category, product.categoryLabel);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _ProductImage(
                    url: product.imageUrl, size: 72, categoryIcon: category.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(category.icon,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(category.label,
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.moneyCompact(product.price),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Deposit ${Formatters.moneyCompact(product.deposit)} · '
                      '${product.inStock ? '${product.inventoryCount} in stock' : 'Out of stock'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: product.inStock
                            ? AppColors.textSecondary
                            : AppColors.defaulted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.url,
    required this.size,
    this.categoryIcon = Icons.shopping_bag_outlined,
  });

  final String? url;
  final double size;
  final IconData categoryIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.surfaceRaised,
      child: Icon(categoryIcon, color: AppColors.textSecondary),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(
      url!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (c, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final color = s.contains('APPROV') || s.contains('FULFIL')
        ? AppColors.primary
        : s.contains('REJECT') || s.contains('CANCEL')
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

/// Compact partner-loan card for the Credit ventures strip: name, partner,
/// interest and amount range. Tapping opens the apply sheet.
class _ExternalLoanMiniCard extends StatelessWidget {
  const _ExternalLoanMiniCard({required this.product});

  final ExternalLoanProduct product;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showExternalLoanApplySheet(context, product),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(externalLoanCategoryIcon(product.category),
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.name}'
                      '${product.partner != null ? ' · ${product.partner!.name}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.interestLabel} · '
                      '${Formatters.moneyCompact(product.minAmount)} – '
                      '${Formatters.moneyCompact(product.maxAmount)}',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedsConnection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text('Connect to browse the store',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Intelli-Stores loads from the Intelli-Cash backend. Connect or '
              'sign in first.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ServerSettingsScreen()),
              ),
              child: const Text('Open Cloud Account'),
            ),
          ],
        ),
      ),
    );
  }
}
