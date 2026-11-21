import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';
import 'package:zonixweb/features/shops/widgets/trial_status_badge.dart';

class TrialShopTile extends StatelessWidget {
  const TrialShopTile({
    super.key,
    required this.shop,
    required this.onOpen,
    required this.onCollect,
  });

  final Shop shop;
  final VoidCallback onOpen;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trial = shop.trial;
    final end = trial.endsAt;
    final ended = trial.stateAt(DateTime.now()) == ShopTrialState.ended;
    final details = [
      if (end != null)
        '${ended ? 'Ended' : 'Ends'} ${formatShortDateTime(end)}',
      if (trial.startedAt != null)
        'Started ${formatShortDate(trial.startedAt!)}',
    ].join(' · ');

    final button = ended
        ? FilledButton.icon(
            onPressed: onCollect,
            icon: const Icon(Icons.payments_outlined, size: AppDimens.iconLg),
            label: const Text('Collect payment'),
          )
        : OutlinedButton.icon(
            onPressed: onCollect,
            icon: const Icon(Icons.payments_outlined, size: AppDimens.iconLg),
            label: const Text('Collect payment'),
          );

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: AppDimens.paddingH16V12,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimens.spacing4),
                  Wrap(
                    spacing: AppDimens.spacing8,
                    runSpacing: AppDimens.spacing4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TrialStatusBadge(trial: trial, compact: true),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          style: TextStyle(
                            fontSize: AppDimens.fontLabel,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spacing8),
            button,
          ],
        ),
      ),
    );
  }
}
