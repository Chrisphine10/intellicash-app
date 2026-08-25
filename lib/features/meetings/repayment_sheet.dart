import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/loan_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../shared/widgets/common.dart';

/// Record a repayment against any outstanding loan, inside the meeting.
class RepaymentSheet extends StatefulWidget {
  const RepaymentSheet({super.key});

  @override
  State<RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<RepaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  Loan? _loan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = context.read<AppState>().group;
      if (group != null) {
        context.read<LoanProvider>().load(group.id);
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
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
              FilledButton.icon(
                onPressed: _saving ? null : _record,
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.repaymentRecordRepayment),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _record() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final loanProvider = context.read<LoanProvider>();
    final meetingProvider = context.read<MeetingProvider>();
    try {
      final updated = await loanProvider.repay(
        loan: _loan!,
        amount: double.parse(_amountCtrl.text),
        meetingId: meetingProvider.activeMeeting?.id,
      );
      await meetingProvider.refreshTotals();
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(
        context,
        updated.outstanding <= 0
            ? '${updated.memberName}\'s loan is fully repaid. 🎉'
            : 'Repayment recorded — '
                '${Formatters.money(updated.outstanding)} remaining.',
      );
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
