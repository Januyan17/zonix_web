import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';
import 'package:zonixweb/features/shops/widgets/stats/stat_tile.dart';

class OverviewSummaryTiles extends StatelessWidget {
  const OverviewSummaryTiles({super.key, required this.health});

  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stale = health.stale().length;
    final nearLimit = health.nearLimit.length;
    final newThisMonth = health.growth.isEmpty
        ? 0
        : health.growth.last.newShops;

    return Wrap(
      spacing: AppDimens.spacing10,
      runSpacing: AppDimens.spacing10,
      children: [
        StatTile(
          icon: Icons.storefront_outlined,
          label: 'Total shops',
          value: '${health.totalShops}',
          color: colorScheme.primary,
          containerColor: colorScheme.primaryContainer,
        ),
        StatTile(
          icon: Icons.check_circle_outline,
          label: 'Active',
          value: '${health.activeShops}',
          color: colorScheme.tertiary,
          containerColor: colorScheme.tertiaryContainer,
        ),
        StatTile(
          icon: Icons.trending_down_rounded,
          label: 'Needs attention',
          value: '$stale',
          color: stale > 0 ? colorScheme.error : colorScheme.onSurfaceVariant,
          containerColor: stale > 0
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainerHighest,
        ),
        StatTile(
          icon: Icons.person_add_alt_1_outlined,
          label: 'New this month',
          value: '$newThisMonth',
          color: colorScheme.primary,
          containerColor: colorScheme.primaryContainer,
          delta: health.signupGrowthRate,
        ),
        StatTile(
          icon: Icons.speed_rounded,
          label: 'Near a limit',
          value: '$nearLimit',
          color: nearLimit > 0
              ? ZonixColors.chartBlue
              : colorScheme.onSurfaceVariant,
          containerColor: nearLimit > 0
              ? ZonixColors.cyanContainer
              : colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}
