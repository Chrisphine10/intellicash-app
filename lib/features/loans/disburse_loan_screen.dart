import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan.dart';
import '../../providers/app_state.dart';
import '../../providers/loan_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';

/// Eligibility is computed and shown before the principal field will
/// accept a value — no manual math, no over-lending.
///
/// Loans are disbursed **only inside a meeting**, so [meetingId] is required —
/// every money movement belongs to a meeting record.
class DisburseLoanScreen extends StatefulWidget {
  const DisburseLoanScreen({super.key, required this.meetingId});

  /// The meeting this disbursement is recorded against.
  final String meetingId;

  @override
  State<DisburseLoanScreen> createState() => _DisburseLoanScreenState();
}

class _DisburseLoanScreenState extends State<DisburseLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _principalCtrl = TextEditingController();
  String? _memberId;
  LoanEligibility? _eligibility;
  late DateTime _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final group = context.read<AppState>().group!;
    _dueDate = _addMonths(DateTime.now(), group.defaultLoanTermMonths);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MemberProvider>().load(group.id);
    });
  }

  static DateTime _addMonths(DateTime date, int months) {
    final year = date.year + (date.month + months - 1) ~/ 12;
    final month = (date.month + months - 1) % 12 + 1;
    final day = date.day.clamp(1, DateUtils.getDaysInMonth(year, month));
    return DateTime(year, month, day);
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility(String memberId) async {
    final group = context.read<AppState>().group!;
    final eligibility = await context
        .read<LoanProvider>()
        .eligibility(group: group, memberId: memberId);
    if (mounted) setState(() => _eligibility = eligibility);
  }

  @override
  Widget build(BuildContext context) {
    final group = context.watch<AppState>().group!;
    final members = context.watch<MemberProvider>().members;
    final eligibility = _eligibility;

    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text('Disburse Loan',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _memberId,
              decoration: const InputDecoration(labelText: 'Select Member'),
              dropdownColor: AppColors.surfaceRaised,
              validator: (v) => v == null ? 'Pick a member' : null,
              items: [
                for (final financials in members)
                  DropdownMenuItem(
                    value: financials.member.id,
                    child: Text(financials.member.name,
                        style: const TextStyle(fontSize: 14)),
                  ),
              ],
              onChanged: (v) {
                setState(() => _memberId = v);
                if (v != null) _checkEligibility(v);
              },
            ),
            if (eligibility != null) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loan Eligibility',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      KeyValueRow('Total Savings',
                          Formatters.money(eligibility.totalSavings)),
                      KeyValueRow('Active Loan Balance',
                          Formatters.money(eligibility.activeLoanBalance)),
                      KeyValueRow(
                          'Max Loan (${_trimNum(group.loanMultiplier)}×)',
                          Formatters.money(eligibility.maxLoan)),
                      KeyValueRow('Available Amount',
                          Formatters.money(eligibility.availableAmount),
                          emphasize: true),
                    ],
                  ),
                ),
              ),
              if (!eligibility.canBorrow)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'This member has no borrowing headroom — savings must '
                    'grow or the current loan must reduce first.',
                    style: TextStyle(fontSize: 12, color: AppColors.defaulted),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _principalCtrl,
              enabled: eligibility?.canBorrow ?? false,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Principal Amount (KSh)'),
              validator: (v) {
                final amount = double.tryParse(v ?? '') ?? 0;
                if (amount <= 0) return 'Enter an amount above zero';
                final available = _eligibility?.availableAmount ?? 0;
                if (amount > available) {
                  return 'Exceeds available '
                      '${Formatters.moneyCompact(available)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now().add(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(Formatters.isoDate(_dueDate),
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Default term · ${group.defaultLoanTermMonths} months · '
              '${_trimNum(group.interestRate)}% '
              '${group.interestType.label.toLowerCase()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  (eligibility?.canBorrow ?? false) && !_saving ? _disburse : null,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Disburse Loan'),
            ),
          ],
        ),
      ),
    );
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  Future<void> _disburse() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final loanProvider = context.read<LoanProvider>();
    final group = appState.group!;
    try {
      final loan = await loanProvider.disburse(
        group: group,
        memberId: _memberId!,
        principal: double.parse(_principalCtrl.text),
        dueDate: _dueDate,
        meetingId: widget.meetingId,
      );
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(
        context,
        'Disbursed ${Formatters.money(loan.principal)} — due '
        '${Formatters.shortDate(loan.dueDate)}.',
      );
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
