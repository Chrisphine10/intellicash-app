import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/remote/membership.dart';
import '../../providers/connection_provider.dart';

/// Where a member asks a group to add them, using the code on the group's
/// records.
///
/// Asking is not joining: the group's officials decide, and nothing of the
/// group's money is visible until they do. The screen says so plainly, so
/// nobody is left wondering why the passbook is still empty afterwards.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the group code first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final connection = context.read<ConnectionProvider>();
    try {
      final groupName = await connection.api.requestToJoinGroup(code);
      if (mounted) setState(() => _sentTo = groupName);
    } on ApiException catch (e) {
      // The backend words these for members already ("No group has that
      // code. Check it with your group's secretary."), so show them as-is.
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send your request. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return Scaffold(
      appBar: AppBar(title: const Text('Join a group')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (sentTo != null) ...[
            Card(
              color: AppColors.surfaceRaised,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Request sent',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We have asked $sentTo to add you. An official of the '
                      'group will accept or decline it. Your savings will '
                      'show here once they accept.',
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ] else ...[
            const Text(
              'Ask your group to add you',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your group has a code on its records — ask the secretary if '
              'you do not know it. Sending a request does not open the '
              'group\'s books to you; an official has to accept you first.',
              style: TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Group code',
                hintText: 'IWL-KBU-0001',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: AppColors.defaulted),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send request'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lets a member move between the groups they save with.
///
/// Only worth showing when there is more than one — most people have a single
/// group and should not be made to think about this at all.
class GroupSwitcher extends StatelessWidget {
  const GroupSwitcher({
    super.key,
    required this.memberships,
    required this.onSwitch,
  });

  final List<Membership> memberships;
  final ValueChanged<Membership> onSwitch;

  @override
  Widget build(BuildContext context) {
    if (memberships.length < 2) return const SizedBox.shrink();
    final active = memberships.firstWhere(
      (m) => m.isActive,
      orElse: () => memberships.first,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: AppColors.surfaceRaised,
        child: PopupMenuButton<Membership>(
          onSelected: onSwitch,
          itemBuilder: (context) => [
            for (final m in memberships)
              PopupMenuItem<Membership>(
                value: m,
                child: Row(
                  children: [
                    Icon(
                      m.isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: m.isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(m.groupName,
                          style: const TextStyle(fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.groups_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viewing',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        active.groupName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_more,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
