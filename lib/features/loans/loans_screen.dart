import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../providers/app_state.dart';
import '../../providers/loan_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import 'loan_detail_screen.dart';

/// The portfolio: filter Active/All, search by member, every loan wearing
/// its status.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  bool _showAll = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final group = context.read<AppState>().group;
    if (group == null) return;
    await context.read<LoanProvider>().load(group.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loans = provider.loans.where((loan) {
      if (!_showAll && loan.status == LoanStatus.repaid) return false;
      if (_query.isNotEmpty &&
          !loan.memberName.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
          children: [
            Text('Loan Portfolio',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Active')),
                ButtonSegment(value: true, label: Text('All')),
              ],
              selected: {_showAll},
              onSelectionChanged: (selection) =>
                  setState(() => _showAll = selection.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.surfaceRaised,
                selectedForegroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.outline),
                textStyle:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by member name',
                prefixIcon: Icon(Icons.search,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            if (loans.isEmpty && !provider.loading)
              const EmptyState(
                icon: Icons.payments_outlined,
                title: 'No loans here',
                message: 'Loans are disbursed inside a meeting — open a '
                    'meeting and use Disburse Loan.',
              ),
            for (final loan in loans)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Text(
                    loan.memberName,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Principal: ${Formatters.money(loan.principal)}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.money(loan.outstanding),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      StatusChip.loan(loan.status),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoanDetailScreen(loanId: loan.id),
                      ),
                    );
                    await _load();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
