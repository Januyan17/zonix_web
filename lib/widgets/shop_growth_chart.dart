import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/platform_stats.dart';
import '../theme/app_dimens.dart';
import '../theme/zonix_colors.dart';

/// New shops per month, as bars over an even monthly axis.
///
/// Deliberately one measure on one axis. Plotting the running total on the
/// same chart would need a second y-scale — the cumulative line and the
/// monthly count differ by an order of magnitude — and a dual-axis chart
/// invites exactly the misreading it appears to prevent. The running total
/// is a stat tile instead, where a single number belongs.
///
/// One series means no legend: the title names the measure. Values are on
/// hover, with only the busiest month labelled directly, since a number
/// over every bar is noise rather than information.
class ShopGrowthChart extends StatelessWidget {
  const ShopGrowthChart({
    super.key,
    required this.loading,
    required this.points,
  });

  final bool loading;
  final List<ShopGrowthPoint> points;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _monthLabel(DateTime month) => _monthNames[month.month - 1];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAny = points.any((p) => p.newShops > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spacing16,
          AppDimens.spacing16,
          AppDimens.spacing20,
          AppDimens.spacing12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New shops per month · last ${points.length} months',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing16),
            SizedBox(
              height: 200,
              child: loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : !hasAny
                  ? Center(
                      child: Text(
                        'No shops created in this period.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : _Bars(points: points),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.points});

  final List<ShopGrowthPoint> points;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridColor = colorScheme.outlineVariant.withValues(alpha: 0.4);

    var peak = 0;
    for (final point in points) {
      if (point.newShops > peak) peak = point.newShops;
    }
    final maxY = (peak * 1.25).clamp(1, double.infinity).toDouble();
    // Only the busiest month carries a printed value; the rest are on hover.
    final peakIndex = points.indexWhere((p) => p.newShops == peak);

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            tooltipBorderRadius: BorderRadius.circular(
              AppDimens.radiusSmall,
            ),
            getTooltipItem: (group, _, rod, _) {
              final point = points[group.x];
              final count = rod.toY.toInt();
              return BarTooltipItem(
                '${ShopGrowthChart._monthLabel(point.month)} '
                '${point.month.year}\n',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: AppDimens.fontLabel,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: '$count new shop${count == 1 ? '' : 's'} · '
                        '${point.cumulative} total',
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: AppDimens.fontLabel,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) return const SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: AppDimens.fontCaption,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox();
                }
                // Thin the axis on narrow ranges so labels never collide.
                final step = points.length > 8 ? 2 : 1;
                if (index % step != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spacing6),
                  child: Text(
                    ShopGrowthChart._monthLabel(points[index].month),
                    style: TextStyle(
                      fontSize: AppDimens.fontCaption,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: const [],
              barRods: [
                BarChartRodData(
                  toY: points[i].newShops.toDouble(),
                  color: ZonixColors.chartBlue,
                  width: 14,
                  // Rounded data-end, square against the baseline.
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimens.spacing4),
                  ),
                ),
              ],
            ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (peakIndex >= 0 && peak > 0)
              HorizontalLine(
                y: peak.toDouble(),
                color: ZonixColors.chartBlue.withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: const [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(
                    fontSize: AppDimens.fontCaption,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  labelResolver: (_) => 'peak $peak',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
