import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/credit_rating.dart';
import '../../data/models/remote/store_models.dart';
import '../../providers/connection_provider.dart';
import '../../providers/store_provider.dart';
import '../../shared/widgets/common.dart';
import '../agent/credit_band_chip.dart';
import 'store_categories.dart';

/// Product detail + the "request on credit" flow.
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.product});

  final StoreProduct product;

  @override
  Widget build(BuildContext context) {
    final category = storeCategoryInfo(product.category, product.categoryLabel);
    return Scaffold(
      appBar: AppBar(title: const Text('Intelli-Stores')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                product.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 14),
          Text(product.name,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(category.icon, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${category.label}'
                '${product.sellerName != null ? ' · ${product.sellerName}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Column(
                children: [
                  KeyValueRow('Price', Formatters.money(product.price),
                      emphasize: true),
                  KeyValueRow('Deposit', Formatters.money(product.deposit)),
                  KeyValueRow(
                    'Availability',
                    product.inStock
                        ? '${product.inventoryCount} in stock'
                        : 'Out of stock',
                  ),
                ],
              ),
            ),
          ),
          if (product.description != null) ...[
            const SectionLabel('About'),
            Text(product.description!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (product.creditSummary != null) ...[
            const SectionLabel('Credit'),
            Text(product.creditSummary!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (product.fulfilmentSummary != null) ...[
            const SectionLabel('Fulfilment'),
            Text(product.fulfilmentSummary!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: product.inStock
                ? () => _openRequestSheet(context)
                : null,
            icon: const Icon(Icons.request_quote_outlined, size: 18),
            label: Text(product.inStock
                ? 'Request on Credit'
                : 'Out of stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreditRequestSheet(product: product),
    );
  }
}

class _CreditRequestSheet extends StatefulWidget {
  const _CreditRequestSheet({required this.product});
  final StoreProduct product;

  @override
  State<_CreditRequestSheet> createState() => _CreditRequestSheetState();
}

class _CreditRequestSheetState extends State<_CreditRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  String? _programmeId;
  int _quantity = 1;
  bool _saving = false;
  List<StoreProgramme> _programmes = [];
  bool _loadingProgrammes = true;

  RemoteCreditRating? _rating;
  bool _loadingRating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<StoreProvider>();
      final connection = context.read<ConnectionProvider>();
      final p = await store.ensureProgrammes();
      if (mounted) {
        setState(() {
          _programmes = p;
          _programmeId = p.isNotEmpty ? p.first.id : null;
          _loadingProgrammes = false;
        });
      }
      final group = connection.selectedGroup;
      if (group != null) {
        try {
          final rating = await connection.api.creditRating(group.id);
          if (mounted) setState(() => _rating = rating);
        } catch (_) {
          // No rating available — the request still goes through; the
          // backend falls back to the product's default deposit.
        }
      }
      if (mounted) setState(() => _loadingRating = false);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final group = connection.selectedGroup;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 8),
            Text('Request on Credit',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(widget.product.name,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            if (group != null) _CreditPricingPanel(
              groupName: group.name,
              rating: _rating,
              loading: _loadingRating,
              productPrice: widget.product.price,
            ),
            const SizedBox(height: 16),
            if (_loadingProgrammes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _programmeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Programme'),
                dropdownColor: AppColors.surfaceRaised,
                validator: (v) => v == null ? 'Pick a programme' : null,
                items: [
                  for (final p in _programmes)
                    DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14))),
                ],
                onChanged: (v) => setState(() => _programmeId = v),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Customer name'),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (v) =>
                  (v == null || v.trim().length < 7) ? 'Enter a phone' : null,
            ),
            const SizedBox(height: 16),
            if (group == null)
              TextFormField(
                controller: _groupCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Group name (optional)'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Quantity', style: TextStyle(fontSize: 14))),
                IconButton.outlined(
                  onPressed:
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$_quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton.filled(
                  onPressed: _quantity < widget.product.inventoryCount
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving || _loadingProgrammes ? null : _submit,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final store = context.read<StoreProvider>();
    final connection = context.read<ConnectionProvider>();
    final group = connection.selectedGroup;
    // Bought during a sitting, so the meeting's record accounts for it. Uses
    // the server's meeting, not the local one — the two have different ids.
    final meeting = connection.openRemoteMeeting;
    try {
      await store.submitCreditRequest(
        productId: widget.product.id,
        programmeId: _programmeId!,
        customerName: _nameCtrl.text.trim(),
        customerEmail: _emailCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        quantity: _quantity,
        groupId: group?.id,
        groupName: group?.name ?? _groupCtrl.text.trim(),
        meetingId: meeting?.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'Credit request submitted.');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Shows how the buying group's credit rating prices this purchase — the
/// deposit floor their band unlocks. The server always confirms the final
/// figures; this is a preview so the buyer isn't surprised.
class _CreditPricingPanel extends StatelessWidget {
  const _CreditPricingPanel({
    required this.groupName,
    required this.rating,
    required this.loading,
    required this.productPrice,
  });

  final String groupName;
  final RemoteCreditRating? rating;
  final bool loading;
  final double productPrice;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buying for $groupName',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (loading)
                    Text('Checking your group\'s credit rating…',
                        style: Theme.of(context).textTheme.bodySmall)
                  else if (rating == null)
                    Text(
                      'Priced at the standard deposit — rating unavailable.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(
                      '${rating!.rated ? 'Band ${rating!.band}' : 'Unrated'} · '
                      'Estimated deposit '
                      '${Formatters.money(productPrice * rating!.depositPercent / 100)} '
                      '(${rating!.depositPercent.toStringAsFixed(0)}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (!loading && rating != null) CreditBandChip(rating: rating!),
          ],
        ),
      ),
    );
  }
}
