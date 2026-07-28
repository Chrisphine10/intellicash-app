import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';

/// Common VSLA fine reasons offered as presets; "Other" reveals a free-text
/// field for anything not listed.
const List<String> kFineReasons = [
  'Late arrival',
  'Absent without apology',
  'Missed savings contribution',
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
  String? _memberId;
  String? _reason;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<MemberProvider>().members;

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
            Text('Record Fine',
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
              onChanged: (v) => setState(() => _memberId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (KSh)'),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Enter an amount above zero'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              dropdownColor: AppColors.surfaceRaised,
              isExpanded: true,
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
                decoration: const InputDecoration(labelText: 'Specify reason'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Describe the reason'
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _record,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Record Fine'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _record() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final meetingProvider = context.read<MeetingProvider>();
    try {
      final reason =
          _reason == 'Other' ? _reasonCtrl.text.trim() : _reason!;
      await meetingProvider.recordFine(
        memberId: _memberId!,
        amount: double.parse(_amountCtrl.text),
        reason: reason,
      );
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'Fine recorded.');
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
