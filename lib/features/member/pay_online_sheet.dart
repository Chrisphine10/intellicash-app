import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/services/remote_payments_api.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/payment_method_button.dart';
import '../meetings/gateway_payment_sheet.dart';
import '../meetings/online_charge.dart' show PaymentPurpose;

/// A member paying into their own group from the passbook: shares, the
/// welfare (social) fund, a fine, or a loan repayment. The server confirms
/// the payment with the provider and books it into the right fund itself.
class PayOnlineSheet extends StatefulWidget {
  const PayOnlineSheet({super.key, required this.options, this.memberPhone});

  final SelfPayOptions options;
  final String? memberPhone;

  @override
  State<PayOnlineSheet> createState() => _PayOnlineSheetState();
}

class _PayOnlineSheetState extends State<PayOnlineSheet> {
  PaymentPurpose _purpose = PaymentPurpose.shares;
  int _shares = 1;
  final _amountCtrl = TextEditingController();
  late PaymentMethod _method;

  @override
  void initState() {
    super.initState();
    _method = widget.options.providers.contains('MPESA_DARAJA') ? PaymentMethod.mpesa : PaymentMethod.paystack;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _typed => double.tryParse(_amountCtrl.text.trim());

  double? get _amount => switch (_purpose) {
        PaymentPurpose.shares =>
          widget.options.shareValue == null ? _typed : _shares * widget.options.shareValue!,
        PaymentPurpose.welfare => widget.options.socialFund ?? _typed,
        PaymentPurpose.fine || PaymentPurpose.loanRepayment => _typed,
      };

  /// Why the member cannot pay this yet, or null.
  String? _blocker(L10n l10n) {
    if (_purpose != PaymentPurpose.loanRepayment) return null;
    final owes = widget.options.loanOutstanding;
    if (owes <= 0) return l10n.requestPaymentNoLoan;
    final amount = _amount;
    if (amount != null && amount > owes + 0.001) return l10n.requestPaymentMoreThanOwed(Formatters.money(owes));
    return null;
  }

  Future<void> _continue() async {
    final amount = _amount;
    if (amount == null || amount < 1) return;
    final api = context.read<RemotePaymentsApi>();
    final result = await showModalBottomSheet<GatewayPaymentResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GatewayPaymentSheet(
        channel: SelfPaymentChannel(api, purpose: _purpose.wire, groupAmount: amount),
        method: _method,
        amount: amount,
        memberPhone: widget.memberPhone,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(result != null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final shareValue = widget.options.shareValue;
    final amount = _amount;
    final blocker = _blocker(l10n);
    final purposes = {
      PaymentPurpose.shares: l10n.payOnlineShares,
      PaymentPurpose.welfare: l10n.payOnlineSocialFund,
      PaymentPurpose.fine: l10n.purposeFine,
      PaymentPurpose.loanRepayment: l10n.purposeLoanRepayment,
    };
    final needsTypedAmount = switch (_purpose) {
      PaymentPurpose.shares => shareValue == null,
      PaymentPurpose.welfare => widget.options.socialFund == null,
      _ => true,
    };

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.payIntoMyGroup, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in purposes.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _purpose == entry.key,
                    selectedColor: AppColors.primaryTint,
                    onSelected: (_) => setState(() => _purpose = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_purpose == PaymentPurpose.shares && shareValue != null)
              Row(
                children: [
                  Expanded(child: Text('${l10n.payOnlineShares} × ${Formatters.money(shareValue)}')),
                  IconButton.outlined(
                    onPressed: _shares > 1 ? () => setState(() => _shares--) : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  SizedBox(width: 40, child: Text('$_shares', textAlign: TextAlign.center)),
                  IconButton.filled(
                    onPressed: () => setState(() => _shares++),
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              )
            else if (_purpose == PaymentPurpose.welfare && widget.options.socialFund != null)
              Text(l10n.requestPaymentWelfareAmount(Formatters.money(widget.options.socialFund!)))
            else if (needsTypedAmount)
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.requestPaymentAmount,
                  helperText: _purpose == PaymentPurpose.loanRepayment
                      ? l10n.requestPaymentYouOwe(Formatters.money(widget.options.loanOutstanding))
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 12),
            if (widget.options.providers.length > 1)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final provider in widget.options.providers)
                    PaymentMethodButton(
                      method: provider == 'PAYSTACK' ? PaymentMethod.paystack : PaymentMethod.mpesa,
                      selected: (_method == PaymentMethod.paystack) == (provider == 'PAYSTACK'),
                      onTap: () => setState(
                        () => _method = provider == 'PAYSTACK' ? PaymentMethod.paystack : PaymentMethod.mpesa,
                      ),
                    ),
                ],
              ),
            if (blocker != null) ...[
              const SizedBox(height: 10),
              Text(blocker, style: TextStyle(color: AppColors.defaulted, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: amount == null || amount < 1 || blocker != null ? null : _continue,
              child: Text(amount == null ? l10n.requestPaymentContinue : l10n.requestPaymentFor(Formatters.money(amount))),
            ),
            const SizedBox(height: 4),
            Text(l10n.payOnlineChargesShownNext, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
