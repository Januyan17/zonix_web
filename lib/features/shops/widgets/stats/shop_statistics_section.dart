import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/widgets/filter_row.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/shops/models/product.dart';
import 'package:zonixweb/features/shops/models/shop_insights.dart';
import 'package:zonixweb/features/shops/models/shop_stats.dart';
import 'package:zonixweb/features/shops/utils/shop_date_filter.dart';
import 'package:zonixweb/features/shops/widgets/products/product_performance_card.dart';
import 'package:zonixweb/features/shops/widgets/stats/sales_rhythm_card.dart';
import 'package:zonixweb/features/shops/widgets/stats/stats_section.dart';
import 'package:zonixweb/features/shops/widgets/stats/trend_chart.dart';

/// Everything a shop's date filter drives: the filter chips, the stat
/// tiles, the trend chart, and the sales-rhythm and product cards.
class ShopStatisticsSection extends StatelessWidget {
  const ShopStatisticsSection({
    super.key,
    required this.selection,
    required this.onSelectFilter,
    required this.statsLoading,
    required this.seriesLoading,
    required this.stats,
    required this.comparison,
    required this.voids,
    required this.dailySeries,
    required this.hours,
    required this.weekdays,
    required this.performance,
    required this.deadStock,
  });

  final ShopDateFilterSelection selection;
  final ValueChanged<ShopDateFilter> onSelectFilter;
  final bool statsLoading;
  final bool seriesLoading;
  final ShopStats? stats;
  final StatsComparison? comparison;
  final VoidStats? voids;
  final List<DailyStat>? dailySeries;
  final List<HourBucket> hours;
  final List<WeekdayBucket> weekdays;
  final List<ProductPerformance> performance;
  final List<Product> deadStock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filter = selection.filter;
    final customRange = selection.customRange;
    final comparison = this.comparison;
    final filterLabel = selection.label();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(icon: Icons.insights_outlined, label: 'Statistics'),
        const SizedBox(height: AppDimens.spacing10),
        FilterRow<ShopDateFilter>(
          selected: filter,
          onSelect: onSelectFilter,
          options: [
            const FilterOption(value: ShopDateFilter.day, label: 'Daily'),
            const FilterOption(value: ShopDateFilter.week, label: 'Weekly'),
            const FilterOption(value: ShopDateFilter.month, label: 'Monthly'),
            const FilterOption(
              value: ShopDateFilter.allTime,
              label: 'All time',
            ),
            FilterOption(
              value: ShopDateFilter.custom,
              label: filter == ShopDateFilter.custom && customRange != null
                  ? '${formatShortDate(customRange.start)} - ${formatShortDate(customRange.end)}'
                  : 'Custom range',
              avatar: (_) =>
                  const Icon(Icons.date_range_outlined, size: AppDimens.iconSm),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing10),
        StatsSection(
          loading: statsLoading,
          stats: stats,
          comparison: comparison,
          voids: voids,
        ),
        if (comparison != null) ...[
          const SizedBox(height: AppDimens.spacing8),
          Text(
            'Arrows compare with the previous '
            '${comparison.previousRange.dayCount} day'
            '${comparison.previousRange.dayCount == 1 ? '' : 's'} '
            '(${formatShortDate(comparison.previousRange.start)}'
            ' - '
            '${formatShortDate(comparison.previousRange.end)}).',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: AppDimens.fontCaption,
            ),
          ),
        ],
        const SizedBox(height: AppDimens.spacing16),
        TrendChart(
          loading: seriesLoading,
          series: dailySeries,
          rangeLabel: selection.chartWindow().$3,
        ),
        const SizedBox(height: AppDimens.spacing16),
        SalesRhythmCard(
          loading: statsLoading,
          hours: hours,
          weekdays: weekdays,
          rangeLabel: filterLabel,
          showWeekdays: filter != ShopDateFilter.day,
        ),
        const SizedBox(height: AppDimens.spacing16),
        ProductPerformanceCard(
          loading: statsLoading,
          performance: performance,
          deadStock: deadStock,
          rangeLabel: filterLabel,
        ),
      ],
    );
  }
}
