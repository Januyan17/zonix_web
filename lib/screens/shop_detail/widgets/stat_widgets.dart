import 'package:flutter/material.dart';

import '../../../models/shop_stats.dart';
import '../../../models/shop_user.dart';
import '../../../utils/money_format.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key, required this.loading, required this.stats});

  final bool loading;
  final ShopStats? stats;

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
        ),
        StatTile(
          icon: Icons.receipt_long_outlined,
          label: 'Sales',
          value: '${s.salesCount}',
          color: colorScheme.onSurfaceVariant,
          containerColor: colorScheme.surfaceContainerHighest,
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color containerColor;

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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
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
