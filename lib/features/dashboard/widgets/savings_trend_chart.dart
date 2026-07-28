import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/dashboard_summary.dart';

/// Cumulative savings per meeting: single green series with an area fill,
/// a faint grid, an emphasized endpoint, and a touch tooltip.
class SavingsTrendChart extends StatelessWidget {
  const SavingsTrendChart({super.key, required this.points});

  final List<SavingsTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final point in points)
        FlSpot(point.meetingNumber.toDouble(), point.cumulativeSavings),
    ];
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final chartTop = maxY <= 0 ? 100.0 : maxY * 1.15;
    final lastSpot = spots.last;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: chartTop,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartTop / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.outline,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: _bottomInterval(),
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '#${value.toInt()}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceRaised,
              getTooltipItems: (touched) => [
                for (final spot in touched)
                  LineTooltipItem(
                    'Meeting #${spot.x.toInt()}\n'
                    '${Formatters.moneyCompact(spot.y)}',
                    TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: AppColors.primary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) => spot == lastSpot,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.primary,
                  strokeWidth: 4,
                  strokeColor: AppColors.primaryTint,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.28),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _bottomInterval() {
    final range = points.last.meetingNumber - points.first.meetingNumber;
    if (range <= 6) return 1;
    return (range / 5).ceilToDouble();
  }
}
