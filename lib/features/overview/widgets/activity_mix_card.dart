import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';
import 'package:zonixweb/features/overview/widgets/proportion_row.dart';

/// The four-way liveness census of every shop.
///
/// The "needs attention" tile counts shops with a problem; this says which
/// problem. A platform whose stalled shops are mostly [ShopActivity.neverSold]
/// has an onboarding failure — those shops were sold and never switched on.
/// One whose stalled shops mostly went [ShopActivity.dormant] after trading
/// has a retention failure. Same total, different fix.
class ActivityMixCard extends StatelessWidget {
  const ActivityMixCard({super.key, required this.health});

  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mix = health.activityMix();
    final total = mix.total;

    final rows = [
      (
        'Selling (under ${ShopActivityThresholds.quietDays}d)',
        mix.live,
        colorScheme.tertiary,
      ),
      (
        'Quiet (${ShopActivityThresholds.quietDays}d+)',
        mix.quiet,
        ZonixColors.chartBlue,
      ),
      (
        'Dormant (${ShopActivityThresholds.dormantDays}d+)',
        mix.dormant,
        colorScheme.error,
      ),
      ('Never sold', mix.neverSold, colorScheme.onSurfaceVariant),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Shop activity mix',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'How recently each of your $total shop'
              '${total == 1 ? '' : 's'} last rang up a sale. Shops that '
              'never sold were never onboarded; shops that went dormant '
              'stopped — the two need different follow-ups.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing14),
            for (final (label, count, color) in rows) ...[
              ProportionRow(
                label: label,
                count: count,
                total: total,
                color: color,
              ),
              const SizedBox(height: AppDimens.spacing10),
            ],
          ],
        ),
      ),
    );
  }
}
