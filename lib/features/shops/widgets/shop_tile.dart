import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/avatar_color.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_list_entry.dart';
import 'package:zonixweb/features/shops/widgets/trial_status_badge.dart';

class ShopTile extends StatelessWidget {
  const ShopTile({super.key, required this.entry, required this.onOpen});

  final ShopListEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = entry.indexedName;
    final avatarColor = avatarColorForName(name);
    final shop = entry.shop;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacing16,
            vertical: AppDimens.spacing14,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarColor.withValues(alpha: 0.15),
                foregroundColor: avatarColor,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppDimens.spacing14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop?.name ?? name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spacing2),
                    Text(
                      entry.slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: AppDimens.fontBody,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.spacing8),
              // Compact trial chip only for shops on a trial: "No trial" on
              // every tile would just be noise in the grid.
              if (shop != null && shop.trial.trialEnabled) ...[
                TrialStatusBadge(trial: shop.trial, compact: true),
                const SizedBox(width: AppDimens.spacing4),
              ],
              _StatusChip(shop: shop),
              const SizedBox(width: AppDimens.spacing4),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.shop});

  final Shop? shop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (shop == null) {
      return Chip(
        label: const Text('missing'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }
    final active = shop!.isActive;
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle : Icons.pause_circle_outline,
        size: AppDimens.iconSm,
        color: active ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
      ),
      label: Text(active ? 'Active' : 'Inactive'),
      backgroundColor: active
          ? colorScheme.tertiaryContainer.withValues(alpha: 0.6)
          : colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: active
            ? colorScheme.onTertiaryContainer
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}
