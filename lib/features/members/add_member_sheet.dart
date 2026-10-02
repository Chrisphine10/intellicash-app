import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../../data/services/member_matching.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';

class AddMemberSheet extends StatefulWidget {
  const AddMemberSheet({super.key});

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  MemberRole _role = MemberRole.member;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
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
              Text(l10n.addMemberAddMember,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.addMemberFullName),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the member\'s name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.addMemberPhoneOptional,
                  hintText: '07XX XXX XXX',
                ),
                // Optional, but if it is typed it must look like a number. The
                // same rule as the server's, so a member saved here is never
                // turned away when the phone sends it up: "12345" used to be
                // accepted and then refused at sync, leaving the member on this
                // phone only.
                validator: (v) => (v == null || v.trim().isEmpty || looksLikePhone(v))
                    ? null
                    : 'Enter a valid phone number, or leave it empty',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MemberRole>(
                isExpanded: true,
                initialValue: _role,
                decoration: InputDecoration(labelText: l10n.addMemberRole),
                dropdownColor: AppColors.surfaceRaised,
                items: [
                  for (final role in MemberRole.values)
                    DropdownMenuItem(
                      value: role,
                      child: Text(role.label,
                          style: const TextStyle(fontSize: 14)),
                    ),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: Text(l10n.addMemberRegisterMember),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final appState = context.read<AppState>();
    final memberProvider = context.read<MemberProvider>();

    // Two members of one group cannot share a number — the server refuses the
    // second at sync, which would leave that member on this phone only. Say so
    // now, at the table, with no signal needed.
    final typed = _phoneCtrl.text.trim();
    if (typed.isNotEmpty) {
      final canonical = normalisePhone(typed);
      for (final row in memberProvider.members) {
        if (normalisePhone(row.member.phone) == canonical) {
          showAppSnack(
            context,
            '${row.member.name} already uses that number. Two members cannot share one — it is how the group tells them apart.',
            error: true,
          );
          return;
        }
      }
    }
    setState(() => _saving = true);
    try {
      final member = await memberProvider.addMember(
        groupId: appState.group!.id,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        role: _role,
      );
      await appState.refreshPendingSync();
      // Send the new member up now, while there is signal: a member the server
      // has not heard of cannot be marked present or credited at the next
      // meeting. A no-op offline or when the group is not linked yet.
      unawaited(appState.syncNow());
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, '${member.name} registered.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
