import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/core/utils/percent_format.dart';
import 'package:zonixweb/core/widgets/info_note.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';
import 'package:zonixweb/features/shops/widgets/stats/stat_tile.dart';
import 'package:zonixweb/features/shops/widgets/stats/trend_chart.dart';

/// The expensive tier, behind an explicit action.
class VolumeCard extends StatelessWidget {
  const VolumeCard({
    super.key,
    required this.volume,
    required this.computing,
    required this.done,
    required this.total,
    required this.error,
    required this.days,
    required this.onCompute,
    required this.onOpenShop,
  });

  final PlatformVolume? volume;
  final bool computing;
  final int done;
  final int total;
  final String? error;
  final int days;
  final VoidCallback? onCompute;
  final ValueChanged<String> onOpenShop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue across all shops · last $days days',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCompute,
                  icon: computing
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow_rounded,
                          size: AppDimens.iconLg,
                        ),
                  label: Text(volume == null ? 'Compute' : 'Recompute'),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'Not loaded automatically: this reads every sale, expense, and '
              'income record of every shop, and that cost grows with your '
              'history rather than your shop count. Run it when you need it. '
              'To have it always fresh instead, it needs nightly rollup '
              'documents written by a scheduled function.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (computing) ...[
              const SizedBox(height: AppDimens.spacing14),
              LinearProgressIndicator(
                value: total == 0 ? null : done / total,
                minHeight: 6,
              ),
              const SizedBox(height: AppDimens.spacing6),
              Text(
                'Scanned $done of $total shops…',
                style: TextStyle(
                  fontSize: AppDimens.fontCaption,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: AppDimens.spacing14),
              InfoNote(icon: Icons.error_outline, text: error!),
            ],
            if (volume != null) ...[
              const SizedBox(height: AppDimens.spacing16),
              _VolumeResults(volume: volume!, onOpenShop: onOpenShop),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeResults extends StatelessWidget {
  const _VolumeResults({required this.volume, required this.onOpenShop});

  final PlatformVolume volume;
  final ValueChanged<String> onOpenShop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ranked = volume.shops.where((s) => s.stats.totalRevenue > 0).toList();
    final peak = ranked.isEmpty ? 0.0 : ranked.first.stats.totalRevenue;
    final aov = volume.averageOrderValue;
    final margin = volume.grossMargin;
    final arps = volume.averageRevenuePerSellingShop;
    final median = volume.medianRevenuePerSellingShop;
    final concentration = volume.topShopsShare(5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimens.spacing10,
          runSpacing: AppDimens.spacing10,
          children: [
            StatTile(
              icon: Icons.payments_outlined,
              label: 'Total revenue',
              value: formatMoney(volume.totalRevenue),
              color: colorScheme.tertiary,
              containerColor: colorScheme.tertiaryContainer,
            ),
            StatTile(
              icon: Icons.savings_outlined,
              label: 'Net profit',
              value: formatMoney(volume.totalNetProfit),
              color: volume.totalNetProfit >= 0
                  ? colorScheme.tertiary
                  : colorScheme.error,
              containerColor: volume.totalNetProfit >= 0
                  ? colorScheme.tertiaryContainer
                  : colorScheme.errorContainer,
            ),
            StatTile(
              icon: Icons.receipt_long_outlined,
              label: 'Sales',
              value: '${volume.totalSalesCount}',
              color: ZonixColors.chartBlue,
              containerColor: ZonixColors.cyanContainer,
            ),
            StatTile(
              icon: Icons.storefront_outlined,
              label: 'Shops selling',
              value: '${volume.sellingShopCount} / ${volume.shops.length}',
              color: colorScheme.primary,
              containerColor: colorScheme.primaryContainer,
            ),
            StatTile(
              icon: Icons.shopping_basket_outlined,
              label: 'Avg order value',
              value: aov == null ? '—' : formatMoney(aov),
              color: ZonixColors.chartBlue,
              containerColor: ZonixColors.cyanContainer,
            ),
            StatTile(
              icon: Icons.percent_rounded,
              label: 'Gross margin',
              value: margin == null ? '—' : formatPercent(margin, decimals: 1),
              color: (margin ?? 0) >= 0
                  ? colorScheme.tertiary
                  : colorScheme.error,
              containerColor: (margin ?? 0) >= 0
                  ? colorScheme.tertiaryContainer
                  : colorScheme.errorContainer,
              sublabel: 'after cost of goods',
            ),
            StatTile(
              icon: Icons.store_mall_directory_outlined,
              label: 'Revenue per shop',
              value: arps == null ? '—' : formatMoney(arps),
              color: colorScheme.onSurfaceVariant,
              containerColor: colorScheme.surfaceContainerHighest,
              // The mean alone hides the shape. A median far below it means
              // the platform's revenue is one or two shops, not a hundred.
              sublabel: median == null
                  ? 'across selling shops'
                  : 'median ${formatMoney(median)}',
            ),
            StatTile(
              icon: Icons.pie_chart_outline_rounded,
              label: 'Top 5 shops',
              value: concentration == null ? '—' : formatPercent(concentration),
              color: (concentration ?? 0) >= 0.8
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              containerColor: (concentration ?? 0) >= 0.8
                  ? colorScheme.errorContainer
                  : colorScheme.surfaceContainerHighest,
              sublabel: 'of all revenue',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing16),
        TrendChart(
          loading: false,
          series: volume.series,
          rangeLabel: 'last ${volume.series.length} days',
        ),
        const SizedBox(height: AppDimens.spacing16),
        Text(
          'Revenue by shop',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimens.spacing10),
        if (ranked.isEmpty)
          Text(
            'No shop recorded a sale in this period.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          )
        else
          for (final shop in ranked) ...[
            _RevenueBar(
              name: shop.name,
              revenue: shop.stats.totalRevenue,
              peak: peak,
              onTap: () => onOpenShop(shop.slug),
            ),
            const SizedBox(height: AppDimens.spacing8),
          ],
      ],
    );
  }
}

/// One shop's revenue as a ranked bar. Every bar is the same color on
/// purpose — the measure is identical across rows, so a per-shop hue would
/// encode nothing and imply a category that does not exist.
class _RevenueBar extends StatelessWidget {
  const _RevenueBar({
    required this.name,
    required this.revenue,
    required this.peak,
    required this.onTap,
  });

  final String name;
  final double revenue;
  final double peak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing4),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppDimens.fontBody),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
                child: LinearProgressIndicator(
                  value: peak == 0 ? 0 : revenue / peak,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(
                    ZonixColors.chartBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spacing12),
            SizedBox(
              width: 110,
              child: Text(
                formatMoney(revenue),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: AppDimens.fontLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
