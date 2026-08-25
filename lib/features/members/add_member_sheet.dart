import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
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
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MemberRole>(
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
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final memberProvider = context.read<MemberProvider>();
    try {
      final member = await memberProvider.addMember(
        groupId: appState.group!.id,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        role: _role,
      );
      await appState.refreshPendingSync();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, '${member.name} registered.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
