import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/member.dart';
import '../../data/services/member_matching.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';

/// Correct a member's name or phone number.
///
/// The name is cosmetic. The phone is not: it is how this person is matched to
/// their savings when a phone syncs or when they ask to join from their own
/// handset. Two members on one number means somebody's contributions land in
/// the wrong passbook, so the duplicate check runs HERE too — the server
/// refuses it, but a secretary editing at a meeting table has no signal to
/// hear that refusal.
class EditMemberSheet extends StatefulWidget {
  const EditMemberSheet({super.key, required this.member});

  final Member member;

  static Future<bool?> show(BuildContext context, Member member) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: EditMemberSheet(member: member),
      ),
    );
  }

  @override
  State<EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<EditMemberSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.member.name);
  late final TextEditingController _phone =
      TextEditingController(text: widget.member.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();

    if (name.length < 2) {
      setState(() => _error = 'Enter the member\'s name.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'A member needs a phone number — it is how they are recognised.');
      return;
    }

    final provider = context.read<MemberProvider>();
    final canonical = normalisePhone(phone);

    // Same rule the server enforces, checked here so an edit made with no
    // signal fails at the table rather than silently at the next sync.
    Member? clash;
    for (final row in provider.members) {
      if (row.member.id == widget.member.id) continue;
      if (normalisePhone(row.member.phone) == canonical) {
        clash = row.member;
        break;
      }
    }
    if (clash != null) {
      setState(() => _error =
          '${clash!.name} already uses that number. Two members cannot share one — '
          'it is how the group tells them apart.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await provider.updateMember(
        widget.member.copyWith(name: name, phone: phone),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showAppSnack(context, 'Member details updated.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit member', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Correcting a spelling or a mistyped number. Their savings, loans '
              'and attendance stay exactly as they are.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                helperText: '07XX XXX XXX or +254…',
              ),
              enabled: !_saving,
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
