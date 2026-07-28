import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/credit_rating.dart';
import '../../data/models/remote/external_loan_models.dart';
import '../../providers/connection_provider.dart';
import '../../providers/external_loans_provider.dart';
import '../../shared/widgets/common.dart';
import '../agent/credit_band_chip.dart';

/// Bottom sheet to apply for an external partner loan: shows the group's
/// credit band against the product's minimum, then takes amount + purpose.
class ExternalLoanApplySheet extends StatefulWidget {
  const ExternalLoanApplySheet({super.key, required this.product});

  final ExternalLoanProduct product;

  @override
  State<ExternalLoanApplySheet> createState() => _ExternalLoanApplySheetState();
}

class _ExternalLoanApplySheetState extends State<ExternalLoanApplySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  bool _saving = false;

  RemoteCreditRating? _rating;
  bool _loadingRating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final connection = context.read<ConnectionProvider>();
      final group = connection.selectedGroup;
      if (group != null) {
        try {
          final rating = await connection.api.creditRating(group.id);
          if (mounted) setState(() => _rating = rating);
        } catch (_) {
          // No rating available — the application still goes through; the
          // server checks the band when it processes the request.
        }
      }
      if (mounted) setState(() => _loadingRating = false);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final connection = context.watch<ConnectionProvider>();
    final group = connection.selectedGroup;
    final partnerName = product.partner?.name;

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
            Text('Apply for a Loan',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              '${product.name}${partnerName != null ? ' · $partnerName' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (group != null) ...[
              _LoanBandPanel(
                groupName: group.name,
                rating: _rating,
                loading: _loadingRating,
                minCreditBand: product.minCreditBand,
              ),
              const SizedBox(height: 14),
            ],
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Column(
                  children: [
                    KeyValueRow('Interest', product.interestLabel),
                    KeyValueRow('Term', 'Up to ${product.termMonths} months'),
                    KeyValueRow('Repayments', product.frequencyLabel),
                    KeyValueRow(
                      'Amount',
                      '${Formatters.moneyCompact(product.minAmount)} – '
                          '${Formatters.moneyCompact(product.maxAmount)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (KSh)',
                helperText: 'Between ${Formatters.moneyCompact(product.minAmount)} '
                    'and ${Formatters.moneyCompact(product.maxAmount)}',
              ),
              validator: _validateAmount,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _purposeCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What is the loan for?',
                hintText: 'e.g. Buying maize seed for the season',
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Tell us what the loan is for (at least 5 characters)'
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateAmount(String? v) {
    final raw = (v ?? '').replaceAll(',', '').trim();
    if (raw.isEmpty) return 'Enter an amount';
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    if (amount < widget.product.minAmount ||
        amount > widget.product.maxAmount) {
      return 'Amount must be between '
          '${Formatters.moneyCompact(widget.product.minAmount)} and '
          '${Formatters.moneyCompact(widget.product.maxAmount)}';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final provider = context.read<ExternalLoansProvider>();
    final group = context.read<ConnectionProvider>().selectedGroup;
    final amount =
        double.parse(_amountCtrl.text.replaceAll(',', '').trim());
    try {
      await provider.submitApplication(
        productId: widget.product.id,
        amountKes: amount,
        purpose: _purposeCtrl.text.trim(),
        groupId: group?.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'Loan application submitted.');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Shows the applying group's credit band next to the product's minimum
/// band. When the band falls short we warn but never block — the server
/// makes the final call, and lenders sometimes review edge cases manually.
class _LoanBandPanel extends StatelessWidget {
  const _LoanBandPanel({
    required this.groupName,
    required this.rating,
    required this.loading,
    required this.minCreditBand,
  });

  final String groupName;
  final RemoteCreditRating? rating;
  final bool loading;
  final String? minCreditBand;

  @override
  Widget build(BuildContext context) {
    final minBand = minCreditBand;
    final bandShort = !loading &&
        minBand != null &&
        !creditBandMeets(rating?.band, minBand);
    return Card(
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Applying as $groupName',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (loading)
                        Text('Checking your group\'s credit rating…',
                            style: Theme.of(context).textTheme.bodySmall)
                      else if (rating == null)
                        Text(
                          'Credit rating unavailable — the lender checks it '
                          'when reviewing your application.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        Text(
                          minBand != null
                              ? 'This loan asks for Band $minBand or better.'
                              : 'Open to all credit bands.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (!loading && rating != null) CreditBandChip(rating: rating!),
              ],
            ),
            if (bandShort) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: AppColors.pending),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your group\'s rating is below Band $minBand. You can '
                      'still apply, but the lender may not approve it.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.pending),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
