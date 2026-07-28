import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/remote/credit_rating.dart';

/// Colour for a credit band, best → worst.
({Color color, Color tint}) creditBandColor(String band) => switch (band) {
      'A' => (color: AppColors.primary, tint: AppColors.primaryTint),
      'B' => (color: AppColors.repaid, tint: AppColors.repaidTint),
      'C' => (color: AppColors.pending, tint: AppColors.pendingTint),
      'D' => (color: AppColors.defaulted, tint: AppColors.defaultedTint),
      _ => (color: AppColors.textSecondary, tint: AppColors.surfaceRaised),
    };

/// A compact "Band B · 73" pill for a group's credit rating.
class CreditBandChip extends StatelessWidget {
  CreditBandChip({super.key, required RemoteCreditRating rating})
      : band = rating.band,
        score = rating.score,
        rated = rating.rated;

  /// For callers that hold the band and score without a full rating object —
  /// the agent caseload report returns them inline.
  const CreditBandChip.values({
    super.key,
    required this.band,
    required this.score,
    required this.rated,
  });

  final String band;
  final int score;
  final bool rated;

  @override
  Widget build(BuildContext context) {
    final c = creditBandColor(band);
    final label = rated ? 'Band $band · $score' : 'Unrated';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: c.color,
        ),
      ),
    );
  }
}
