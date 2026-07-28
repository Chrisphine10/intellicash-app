import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan.dart';
import '../../providers/loan_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';

/// Full history of one loan: terms, balance and every repayment.
class LoanDetailScreen extends StatefulWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  Loan? _loan;
  List<LoanRepayment> _repayments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<LoanProvider>();
    final loan = await provider.loanById(widget.loanId);
    final repayments = await provider.repaymentsForLoan(widget.loanId);
    if (mounted) {
      setState(() {
        _loan = loan;
        _repayments = repayments;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = _loan;
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: loan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(loan.memberName,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    StatusChip.loan(loan.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Disbursed ${Formatters.shortDate(loan.disbursedAt)} · '
                  'Due ${Formatters.shortDate(loan.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SectionLabel('Terms'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    child: Column(
                      children: [
                        KeyValueRow(
                            'Principal', Formatters.money(loan.principal)),
                        KeyValueRow(
                          'Interest',
                          '${loan.interestRate == loan.interestRate.roundToDouble() ? loan.interestRate.toInt() : loan.interestRate}% '
                          '${loan.interestType.label.toLowerCase()}',
                        ),
                        KeyValueRow(
                            'Total due', Formatters.money(loan.totalDue)),
                        KeyValueRow('Repaid so far',
                            Formatters.money(loan.amountRepaid)),
                        const Divider(height: 16),
                        KeyValueRow('Outstanding',
                            Formatters.money(loan.outstanding),
                            emphasize: true),
                      ],
                    ),
                  ),
                ),
                const SectionLabel('Repayments'),
                if (_repayments.isEmpty)
                  const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No repayments yet',
                    message:
                        'Repayments are recorded inside meetings and '
                        'appear here instantly.',
                  ),
                for (final repayment in _repayments)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      leading: Icon(Icons.arrow_downward,
                          size: 18, color: AppColors.primary),
                      title: Text(
                        Formatters.money(repayment.amount),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      trailing: Text(
                        Formatters.shortDate(repayment.paidAt),
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
