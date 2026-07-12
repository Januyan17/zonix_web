import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/shop_stats.dart';

/// Daily revenue vs. expenses line chart for the shop detail page's
/// statistics section. Revenue and expenses share one axis (same currency
/// unit), each with a fixed color used consistently everywhere else in the
/// app (tertiary/emerald = revenue, error/red = expenses).
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.loading,
    required this.series,
    required this.rangeLabel,
  });

  final bool loading;
  final List<DailyStat>? series;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final revenueColor = colorScheme.tertiary;
    final expensesColor = colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue vs expenses · $rangeLabel',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _LegendDot(color: revenueColor, label: 'Revenue'),
                const SizedBox(width: 14),
                _LegendDot(color: expensesColor, label: 'Expenses'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : (series == null || series!.isEmpty)
                      ? Center(
                          child: Text(
                            'No data for this period.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        )
                      : _Chart(
                          series: series!,
                          revenueColor: revenueColor,
                          expensesColor: expensesColor,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    required this.series,
    required this.revenueColor,
    required this.expensesColor,
  });

  final List<DailyStat> series;
  final Color revenueColor;
  final Color expensesColor;

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridColor = colorScheme.outlineVariant.withValues(alpha: 0.4);

    var maxY = 1.0;
    for (final point in series) {
      if (point.revenue > maxY) maxY = point.revenue;
      if (point.expenses > maxY) maxY = point.expenses;
    }
    maxY *= 1.15;

    final labelEvery = (series.length / 6).ceil().clamp(1, series.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY / 4 == 0 ? 1 : maxY / 4,
              getTitlesWidget: (value, meta) => Text(
                _compact(value),
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= series.length) return const SizedBox.shrink();
                if (index % labelEvery != 0) return const SizedBox.shrink();
                final day = series[index].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${day.day}/${day.month}',
                    style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final isRevenue = spot.barIndex == 0;
                final day = series[spot.x.toInt()].day;
                return LineTooltipItem(
                  '${isRevenue ? 'Revenue' : 'Expenses'}\n'
                  'Rs ${spot.y.toStringAsFixed(2)}\n'
                  '${day.day}/${day.month}/${day.year}',
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          _series(series.map((p) => p.revenue).toList(), revenueColor),
          _series(series.map((p) => p.expenses).toList(), expensesColor),
        ],
      ),
    );
  }

  LineChartBarData _series(List<double> values, Color color) {
    return LineChartBarData(
      spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
      isCurved: false,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
    );
  }
}
