import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/shop_insights.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/zonix_colors.dart';
import '../../../utils/money_format.dart';

/// When the shop actually trades: sales by hour of the day, and by day of
/// the week.
///
/// The trend chart answers "how much, over time"; this answers "when",
/// which is the shape behind staffing and opening hours. Both series come
/// from the timestamps on the sales already fetched.
class SalesRhythmCard extends StatelessWidget {
  const SalesRhythmCard({
    super.key,
    required this.loading,
    required this.hours,
    required this.weekdays,
    required this.rangeLabel,
    this.showWeekdays = true,
  });

  final bool loading;
  final List<HourBucket> hours;
  final List<WeekdayBucket> weekdays;
  final String rangeLabel;

  /// Suppressed on a single-day range, where "sales by weekday" is one bar
  /// and six zeroes — a chart that says nothing but looks like it does.
  final bool showWeekdays;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalSales = hours.fold<int>(0, (sum, h) => sum + h.salesCount);

    HourBucket? peak;
    for (final hour in hours) {
      if (hour.salesCount > 0 &&
          (peak == null || hour.salesCount > peak.salesCount)) {
        peak = hour;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'When sales happen · $rangeLabel',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              peak == null
                  ? 'Sales by hour of day, in the shop\'s own clock.'
                  : 'Busiest hour: ${_hourLabel(peak.hour)}–'
                        '${_hourLabel((peak.hour + 1) % 24)} · '
                        '${peak.salesCount} sale'
                        '${peak.salesCount == 1 ? '' : 's'} · '
                        '${formatMoney(peak.revenue)}',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            SizedBox(
              height: 160,
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : totalSales == 0
                  ? Center(
                      child: Text(
                        'No sales in this period.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : _HourChart(hours: hours),
            ),
            if (showWeekdays && !loading && totalSales > 0) ...[
              const SizedBox(height: AppDimens.spacing20),
              Text(
                'By day of week',
                style: TextStyle(
                  fontSize: AppDimens.fontLabelLg,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.spacing10),
              _WeekdayRows(weekdays: weekdays),
            ],
          ],
        ),
      ),
    );
  }
}

String _hourLabel(int hour) {
  final period = hour < 12 ? 'am' : 'pm';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display$period';
}

class _HourChart extends StatelessWidget {
  const _HourChart({required this.hours});

  final List<HourBucket> hours;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    var maxY = 1.0;
    for (final hour in hours) {
      if (hour.salesCount > maxY) maxY = hour.salesCount.toDouble();
    }
    maxY *= 1.15;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY / 3,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                // A label every three hours: 24 of them collide at any
                // width this card is ever given.
                if (hour % 3 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spacing4),
                  child: Text(
                    _hourLabel(hour),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final bucket = hours[group.x];
              return BarTooltipItem(
                '${_hourLabel(bucket.hour)}–${_hourLabel((bucket.hour + 1) % 24)}\n'
                '${bucket.salesCount} sale${bucket.salesCount == 1 ? '' : 's'}\n'
                '${formatMoney(bucket.revenue)}',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (final bucket in hours)
            BarChartGroupData(
              x: bucket.hour,
              barRods: [
                BarChartRodData(
                  toY: bucket.salesCount.toDouble(),
                  color: ZonixColors.chartBlue,
                  width: 7,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeekdayRows extends StatelessWidget {
  const _WeekdayRows({required this.weekdays});

  final List<WeekdayBucket> weekdays;

  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    var peak = 0.0;
    for (final day in weekdays) {
      if (day.revenue > peak) peak = day.revenue;
    }

    return Column(
      children: [
        for (final day in weekdays) ...[
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  _names[day.weekday - 1],
                  style: TextStyle(
                    fontSize: AppDimens.fontCaption,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
                  child: LinearProgressIndicator(
                    value: peak <= 0 ? 0 : day.revenue / peak,
                    minHeight: 7,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(colorScheme.tertiary),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacing10),
              SizedBox(
                width: 110,
                child: Text(
                  formatMoney(day.revenue),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: AppDimens.fontCaption),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacing6),
        ],
      ],
    );
  }
}
