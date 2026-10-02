import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';
import 'payment_method_button.dart';

/// Checks an M-Pesa confirmation code as a member reads it off their SMS:
/// letters and digits only, 10 characters (8–12 accepted for older codes).
String? validateMpesaCode(String? value, L10n l10n) {
  final code = (value ?? '').trim().toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{8,12}$').hasMatch(code)) return l10n.mpesaCodeInvalid;
  return null;
}

/// The label of the button that completes a payment, for the method chosen.
String paymentActionLabel(L10n l10n, PaymentMethod method, String recordLabel) => switch (method) {
      PaymentMethod.mpesa => l10n.paySendMpesaPrompt,
      PaymentMethod.paystack => l10n.payCreatePaystackLink,
      _ => recordLabel,
    };

IconData paymentActionIcon(PaymentMethod method) =>
    method.automated ? Icons.phone_android : Icons.check;

/// The payment card used at every payment point: how the member is paying,
/// as four equal tiles, and — only for M-Pesa Classic — the code to type.
///
/// M-Pesa and Paystack are charged online, so they need the book to be
/// online; offline — or switched off for the group — they show but cannot be
/// chosen, and say why.
class PaymentMethodPanel extends StatelessWidget {
  const PaymentMethodPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.online,
    required this.codeController,
    this.title,
    this.switchedOff = const {},
  });

  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;

  /// Whether this book can charge members online right now.
  final bool online;

  /// Holds the M-Pesa Classic code; validated by the surrounding form.
  final TextEditingController codeController;
  final String? title;

  /// Online methods the group has switched off (Payments settings).
  final Set<PaymentMethod> switchedOff;

  String _hint(L10n l10n, PaymentMethod method) => switchedOff.contains(method)
      ? l10n.payHintSwitchedOff
      : switch (method) {
        PaymentMethod.cash => l10n.payHintCash,
        PaymentMethod.mpesa => online ? l10n.payHintMpesa : l10n.payHintNeedsInternet,
        PaymentMethod.mpesaClassic => l10n.payHintClassic,
        PaymentMethod.paystack => online ? l10n.payHintPaystack : l10n.payHintNeedsInternet,
        PaymentMethod.card => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title ?? l10n.payMethodTitle,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in PaymentMethod.offered)
                    SizedBox(
                      width: tileWidth,
                      child: _MethodTile(
                        method: method,
                        hint: _hint(l10n, method),
                        selected: value == method,
                        enabled: !method.automated || (online && !switchedOff.contains(method)),
                        onTap: () => onChanged(method),
                      ),
                    ),
                ],
              );
            },
          ),
          if (value == PaymentMethod.mpesaClassic) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: l10n.mpesaCodeLabel,
                hintText: l10n.mpesaCodeHint,
                filled: true,
                fillColor: AppColors.surface,
              ),
              validator: (v) => validateMpesaCode(v, l10n),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.hint,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PaymentMethod method;
  final String hint;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = paymentLogoAsset(method);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${method.label}. $hint',
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            // One height for all four, so the grid lines up whatever the hint —
            // grown with the phone's font size, or larger text is cut off.
            height: MediaQuery.textScalerOf(context).scale(118).clamp(118.0, 200.0),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryTint : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppColors.primary : AppColors.outline, width: selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: logo != null
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                child: Image.asset(logo, height: 20, excludeFromSemantics: true),
                              ),
                            )
                          : Row(
                              children: [
                                Icon(Icons.payments_outlined, size: 20, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    method.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18,
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Every tile names its method: two share the M-Pesa mark.
                if (logo != null)
                  Text(method.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.25),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
