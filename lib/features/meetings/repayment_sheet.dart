import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/user_message.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/loan.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/loan_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/payment_method_panel.dart';
import 'online_charge.dart';

/// Record a repayment against any outstanding loan, inside the meeting.
class RepaymentSheet extends StatefulWidget {
  const RepaymentSheet({super.key});

  @override
  State<RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<RepaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  Loan? _loan;
  bool _saving = false;
  PaymentMethod _method = PaymentMethod.cash;

  /// Set when the book can charge members online; null means cash only.
  OnlineCharge? _online;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = context.read<AppState>().group;
      if (group != null) {
        context.read<LoanProvider>().load(group.id);
      }
      OnlineCharge.load(context).then((online) {
        if (mounted) setState(() => _online = online);
      });
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final outstandingLoans = context
        .watch<LoanProvider>()
        .loans
        .where((loan) => loan.outstanding > 0)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.repaymentRecordRepayment,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (outstandingLoans.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.repaymentNoOutstandingLoansNothingTo,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else ...[
              DropdownButtonFormField<Loan>(
                initialValue: _loan,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.repaymentSelectLoan),
                dropdownColor: AppColors.surfaceRaised,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => v == null ? 'Pick a loan' : null,
                items: [
                  for (final loan in outstandingLoans)
                    DropdownMenuItem(
                      value: loan,
                      child: Text(
                        '${loan.memberName} — '
                        '${Formatters.moneyCompact(loan.outstanding)} due',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _loan = v),
              ),
              if (_loan != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.surfaceRaised,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      children: [
                        KeyValueRow('Principal',
                            Formatters.money(_loan!.principal)),
                        KeyValueRow(
                            'Repaid so far', Formatters.money(_loan!.amountRepaid)),
                        KeyValueRow('Outstanding',
                            Formatters.money(_loan!.outstanding),
                            emphasize: true),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.welfareAmountKsh),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  final amount = double.tryParse(v ?? '') ?? 0;
                  if (amount <= 0) return 'Enter an amount above zero';
                  final loan = _loan;
                  if (loan != null && amount > loan.outstanding) {
                    return 'More than the outstanding balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PaymentMethodPanel(
                value: _method,
                online: _online != null && _online!.canCharge(_loan?.memberId),
                switchedOff: _online?.switchedOff ?? const {},
                codeController: _codeCtrl,
                onChanged: (m) => setState(() => _method = m),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _record,
                icon: Icon(paymentActionIcon(_method), size: 18),
                label: Text(paymentActionLabel(l10n, _method, l10n.repaymentRecordRepayment)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _record() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final appState = context.read<AppState>();
    final loanProvider = context.read<LoanProvider>();
    final meetingProvider = context.read<MeetingProvider>();
    final amount = double.parse(_amountCtrl.text);
    // M-Pesa / Paystack: the member approves on their own phone first, and
    // the repayment is recorded once the server confirms the money. Cash and
    // M-Pesa Classic (code typed above) are recorded straight away.
    final settled = await settlePayment(
      context,
      online: _online,
      method: _method,
      purpose: PaymentPurpose.loanRepayment,
      amount: amount,
      localMemberId: _loan!.memberId,
      typedCode: _codeCtrl.text,
    );
    if (settled == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await loanProvider.repay(
        loan: _loan!,
        amount: amount,
        meetingId: meetingProvider.activeMeeting?.id,
        groupPaymentId: settled.groupPaymentId,
        paymentMethod: settled.method,
        paymentReference: settled.reference,
      );
      // A payment clears the member's oldest loan first (the server's rule),
      // so what is left is told across all their loans, not just this one.
      final stillOwed = await loanProvider.owedByMember(updated.memberId);
      await meetingProvider.refreshTotals();
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(
        context,
        stillOwed <= 0
            ? '${updated.memberName}\'s loans are fully repaid. 🎉'
            : 'Repayment recorded — '
                '${Formatters.money(stillOwed)} still owed on ${updated.memberName}\'s loans.',
      );
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (e) {
      // Anything else (a storage fault) must say so, never fail silently.
      if (mounted) showAppSnack(context, userMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
