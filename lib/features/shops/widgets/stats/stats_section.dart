import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/core/utils/percent_format.dart';
import 'package:zonixweb/features/shops/models/shop_insights.dart';
import 'package:zonixweb/features/shops/models/shop_stats.dart';
import 'package:zonixweb/features/shops/widgets/stats/stat_tile.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({
    super.key,
    required this.loading,
    required this.stats,
    this.comparison,
    this.voids,
  });

  final bool loading;
  final ShopStats? stats;

  /// The same figures for the period immediately before, when there is one
  /// and its documents were fetched. Null on the all-time filter, where
  /// there is no previous period.
  final StatsComparison? comparison;

  /// Sales that were rung up and then deleted. Rendered only when there
  /// were any — a permanent "0 voids" tile is noise on the vast majority of
  /// shops that never void anything.
  final VoidStats? voids;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final s = stats;
    if (s == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Statistics unavailable.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final profitPositive = s.netProfit >= 0;
    final c = comparison;
    final margin = s.grossMargin;
    final aov = s.averageOrderValue;
    final basket = s.averageBasketSize;
    final voided = voids;
    final voidRate = voided?.rate;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        StatTile(
          icon: Icons.trending_up_rounded,
          label: 'Revenue',
          value: formatMoney(s.totalRevenue),
          color: colorScheme.tertiary,
          containerColor: colorScheme.tertiaryContainer,
          delta: c?.revenueChange,
        ),
        StatTile(
          icon: Icons.inventory_outlined,
          label: 'Cost of goods',
          value: formatMoney(s.totalCogs),
          color: colorScheme.error,
          containerColor: colorScheme.errorContainer,
        ),
        StatTile(
          icon: Icons.trending_down_rounded,
          label: 'Expenses',
          value: formatMoney(s.totalExpenses),
          color: colorScheme.error,
          containerColor: colorScheme.errorContainer,
          delta: c?.expensesChange,
          // Spending more is not an improvement, so the arrow that means
          // "good" points the other way here.
          higherIsBetter: false,
        ),
        StatTile(
          icon: Icons.add_circle_outline,
          label: 'Other income',
          value: formatMoney(s.totalAdditionalIncome),
          color: colorScheme.primary,
          containerColor: colorScheme.primaryContainer,
        ),
        StatTile(
          icon: profitPositive
              ? Icons.savings_outlined
              : Icons.warning_amber_rounded,
          label: 'Net profit',
          value: formatMoney(s.netProfit),
          color: profitPositive ? colorScheme.tertiary : colorScheme.error,
          containerColor: profitPositive
              ? colorScheme.tertiaryContainer
              : colorScheme.errorContainer,
          delta: c?.netProfitChange,
        ),
        StatTile(
          icon: Icons.receipt_long_outlined,
          label: 'Sales',
          value: '${s.salesCount}',
          color: colorScheme.onSurfaceVariant,
          containerColor: colorScheme.surfaceContainerHighest,
          delta: c?.salesCountChange,
        ),
        StatTile(
          icon: Icons.shopping_basket_outlined,
          label: 'Avg order value',
          // A dash, not "Rs 0.00": nothing sold is a different fact from
          // baskets averaging nothing.
          value: aov == null ? '—' : formatMoney(aov),
          color: ZonixColors.chartBlue,
          containerColor: ZonixColors.cyanContainer,
          delta: c?.averageOrderValueChange,
          sublabel: basket == null
              ? null
              : '${formatQuantity(basket)} items each',
        ),
        StatTile(
          icon: Icons.percent_rounded,
          label: 'Gross margin',
          value: margin == null ? '—' : formatPercent(margin, decimals: 1),
          color: (margin ?? 0) >= 0 ? colorScheme.tertiary : colorScheme.error,
          containerColor: (margin ?? 0) >= 0
              ? colorScheme.tertiaryContainer
              : colorScheme.errorContainer,
          sublabel: 'after cost of goods',
        ),
        StatTile(
          icon: Icons.numbers_rounded,
          label: 'Units sold',
          value: s.unitsSold == 0 ? '—' : formatQuantity(s.unitsSold),
          color: colorScheme.onSurfaceVariant,
          containerColor: colorScheme.surfaceContainerHighest,
        ),
        if (voided != null && voided.count > 0)
          StatTile(
            icon: Icons.remove_shopping_cart_outlined,
            label: 'Voided sales',
            value: '${voided.count}',
            color: colorScheme.error,
            containerColor: colorScheme.errorContainer,
            sublabel:
                '${voidRate == null ? '' : '${formatPercent(voidRate)} of '
                          'sales · '}${formatMoney(voided.value)}',
          ),
        StatTile(
          icon: Icons.inventory_2_outlined,
          label: 'Products',
          value: '${s.productCount}',
          color: colorScheme.onSurfaceVariant,
          containerColor: colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}
