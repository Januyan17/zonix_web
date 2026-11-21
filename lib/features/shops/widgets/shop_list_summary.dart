import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/features/shops/models/shop_list_entry.dart';

class ShopListSummary extends StatelessWidget {
  const ShopListSummary({
    super.key,
    required this.entries,
    required this.loading,
  });

  final List<ShopListEntry> entries;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = entries.length;
    final active = entries.where((e) => e.shop?.isActive == true).length;
    final inactive = entries
        .where((e) => e.shop != null && e.shop!.isActive == false)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        final tiles = [
          _SummaryTile(
            icon: Icons.storefront_outlined,
            label: 'Total shops',
            value: loading ? '—' : '$total',
            color: colorScheme.primary,
            containerColor: colorScheme.primaryContainer,
          ),
          _SummaryTile(
            icon: Icons.check_circle_outline,
            label: 'Active',
            value: loading ? '—' : '$active',
            color: colorScheme.tertiary,
            containerColor: colorScheme.tertiaryContainer,
          ),
          _SummaryTile(
            icon: Icons.pause_circle_outline,
            label: 'Inactive',
            value: loading ? '—' : '$inactive',
            color: colorScheme.onSurfaceVariant,
            containerColor: colorScheme.surfaceContainerHighest,
          ),
        ];

        if (narrow) {
          return Column(
            children: [
              for (final t in tiles) ...[
                t,
                const SizedBox(height: AppDimens.spacing10),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i != tiles.length - 1)
                const SizedBox(width: AppDimens.spacing10),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: containerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: AppDimens.iconXl, color: color),
            ),
            const SizedBox(width: AppDimens.spacing14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppDimens.fontLabelLg,
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
