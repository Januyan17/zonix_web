import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';

/// Per-shop liveness and cap utilization — the churn-risk and upsell view.
/// Sorted worst-first so the shops that need attention are at the top
/// rather than wherever alphabetical order happens to put them.
class ShopHealthCard extends StatelessWidget {
  const ShopHealthCard({
    super.key,
    required this.health,
    required this.onOpenShop,
  });

  final PlatformHealth health;
  final ValueChanged<String> onOpenShop;

  static int _severity(ShopActivity activity) => switch (activity) {
    ShopActivity.dormant => 0,
    ShopActivity.neverSold => 1,
    ShopActivity.quiet => 2,
    ShopActivity.live => 3,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final shops = [...health.shops]
      ..sort((a, b) {
        final bySeverity = _severity(
          a.activity(now: now),
        ).compareTo(_severity(b.activity(now: now)));
        if (bySeverity != 0) return bySeverity;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Shop health',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'A till that stops ringing is the earliest sign of churn. '
              'Sorted by how long it has been quiet.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing12),
            if (shops.isEmpty)
              Text(
                'No shops yet.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              for (final shop in shops) ...[
                const Divider(height: 1),
                _ShopHealthRow(
                  shop: shop,
                  now: now,
                  onTap: () => onOpenShop(shop.slug),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ShopHealthRow extends StatelessWidget {
  const _ShopHealthRow({
    required this.shop,
    required this.now,
    required this.onTap,
  });

  final ShopHealth shop;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activity = shop.activity(now: now);
    final days = shop.daysSinceLastSale(now: now);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing10),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppDimens.spacing12,
          runSpacing: AppDimens.spacing8,
          children: [
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppDimens.fontBodyLg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!shop.isActive)
                    Text(
                      'Shop deactivated',
                      style: TextStyle(
                        fontSize: AppDimens.fontCaption,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            _ActivityChip(activity: activity, days: days),
            _UtilizationText(
              icon: Icons.badge_outlined,
              used: shop.staffCount,
              limit: shop.staffLimit,
              unit: 'staff',
            ),
            _UtilizationText(
              icon: Icons.inventory_2_outlined,
              used: shop.productCount,
              limit: shop.productLimit,
              unit: 'products',
            ),
          ],
        ),
      ),
    );
  }
}

/// Status is never carried by color alone — every state ships with its own
/// icon and its own words, so it survives a colorblind reader, a greyscale
/// print, and a screenshot pasted into chat.
class _ActivityChip extends StatelessWidget {
  const _ActivityChip({required this.activity, required this.days});

  final ShopActivity activity;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (
      IconData icon,
      Color color,
      Color background,
      String label,
    ) = switch (activity) {
      ShopActivity.live => (
        Icons.check_circle_outline,
        colorScheme.onTertiaryContainer,
        colorScheme.tertiaryContainer.withValues(alpha: 0.6),
        days == 0 ? 'Sold today' : 'Sold ${days}d ago',
      ),
      ShopActivity.quiet => (
        Icons.schedule_rounded,
        ZonixColors.onCyanContainer,
        ZonixColors.cyanContainer,
        'Quiet ${days}d',
      ),
      ShopActivity.dormant => (
        Icons.warning_amber_rounded,
        colorScheme.onErrorContainer,
        colorScheme.errorContainer,
        'Dormant ${days}d',
      ),
      ShopActivity.neverSold => (
        Icons.remove_circle_outline,
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
        'Never sold',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing8,
        vertical: AppDimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.iconXs, color: color),
          const SizedBox(width: AppDimens.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: AppDimens.fontCaption,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilizationText extends StatelessWidget {
  const _UtilizationText({
    required this.icon,
    required this.used,
    required this.limit,
    required this.unit,
  });

  final IconData icon;
  final int used;
  final int? limit;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final atRisk = limit != null && limit! > 0 && used / limit! >= 0.8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimens.iconXs, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppDimens.spacing6),
        Text(
          limit == null ? '$used $unit' : '$used / $limit $unit',
          style: TextStyle(
            fontSize: AppDimens.fontLabel,
            fontWeight: atRisk ? FontWeight.w700 : FontWeight.w400,
            color: atRisk ? colorScheme.error : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
