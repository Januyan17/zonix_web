import 'package:flutter/material.dart';
import 'package:zonixweb/core/widgets/icon_badge.dart';
import 'package:zonixweb/features/shops/models/shop_user.dart';

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
