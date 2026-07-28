import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Uppercase, letter-spaced section label (`OVERVIEW`, `SAVINGS TREND`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// Circular two-letter initials avatar for members.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.name, {super.key, this.radius = 17});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceRaised,
      child: Text(
        Formatters.initials(name),
        style: TextStyle(
          fontSize: radius * 0.68,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Friendly placeholder for lists that have no rows yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Key-value row used inside summary cards (eligibility, meeting totals).
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(
    this.label,
    this.value, {
    super.key,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The label yields space and ellipsizes; the amount never does.
          // On a 320px handset a long label beside a large figure used to
          // overflow the row, and truncating money is not an option — a
          // member reading "KSh 1,800,00" would be told the wrong number.
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color:
                    emphasize ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: emphasize ? AppColors.primary : AppColors.textPrimary,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // The error toast keeps a fixed dark scrim in both themes, so its
        // text is pinned to white rather than following AppColors.textPrimary
        // (which would go near-black on this dark background in light mode).
        content: Text(
          message,
          style: error ? const TextStyle(color: Colors.white) : null,
        ),
        backgroundColor:
            error ? const Color(0xFF3A2422) : AppColors.surfaceRaised,
      ),
    );
}
