import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';
import 'package:zonixweb/features/overview/widgets/proportion_row.dart';

class FeatureAdoptionCard extends StatelessWidget {
  const FeatureAdoptionCard({super.key, required this.features});

  final FeatureAdoption features;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = features.totalShops;

    final rows = [
      ('Shop links editable', features.shopLinksEnabled),
      ('Staff delete allowed', features.staffDeleteEnabled),
      ('Staff limit set', features.staffLimitSet),
      ('Product limit set', features.productLimitSet),
      ('Staff multi-device', features.multiDeviceStaff),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Feature adoption',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'How many of your $total shop${total == 1 ? '' : 's'} have each '
              'optional setting turned on.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing14),
            for (final (label, count) in rows) ...[
              ProportionRow(label: label, count: count, total: total),
              const SizedBox(height: AppDimens.spacing10),
            ],
          ],
        ),
      ),
    );
  }
}
