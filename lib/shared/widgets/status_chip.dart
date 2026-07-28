import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';

/// Tinted pill chip for loan/meeting/sync states — status is always shown
/// with a label, never color alone.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.tint,
    this.icon,
  });

  factory StatusChip.loan(LoanStatus status, {Key? key}) {
    return StatusChip(
      key: key,
      label: status.label,
      color: switch (status) {
        LoanStatus.active => AppColors.primary,
        LoanStatus.repaid => AppColors.repaid,
        LoanStatus.defaulted => AppColors.defaulted,
      },
      tint: switch (status) {
        LoanStatus.active => AppColors.primaryTint,
        LoanStatus.repaid => AppColors.repaidTint,
        LoanStatus.defaulted => AppColors.defaultedTint,
      },
    );
  }

  factory StatusChip.meeting(MeetingStatus status, {Key? key}) {
    return StatusChip(
      key: key,
      label: status.label,
      color: status == MeetingStatus.open
          ? AppColors.primary
          : AppColors.textSecondary,
      tint: status == MeetingStatus.open
          ? AppColors.primaryTint
          : AppColors.surfaceRaised,
      icon: status == MeetingStatus.closed ? Icons.lock_outline : null,
    );
  }

  factory StatusChip.pendingSync(int count, {Key? key}) {
    return StatusChip(
      key: key,
      label: '$count pending',
      color: AppColors.pending,
      tint: AppColors.pendingTint,
      icon: Icons.cloud_upload_outlined,
    );
  }

  factory StatusChip.synced({Key? key}) {
    return StatusChip(
      key: key,
      label: 'synced',
      color: AppColors.primary,
      tint: AppColors.primaryTint,
      icon: Icons.check,
    );
  }

  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: ShapeDecoration(shape: const StadiumBorder(), color: tint),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
