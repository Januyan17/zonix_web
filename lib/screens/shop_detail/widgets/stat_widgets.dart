import 'package:flutter/material.dart';

import '../../../models/shop_insights.dart';
import '../../../models/shop_stats.dart';
import '../../../models/shop_user.dart';
import '../../../theme/zonix_colors.dart';
import '../../../utils/money_format.dart';
import '../../../utils/percent_format.dart';

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

/// Shared "icon centered in a colored box" pattern used by the stat tiles,
/// count chips, and transaction rows — square/rounded or circular.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.color,
    required this.background,
    this.borderRadius,
    this.circular = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color background;
  final BorderRadius? borderRadius;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : borderRadius,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.containerColor,
    this.delta,
    this.sublabel,
    this.higherIsBetter = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color containerColor;

  /// Change against the previous period, as a fraction (0.2 = up 20%).
  /// Null hides the chip entirely — both when there is no previous period
  /// and when the previous period was zero, where a percentage would be
  /// undefined.
  final double? delta;

  /// A second line under the label, for the qualifier a figure needs to be
  /// read correctly ("after cost of goods").
  final String? sublabel;

  /// Whether an increase is the good direction. False for costs, where the
  /// same green arrow would say the opposite of what it means.
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: icon,
                size: 32,
                iconSize: 17,
                color: color,
                background: containerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(9),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 6),
                    DeltaChip(change: delta!, higherIsBetter: higherIsBetter),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActiveUserCountsRow extends StatelessWidget {
  const ActiveUserCountsRow({super.key, required this.users});

  final List<ShopUser> users;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeOwners = users
        .where((u) => u.role == 'owner' && u.isEnabled && !u.isDeleted)
        .length;
    final activeStaff = users
        .where((u) => u.role != 'owner' && u.isEnabled && !u.isDeleted)
        .length;

    return Row(
      children: [
        Expanded(
          child: CountChip(
            icon: Icons.workspace_premium_outlined,
            label: 'Active owners',
            count: activeOwners,
            color: colorScheme.primary,
            containerColor: colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CountChip(
            icon: Icons.badge_outlined,
            label: 'Active staff',
            count: activeStaff,
            color: colorScheme.tertiary,
            containerColor: colorScheme.tertiaryContainer,
          ),
        ),
      ],
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.containerColor,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconBadge(
              icon: icon,
              size: 34,
              iconSize: 17,
              color: color,
              background: containerColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "vs. previous period" chip on a stat tile: an arrow and a signed
/// percentage, colored by whether the movement is the good one for that
/// figure rather than by its sign.
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.change,
    this.higherIsBetter = true,
  });

  final double change;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rising = change >= 0;
    final good = rising == higherIsBetter;
    // Flat is neither good nor bad; coloring a 0% move green would invent
    // a trend out of nothing.
    final neutral = change == 0;
    final color = neutral
        ? colorScheme.onSurfaceVariant
        : good
        ? colorScheme.tertiary
        : colorScheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          neutral
              ? Icons.remove_rounded
              : rising
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          size: 12,
          color: color,
        ),
        Text(
          formatSignedPercent(change),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
