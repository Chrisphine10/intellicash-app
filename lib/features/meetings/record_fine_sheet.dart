import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/user_message.dart';
import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/payment_method_panel.dart';
import 'online_charge.dart';

/// Common VSLA fine reasons offered as presets; "Other" reveals a free-text
/// field for anything not listed.
const List<String> kFineReasons = [
  'Late arrival',
  'Absent without apology',
  'Missed share contribution',
  'Late loan repayment',
  'Phone ringing in meeting',
  'Leaving early',
  'Disrupting the meeting',
  'Constitution breach',
  'Other',
];

class RecordFineSheet extends StatefulWidget {
  const RecordFineSheet({super.key});

  @override
  State<RecordFineSheet> createState() => _RecordFineSheetState();
}

class _RecordFineSheetState extends State<RecordFineSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _memberId;
  String? _reason;
  bool _saving = false;
  PaymentMethod _method = PaymentMethod.cash;

  /// Set when the book can charge members online; null means cash only.
  OnlineCharge? _online;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final online = await OnlineCharge.load(context);
      if (mounted) setState(() => _online = online);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final members = context.watch<MemberProvider>().members;

    return SingleChildScrollView(
      // A small phone cannot fit the whole sheet: let it scroll.
      child: Padding(
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
              Text(l10n.meetingHubRecordFine,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _memberId,
                decoration: InputDecoration(labelText: l10n.disburseLoanSelectMember),
                dropdownColor: AppColors.surfaceRaised,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => v == null ? 'Pick a member' : null,
                items: [
                  for (final financials in members)
                    DropdownMenuItem(
                      value: financials.member.id,
                      child: Text(financials.member.name,
                          style: const TextStyle(fontSize: 14)),
                    ),
                ],
                onChanged: (v) => setState(() => _memberId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.welfareAmountKsh),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Enter an amount above zero'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: InputDecoration(labelText: l10n.recordFineReason),
                dropdownColor: AppColors.surfaceRaised,
                isExpanded: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => v == null ? 'Pick a reason' : null,
                items: [
                  for (final r in kFineReasons)
                    DropdownMenuItem(
                      value: r,
                      child: Text(r, style: const TextStyle(fontSize: 14)),
                    ),
                ],
                onChanged: (v) => setState(() => _reason = v),
              ),
              if (_reason == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.recordFineSpecifyReason),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Describe the reason'
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              PaymentMethodPanel(
                value: _method,
                online: _online != null && _online!.canCharge(_memberId),
                switchedOff: _online?.switchedOff ?? const {},
                codeController: _codeCtrl,
                onChanged: (m) => setState(() => _method = m),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _record,
                icon: Icon(paymentActionIcon(_method), size: 18),
                label: Text(paymentActionLabel(l10n, _method, l10n.meetingHubRecordFine)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _record() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final appState = context.read<AppState>();
    final meetingProvider = context.read<MeetingProvider>();
    final amount = double.parse(_amountCtrl.text);
    // M-Pesa / Paystack: the member approves on their own phone first, and
    // the fine is recorded once the server confirms the money. Cash and
    // M-Pesa Classic (code typed above) are recorded straight away.
    final settled = await settlePayment(
      context,
      online: _online,
      method: _method,
      purpose: PaymentPurpose.fine,
      amount: amount,
      localMemberId: _memberId!,
      typedCode: _codeCtrl.text,
    );
    if (settled == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final reason =
          _reason == 'Other' ? _reasonCtrl.text.trim() : _reason!;
      await meetingProvider.recordFine(
        memberId: _memberId!,
        amount: amount,
        reason: reason,
        groupPaymentId: settled.groupPaymentId,
        paymentMethod: settled.method,
        paymentReference: settled.reference,
      );
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'Fine recorded.');
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
