import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A 0–9 keypad for entering a PIN.
///
/// Built rather than reusing the system keyboard for two reasons that matter in
/// the field: the soft keyboard on a low-end handset opens on a letter layout
/// and has to be switched to numbers every time, and it covers most of a small
/// screen at the moment the person needs to see how many digits they have
/// entered. This is always digits, always visible, and has targets big enough
/// for someone holding the phone at arm's length in sunlight.
///
/// Generic over length so the 6-digit member PIN screens can adopt it later
/// without a second implementation.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.length,
    required this.value,
    required this.onChanged,
    this.onSubmit,
    this.enabled = true,
  });

  /// How many digits make a complete entry.
  final int length;
  final String value;
  final ValueChanged<String> onChanged;

  /// Called when the last digit is entered. Optional: some callers submit from
  /// their own button instead.
  final VoidCallback? onSubmit;
  final bool enabled;

  void _press(String digit) {
    if (!enabled || value.length >= length) return;
    final next = '$value$digit';
    onChanged(next);
    if (next.length == length) onSubmit?.call();
  }

  void _backspace() {
    if (!enabled || value.isEmpty) return;
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PinDots(length: length, filled: value.length),
        const SizedBox(height: 28),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final digit in row)
                  _Key(label: digit, onTap: enabled ? () => _press(digit) : null),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty cell keeps 0 centred under 8, where a thumb expects it.
            const SizedBox(width: 84, height: 68),
            _Key(label: '0', onTap: enabled ? () => _press('0') : null),
            _Key(
              icon: Icons.backspace_outlined,
              semanticLabel: 'Delete',
              onTap: enabled && value.isNotEmpty ? _backspace : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.filled});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i += 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: i < filled ? 18 : 16,
              height: i < filled ? 18 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: i < filled ? AppColors.primary : AppColors.outline,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.semanticLabel, required this.onTap});

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: SizedBox(
        width: 84,
        height: 68,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 24,
                      color: disabled ? AppColors.textSecondary : AppColors.textPrimary,
                    )
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: disabled ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
