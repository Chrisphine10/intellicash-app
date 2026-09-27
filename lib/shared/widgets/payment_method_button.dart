import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';

/// The provider's own logo, where the method has one (M-Pesa, Paystack).
String? paymentLogoAsset(PaymentMethod method) => switch (method) {
      PaymentMethod.mpesa || PaymentMethod.mpesaClassic => 'assets/payments/mpesa.png',
      PaymentMethod.paystack => 'assets/payments/paystack.png',
      _ => null,
    };

/// The logo alone, on its white tile — for lists and headings.
class PaymentLogo extends StatelessWidget {
  const PaymentLogo(this.method, {super.key, this.height = 22});

  final PaymentMethod method;
  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = paymentLogoAsset(method);
    if (asset == null) {
      return Icon(method == PaymentMethod.cash ? Icons.payments_outlined : Icons.credit_card, size: height);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: Image.asset(asset, height: height, semanticLabel: method.label),
    );
  }
}

/// A payment method to pick: the provider's logo on a white tile (M-Pesa,
/// Paystack), or an icon and name for cash and card. Selected shows a green
/// border and tick.
class PaymentMethodButton extends StatelessWidget {
  const PaymentMethodButton({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
    this.caption,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  /// A word under the logo where two methods share one (M-Pesa "Classic").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final asset = paymentLogoAsset(method);
    final border = selected ? AppColors.primary : AppColors.outline;
    return Semantics(
      button: true,
      selected: selected,
      label: method.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          constraints: const BoxConstraints(minWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: asset != null ? Colors.white : (selected ? AppColors.primaryTint : AppColors.surfaceRaised),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (asset != null)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(asset, height: caption == null ? 26 : 20, excludeFromSemantics: true),
                    if (caption != null)
                      Text(caption!, style: const TextStyle(fontSize: 9.5, color: Colors.black54, fontWeight: FontWeight.w600)),
                  ],
                )
              else ...[
                Icon(method == PaymentMethod.cash ? Icons.payments_outlined : Icons.credit_card,
                    size: 18, color: selected ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(method.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.textPrimary)),
              ],
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, size: 16, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
