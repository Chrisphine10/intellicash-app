import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/remote_visits_api.dart';
import '../../shared/widgets/numeric_keypad.dart';

/// Step one of a visit: someone from the group enters their 4-digit PIN.
///
/// This is the whole point of the mechanism — it is the group attesting that
/// the agent is standing in front of them. So the phone is handed over here,
/// and the copy says so plainly rather than leaving the agent to type it
/// themselves out of habit.
class VisitPinScreen extends StatefulWidget {
  const VisitPinScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<VisitPinScreen> createState() => _VisitPinScreenState();
}

class _VisitPinScreenState extends State<VisitPinScreen> {
  static const _pinLength = 4;

  String _pin = '';
  bool _checking = false;
  String? _error;
  bool _locked = false;

  Future<void> _verify() async {
    if (_pin.length != _pinLength || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    final api = context.read<RemoteVisitsApi>();
    final result = await api.verifyPin(groupId: widget.groupId, pin: _pin);
    if (!mounted) return;

    if (result.verified) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _checking = false;
      _pin = '';
      _locked = result.failure == VisitPinFailure.locked;
      _error = switch (result.failure) {
        VisitPinFailure.wrong => 'That PIN is not correct. Try again.',
        VisitPinFailure.locked =>
          result.message ?? 'Too many wrong attempts. Try again in a few minutes.',
        VisitPinFailure.notSet =>
          'This group has no visit PIN yet. An official or an administrator '
              'needs to set one before a visit can be recorded.',
        VisitPinFailure.offline =>
          'No connection, so the PIN cannot be checked yet. Try again when you '
              'have signal.',
        _ => result.message ?? 'The PIN could not be checked.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start visit')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              Card(
                color: AppColors.primaryTint,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.groupName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hand the phone to a group official. Their 4-digit visit '
                        'PIN confirms you are here.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_checking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                )
              else
                NumericKeypad(
                  length: _pinLength,
                  value: _pin,
                  enabled: !_locked,
                  onChanged: (value) => setState(() {
                    _pin = value;
                    _error = null;
                  }),
                  onSubmit: _verify,
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.defaulted),
                ),
              ],
              if (_locked) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Back to my groups'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
