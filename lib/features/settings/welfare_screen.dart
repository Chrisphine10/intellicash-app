import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/remote_models.dart';
import '../../data/services/remote_api.dart';
import '../../data/services/remote_governance_api.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// The welfare (social) fund — what has been paid out, and what is left.
///
/// The screen leads with the REMAINING balance rather than the total spent,
/// because that is the number members are owed an answer about: the welfare
/// fund is spent down as the cycle runs, and whatever remains at the end is
/// what gets shared out. Money paid to a hospital here is money nobody
/// receives in December.
class WelfareScreen extends StatefulWidget {
  const WelfareScreen({super.key});

  @override
  State<WelfareScreen> createState() => _WelfareScreenState();
}

class _WelfareScreenState extends State<WelfareScreen> {
  RemoteWelfare? _data;
  /// Welfare is recorded DURING a meeting, so the screen needs the open ones.
  List<RemoteMeeting> _openMeetings = const [];
  String? _meetingId;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  final _amount = TextEditingController();
  final _payee = TextEditingController();
  final _note = TextEditingController();
  String _category = 'BEREAVEMENT';

  /// Categories a VSLA actually pays welfare for. Free text is allowed by the
  /// API, but a fixed list keeps a year of records comparable across meetings.
  static const _categories = <String, String>{
    'BEREAVEMENT': 'Bereavement',
    'MEDICAL': 'Medical / hospital',
    'SCHOOL_FEES': 'School fees',
    'EMERGENCY': 'Emergency',
    'CELEBRATION': 'Celebration',
    'OTHER': 'Other',
  };

  String? get _groupId => context.read<ConnectionProvider>().selectedGroup?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groupId = _groupId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _error = 'Choose your group under Cloud Account first.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Both read BEFORE the first await: reading context after an async gap
      // is how a popped screen throws on return.
      final governance = context.read<RemoteGovernanceApi>();
      final remote = context.read<RemoteApi>();
      final data = await governance.welfare(groupId);
      final meetings = await remote.groupMeetings(groupId);
      final open = meetings.where((m) => m.status == 'IN_PROGRESS').toList();
      if (!mounted) return;
      setState(() {
        _data = data;
        _openMeetings = open;
        // One open meeting is the normal case — preselect rather than making
        // an official choose from a list of one.
        _meetingId = open.any((m) => m.id == _meetingId)
            ? _meetingId
            : (open.isEmpty ? null : open.first.id);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _record() async {
    // Captured before the dialog: it is an async gap, and reading context
    // after the screen may have popped is how this throws on return.
    final api = context.read<RemoteGovernanceApi>();
    final groupId = _groupId;
    if (groupId == null) return;

    final shillings = double.tryParse(_amount.text.trim());
    if (shillings == null || shillings <= 0) {
      showAppSnack(context, 'Enter how much was paid.', error: true);
      return;
    }
    if (_payee.text.trim().isEmpty) {
      // The server refuses this too. Asking here saves a round trip and says
      // why in the same breath.
      showAppSnack(context, 'Record who received the money.', error: true);
      return;
    }
    final meetingId = _meetingId;
    if (meetingId == null) {
      showAppSnack(
        context,
        'Open a meeting first — welfare is paid out in front of the members.',
        error: true,
      );
      return;
    }

    final amountCents = (shillings * 100).round();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record this payment?'),
        content: Text(
          '${Formatters.money(amountCents / 100)} to ${_payee.text.trim()}.\n\n'
          'This is taken out of the welfare fund now, so it is money the group '
          'will not share out at the end of the cycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final result = await api.recordWelfareExpense(
        groupId,
        amountCents: amountCents,
        category: _category,
        meetingId: meetingId,
        payeeName: _payee.text.trim(),
        note: _note.text.trim(),
      );
      _amount.clear();
      _payee.clear();
      _note.clear();
      await _load();
      if (!mounted) return;
      showAppSnack(
        context,
        '${result.message} ${Formatters.money(result.balanceCents / 100)} left in the welfare fund.',
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welfare Fund')),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [Text(_error!, style: TextStyle(color: AppColors.defaulted))],
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final online = context.watch<ConnectionProvider>().isConnected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Left in the welfare fund',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  Formatters.money(data.balanceCents / 100),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'This is what gets shared out at the end of the cycle — not the '
                  'total contributed. ${Formatters.money(data.spentCents / 100)} '
                  'has been paid out so far.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('Record a welfare payment',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (!online)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'You are offline. Welfare payments are recorded on the server so '
                'the fund cannot be overspent by two phones at once — reconnect '
                'to record one.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else if (_openMeetings.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No meeting is open. Welfare is paid out during a meeting, in '
                'front of the members — open one first, then record it there.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else ...[
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Recorded in meeting'),
            initialValue: _meetingId,
            items: [
              for (final meeting in _openMeetings)
                DropdownMenuItem(value: meeting.id, child: Text(meeting.title)),
            ],
            onChanged: _saving ? null : (v) => setState(() => _meetingId = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            decoration: const InputDecoration(
              labelText: 'Amount (KSh)',
              prefixText: 'KSh ',
            ),
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'What for'),
            initialValue: _category,
            items: [
              for (final entry in _categories.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _saving ? null : (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _payee,
            decoration: const InputDecoration(
              labelText: 'Paid to',
              helperText: 'A member, a family, or a hospital — whoever received it',
            ),
            enabled: !_saving,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            enabled: !_saving,
            maxLength: 500,
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _record,
            icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
            label: Text(_saving ? 'Recording…' : 'Record payment'),
          ),
        ],

        const SizedBox(height: 20),
        Text('Paid out this cycle', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (data.expenses.isEmpty)
          Text(
            'Nothing paid out yet — the whole welfare fund will be shared.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final expense in data.expenses) _expenseCard(expense),
      ],
    );
  }

  Widget _expenseCard(RemoteWelfareExpense expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _categories[expense.category] ?? expense.category,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  Formatters.money(expense.amountCents / 100),
                  style: TextStyle(fontSize: 14, color: AppColors.defaulted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${expense.payeeName ?? 'Payee not recorded'}'
              '${expense.createdAt == null ? '' : ' · ${Formatters.shortDate(expense.createdAt!)}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (expense.note != null && expense.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(expense.note!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
