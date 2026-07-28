import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../../data/models/group.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// The 4-step group constitution wizard: Basics, Savings, Loans, Schedule.
///
/// Create mode captures founding members too; pass [existing] to edit the
/// rules of a group that is already running.
class GroupSetupWizard extends StatefulWidget {
  const GroupSetupWizard({super.key, this.existing});

  final Group? existing;

  @override
  State<GroupSetupWizard> createState() => _GroupSetupWizardState();
}

class _GroupSetupWizardState extends State<GroupSetupWizard> {
  static const _stepTitles = ['Basics', 'Savings', 'Loans', 'Schedule'];

  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _saving = false;

  // Step 1 — Basics
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cycleCtrl;
  final _memberCtrl = TextEditingController();
  final List<String> _memberNames = [];

  // Step 2 — Savings
  late SavingsMode _savingsMode;
  late final TextEditingController _shareValueCtrl;
  late final TextEditingController _maxSharesCtrl;
  late final TextEditingController _socialFundCtrl;

  // Step 3 — Loans
  late InterestType _interestType;
  late final TextEditingController _interestRateCtrl;
  late final TextEditingController _multiplierCtrl;
  late final TextEditingController _termCtrl;

  // Step 4 — Schedule
  late MeetingFrequency _frequency;
  final Set<int> _meetingDays = {};

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    // No repetition: a fresh setup starts from the group name the account
    // was registered with (a group account's name IS the group's name).
    final accountName =
        context.read<ConnectionProvider>().signedInUser?.name ?? '';
    _nameCtrl = TextEditingController(text: g?.name ?? accountName);
    _cycleCtrl = TextEditingController(text: '${g?.cycleNumber ?? 1}');
    _savingsMode = g?.savingsMode ?? SavingsMode.fixed;
    _shareValueCtrl =
        TextEditingController(text: _trimNum(g?.shareValue ?? 100));
    _maxSharesCtrl =
        TextEditingController(text: '${g?.maxSharesPerMeeting ?? 10}');
    _socialFundCtrl =
        TextEditingController(text: _trimNum(g?.socialFundAmount ?? 50));
    _interestType = g?.interestType ?? InterestType.reducingBalance;
    _interestRateCtrl =
        TextEditingController(text: _trimNum(g?.interestRate ?? 5));
    _multiplierCtrl =
        TextEditingController(text: _trimNum(g?.loanMultiplier ?? 2));
    _termCtrl =
        TextEditingController(text: '${g?.defaultLoanTermMonths ?? 3}');
    _frequency = g?.meetingFrequency ?? MeetingFrequency.weekly;
    _meetingDays.addAll(g?.meetingDays ?? const [DateTime.sunday]);
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  @override
  void dispose() {
    for (final ctrl in [
      _nameCtrl,
      _cycleCtrl,
      _memberCtrl,
      _shareValueCtrl,
      _maxSharesCtrl,
      _socialFundCtrl,
      _interestRateCtrl,
      _multiplierCtrl,
      _termCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Group Settings' : 'Set Up Your Group')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _StepperHeader(step: _step, titles: _stepTitles),
            ),
            Expanded(
              child: Form(
                key: _formKeys[_step],
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: switch (_step) {
                    0 => _basicsStep(),
                    1 => _savingsStep(),
                    2 => _loansStep(),
                    _ => _scheduleStep(),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_step < 3
                              ? 'Next'
                              : _isEdit
                                  ? 'Save Changes'
                                  : 'Create Group'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- steps ----------

  List<Widget> _basicsStep() {
    return [
      const SectionLabel('Group basics', padding: EdgeInsets.only(bottom: 12)),
      TextFormField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Group Name'),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter the group name' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _cycleCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Cycle Number',
          helperText: 'Which savings cycle is this group on?',
        ),
        validator: (v) =>
            (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter a cycle of 1 or more' : null,
      ),
      if (!_isEdit) ...[
        const SectionLabel('Founding members'),
        Text(
          'Add the members joining this cycle. You can always add more later.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _memberCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Member Name'),
                onFieldSubmitted: (_) => _addMemberName(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _addMemberName,
              icon: const Icon(Icons.add),
              tooltip: 'Add member',
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (i, name) in _memberNames.indexed)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: MemberAvatar(name),
              title: Text(name, style: const TextStyle(fontSize: 14)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _memberNames.removeAt(i)),
                tooltip: 'Remove',
              ),
            ),
          ),
      ],
    ];
  }

  List<Widget> _savingsStep() {
    return [
      const SectionLabel('Savings configuration',
          padding: EdgeInsets.only(bottom: 4)),
      RadioGroup<SavingsMode>(
        groupValue: _savingsMode,
        onChanged: (v) => setState(() => _savingsMode = v!),
        child: Column(
          children: [
            RadioListTile<SavingsMode>(
              value: SavingsMode.fixed,
              title: Text(SavingsMode.fixed.label),
              subtitle: const Text('Everyone buys shares at one fixed price'),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<SavingsMode>(
              value: SavingsMode.flexible,
              title: Text(SavingsMode.flexible.label),
              subtitle: const Text('Members save what they can each meeting'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _shareValueCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Share Value (KSh)'),
        validator: _positiveAmount,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _maxSharesCtrl,
        keyboardType: TextInputType.number,
        decoration:
            const InputDecoration(labelText: 'Max Shares per Meeting'),
        validator: (v) =>
            (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter 1 or more' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _socialFundCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Social Fund per Meeting (KSh)',
          helperText: 'Tracked separately from savings',
        ),
        validator: _nonNegativeAmount,
      ),
      const SizedBox(height: 8),
      _helperCard(
        'Members buy 1–${_maxSharesCtrl.text} shares of '
        'KSh ${_shareValueCtrl.text} at every meeting.',
      ),
    ];
  }

  List<Widget> _loansStep() {
    return [
      const SectionLabel('Loan configuration',
          padding: EdgeInsets.only(bottom: 12)),
      TextFormField(
        controller: _interestRateCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Interest Rate (% per month)',
        ),
        validator: _nonNegativeAmount,
      ),
      const SizedBox(height: 8),
      RadioGroup<InterestType>(
        groupValue: _interestType,
        onChanged: (v) => setState(() => _interestType = v!),
        child: Column(
          children: [
            RadioListTile<InterestType>(
              value: InterestType.flat,
              title: Text(InterestType.flat.label),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<InterestType>(
              value: InterestType.reducingBalance,
              title: Text(InterestType.reducingBalance.label),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _multiplierCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Max Loan Multiplier (× savings)',
        ),
        validator: _positiveAmount,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _termCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Default Loan Term (months)',
        ),
        validator: (v) =>
            (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter 1 or more' : null,
      ),
      const SizedBox(height: 8),
      _helperCard(
        'Members can borrow up to ${_multiplierCtrl.text}× their '
        'total savings.',
      ),
    ];
  }

  List<Widget> _scheduleStep() {
    return [
      const SectionLabel('Meeting schedule',
          padding: EdgeInsets.only(bottom: 12)),
      Wrap(
        spacing: 8,
        children: [
          for (final freq in MeetingFrequency.values)
            ChoiceChip(
              label: Text(freq.label),
              selected: _frequency == freq,
              selectedColor: AppColors.primaryTint,
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _frequency == freq
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
              onSelected: (_) => setState(() => _frequency = freq),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        _frequency == MeetingFrequency.monthly
            ? 'Meeting day(s) of the week'
            : 'Meeting day(s) — pick one or more',
        style: const TextStyle(fontSize: 14),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (i, day) in Group.weekdayShort.indexed)
            FilterChip(
              label: Text(day),
              selected: _meetingDays.contains(i + 1),
              selectedColor: AppColors.primaryTint,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _meetingDays.contains(i + 1)
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
              onSelected: (on) => setState(() {
                if (on) {
                  _meetingDays.add(i + 1);
                } else if (_meetingDays.length > 1) {
                  _meetingDays.remove(i + 1);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: 20),
      _helperCard(
        '${_nameCtrl.text.trim().isEmpty ? 'Your group' : _nameCtrl.text.trim()} '
        'meets ${_frequency.label.toLowerCase()} on '
        '${_daysLabel()}. '
        '${_isEdit ? '' : '${_memberNames.length} founding member(s) will be registered.'}',
      ),
    ];
  }

  String _daysLabel() {
    final days = _meetingDays.toList()..sort();
    if (days.isEmpty) return 'no day selected';
    if (days.length == 1) return '${Group.weekdayNames[days.first - 1]}s';
    return days.map((d) => Group.weekdayShort[d - 1]).join(', ');
  }

  Widget _helperCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- behavior ----------

  void _addMemberName() {
    final name = _memberCtrl.text.trim();
    if (name.isEmpty) return;
    final exists =
        _memberNames.any((n) => n.toLowerCase() == name.toLowerCase());
    if (exists) {
      showAppSnack(context, '$name is already on the list.', error: true);
      return;
    }
    setState(() {
      _memberNames.add(name);
      _memberCtrl.clear();
    });
  }

  String? _positiveAmount(String? v) =>
      (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter an amount above zero' : null;

  String? _nonNegativeAmount(String? v) =>
      (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a valid amount' : null;

  Future<void> _next() async {
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return;
    if (_step == 0 && !_isEdit && _memberNames.isEmpty) {
      showAppSnack(context, 'Add at least one founding member.', error: true);
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    try {
      if (_isEdit) {
        await appState.updateGroup(widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          cycleNumber: int.parse(_cycleCtrl.text),
          savingsMode: _savingsMode,
          shareValue: double.parse(_shareValueCtrl.text),
          maxSharesPerMeeting: int.parse(_maxSharesCtrl.text),
          socialFundAmount: double.parse(_socialFundCtrl.text),
          interestRate: double.parse(_interestRateCtrl.text),
          interestType: _interestType,
          loanMultiplier: double.parse(_multiplierCtrl.text),
          defaultLoanTermMonths: int.parse(_termCtrl.text),
          meetingFrequency: _frequency,
          meetingDays: _meetingDays.toList()..sort(),
        ));
        if (mounted) {
          Navigator.of(context).pop();
          showAppSnack(context, 'Group settings saved.');
        }
      } else {
        await appState.createGroup(
          name: _nameCtrl.text,
          cycleNumber: int.parse(_cycleCtrl.text),
          savingsMode: _savingsMode,
          shareValue: double.parse(_shareValueCtrl.text),
          maxSharesPerMeeting: int.parse(_maxSharesCtrl.text),
          socialFundAmount: double.parse(_socialFundCtrl.text),
          interestRate: double.parse(_interestRateCtrl.text),
          interestType: _interestType,
          loanMultiplier: double.parse(_multiplierCtrl.text),
          defaultLoanTermMonths: int.parse(_termCtrl.text),
          meetingFrequency: _frequency,
          meetingDays: _meetingDays.toList()..sort(),
          memberNames: _memberNames,
        );
        // When the wizard was pushed (from the welcome screen), pop back so
        // the root can show the main shell — the app state is now `ready`.
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StepperHeader extends StatelessWidget {
  const _StepperHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, title) in titles.indexed)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= step
                        ? AppColors.primary
                        : AppColors.surfaceRaised,
                  ),
                  child: Center(
                    child: i < step
                        ? Icon(Icons.check,
                            size: 15, color: AppColors.onPrimary)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: i <= step
                                  ? AppColors.onPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                    color: i == step
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
