import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/remote_governance_api.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// A group's own rules.
///
/// Two settings only. The screen also names the rules that are FIXED, because
/// an official looking for share-out eligibility switches should learn they are
/// decided rather than assume the app is missing them.
class GroupPolicyScreen extends StatefulWidget {
  const GroupPolicyScreen({super.key});

  @override
  State<GroupPolicyScreen> createState() => _GroupPolicyScreenState();
}

class _GroupPolicyScreenState extends State<GroupPolicyScreen> {
  RemoteGroupPolicy? _policy;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int _term = 1;
  String _fund = 'SOCIAL';

  static const _funds = <String, String>{
    'SOCIAL': 'Welfare (social) fund',
    'SAVINGS': 'Savings fund',
    'INTERNAL_LOAN': 'Loan fund',
  };

  String? get _groupId => context.read<ConnectionProvider>().selectedGroup?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
      final policy = await context.read<RemoteGovernanceApi>().policy(groupId);
      if (!mounted) return;
      setState(() {
        _policy = policy;
        _term = policy.defaultLoanTermMonths;
        _fund = policy.expenseFundType;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final message = await context.read<RemoteGovernanceApi>().savePolicy(
            _groupId!,
            defaultLoanTermMonths: _term,
            expenseFundType: _fund,
          );
      await _load();
      if (!mounted) return;
      showAppSnack(context, message);
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
      appBar: AppBar(title: const Text('Group Rules')),
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
    final policy = _policy;
    if (policy == null) return const SizedBox.shrink();
    final editable = policy.canConfigure && !_saving;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          policy.configured
              ? 'This group uses its own rules.'
              : 'This group uses the standard rules.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        Text('How long a loan runs', style: Theme.of(context).textTheme.titleSmall),
        Row(
          children: [
            Expanded(
              child: Slider(
                divisions: 11,
                label: '$_term month(s)',
                max: 12,
                min: 1,
                onChanged: editable ? (v) => setState(() => _term = v.round()) : null,
                value: _term.toDouble().clamp(1, 12),
              ),
            ),
            SizedBox(width: 64, child: Text('$_term mo')),
          ],
        ),
        Text(
          'Applies to new loans. Loans already given keep the term they were '
          'agreed with — changing this never changes what a member already owes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),

        Text('Expenses are paid from', style: Theme.of(context).textTheme.titleSmall),
        DropdownButtonFormField<String>(
          initialValue: _fund,
          items: [
            for (final entry in _funds.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: editable ? (v) => setState(() => _fund = v ?? _fund) : null,
        ),
        const SizedBox(height: 12),

        if (policy.canConfigure)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save rules'),
          )
        else
          Text(
            'You can see these rules but not change them. Only the group account '
            'or a platform admin can.',
            style: Theme.of(context).textTheme.bodySmall,
          ),

        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rules that are fixed',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Unpaid fines and welfare are taken off a member\'s share-out '
                  'payout — they never stop a member from sharing out.\n\n'
                  'Outstanding loans are taken off at share-out and are never '
                  'carried into the next cycle.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
