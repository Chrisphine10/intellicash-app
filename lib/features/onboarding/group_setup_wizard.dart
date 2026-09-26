import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../../data/models/group.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/meeting_schedule_provider.dart';
import '../../core/utils/meeting_schedule.dart';
import '../members/member_sign_ins_switch.dart';
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
  static const _stepTitles = ['Basics', 'Shares', 'Loans', 'Schedule'];

  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());
  int _step = 0;

  /// Shown under the member field. It was a snack bar, which appeared behind the
  /// Next button at the foot of the screen - the person pressed Next and, as far
  /// as they could tell, nothing happened.
  String? _membersError;
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
  // When the group meets, and whether members are reminded. Reminders only:
  // a meeting still starts when an official taps Start Meeting.
  late TimeOfDay _meetingTime;
  late bool _remindersEnabled;

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
    _savingsMode = SavingsMode.fixed;
    _shareValueCtrl =
        TextEditingController(text: _trimNum(g?.shareValue ?? 100));
    _maxSharesCtrl =
        TextEditingController(text: '${g?.maxSharesPerMeeting ?? 10}');
    _socialFundCtrl =
        TextEditingController(text: _trimNum(g?.socialFundAmount ?? 50));
    // A new group starts on the platform's own loan model: flat monthly interest
    // on the amount borrowed, 10% a month, up to 3x savings, for 1 month. It is
    // the only model the online record can express, so a group that keeps these
    // sees the same loan totals on the phone and on the console.
    _interestType = g?.interestType ?? InterestType.flat;
    _interestRateCtrl =
        TextEditingController(text: _trimNum(g?.interestRate ?? 10));
    _multiplierCtrl =
        TextEditingController(text: _trimNum(g?.loanMultiplier ?? 3));
    _termCtrl =
        TextEditingController(text: '${g?.defaultLoanTermMonths ?? 1}');
    _frequency = g?.meetingFrequency ?? MeetingFrequency.weekly;
    _meetingDays.addAll(g?.meetingDays ?? const [DateTime.sunday]);
    final time = parseMeetingTime(g?.meetingTime ?? '14:00');
    _meetingTime = TimeOfDay(hour: time.hour, minute: time.minute);
    _remindersEnabled = g?.remindersEnabled ?? true;
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
    final l10n = L10n.of(context);
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
                        child: Text(l10n.back),
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
    final l10n = L10n.of(context);
    return [
      const SectionLabel('Group basics', padding: EdgeInsets.only(bottom: 12)),
      TextFormField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.groupSetupWizardGroupName),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter the group name' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _cycleCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.groupSetupWizardCycleNumber,
          helperText: l10n.groupSetupWizardWhichSavingsCycleIsThis,
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (v) =>
            (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter a cycle of 1 or more' : null,
      ),
      if (_isEdit) ...[
        const SizedBox(height: 16),
        // The group's own switch, kept on the server so every phone, the
        // console and the members' sign-ins follow the same answer.
        MemberSignInsSwitch(localGroupId: widget.existing!.id),
      ],
      if (!_isEdit) ...[
        const SectionLabel('Founding members'),
        Text(
          l10n.groupSetupWizardAddTheMembersJoiningThis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _memberCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.groupSetupWizardMemberName),
                onFieldSubmitted: (_) => _addMemberName(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _addMemberName,
              icon: const Icon(Icons.add),
              tooltip: l10n.groupSetupWizardAddMember,
            ),
          ],
        ),
        if (_membersError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _membersError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
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
                tooltip: l10n.groupSetupWizardRemove,
              ),
            ),
          ),
      ],
    ];
  }

  List<Widget> _savingsStep() {
    final l10n = L10n.of(context);
    return [
      const SectionLabel('Shares configuration',
          padding: EdgeInsets.only(bottom: 4)),
      // Members save by buying shares at the group's share value. ("Flexible"
      // saving used to be offered here but was never built anywhere else, so
      // choosing it changed nothing; it is gone and every group buys shares.)
      Text(
        l10n.groupSetupWizardEveryoneBuysSharesAtOne,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _shareValueCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: l10n.groupSetupWizardShareValueKsh),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: _positiveAmount,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _maxSharesCtrl,
        keyboardType: TextInputType.number,
        decoration:
            InputDecoration(labelText: l10n.groupSetupWizardMaxSharesPerMeeting),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (v) =>
            (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter 1 or more' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _socialFundCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.groupSetupWizardSocialFundPerMeetingKsh,
          helperText: l10n.groupSetupWizardTrackedSeparatelyFromSavings,
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
    final l10n = L10n.of(context);
    return [
      const SectionLabel('Loan configuration',
          padding: EdgeInsets.only(bottom: 12)),
      TextFormField(
        controller: _interestRateCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.groupSetupWizardInterestRatePerMonth,
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
      // Said where the choice is made, not discovered later as two different
      // loan totals for the same loan.
      if (_interestType == InterestType.reducingBalance)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l10n.groupSetupWizardReducingNote,
            style: TextStyle(fontSize: 12, color: AppColors.pending),
          ),
        ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _multiplierCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.groupSetupWizardMaxLoanMultiplierSavings,
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: _positiveAmount,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _termCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.groupSetupWizardDefaultLoanTermMonths,
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (v) =>
            (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter 1 or more' : null,
      ),
      const SizedBox(height: 8),
      _helperCard(
        'Members can borrow up to ${_multiplierCtrl.text}× their '
        'total shares.',
      ),
    ];
  }

  List<Widget> _scheduleStep() {
    final l10n = L10n.of(context);
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
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(l10n.meetingsMeetingTime),
        trailing: Text(_meetingTime.format(context),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () async {
          final picked =
              await showTimePicker(context: context, initialTime: _meetingTime);
          if (picked != null) setState(() => _meetingTime = picked);
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.meetingsSendReminders),
        subtitle: Text(l10n.meetingsRemindersNote,
            style: Theme.of(context).textTheme.bodySmall),
        value: _remindersEnabled,
        onChanged: (on) => setState(() => _remindersEnabled = on),
      ),
      const SizedBox(height: 12),
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
      setState(() => _membersError = '$name is already on the list.');
      return;
    }
    setState(() {
      _memberNames.add(name);
      _memberCtrl.clear();
      _membersError = null;
    });
  }

  String? _positiveAmount(String? v) =>
      (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter an amount above zero' : null;

  String? _nonNegativeAmount(String? v) =>
      (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a valid amount' : null;

  Future<void> _next() async {
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return;
    if (_step == 0 && !_isEdit && _memberNames.isEmpty) {
      setState(() => _membersError = 'Add at least one founding member.');
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
          meetingTime: formatMeetingTime(_meetingTime.hour, _meetingTime.minute),
          remindersEnabled: _remindersEnabled,
        ));
        // New days or time: re-plan the phone's reminders, and send the
        // schedule up so members are texted for the right day.
        if (mounted) {
          final group = appState.group;
          if (group != null) {
            unawaited(context.read<MeetingScheduleProvider>().load(group));
          }
        }
        unawaited(appState.syncNow());
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
          meetingTime: formatMeetingTime(_meetingTime.hour, _meetingTime.minute),
          remindersEnabled: _remindersEnabled,
          memberNames: _memberNames,
        );
        // Link the new group and send its founding members up straight away,
        // rather than after the next reconnect or the ten-minute timer: the
        // console showed a group with no members for up to ten minutes.
        unawaited(appState.syncNow());
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
