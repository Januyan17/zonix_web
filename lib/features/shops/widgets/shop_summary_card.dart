import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/code_chip.dart';
import 'package:zonixweb/core/widgets/info_row.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/widgets/active_badge.dart';
import 'package:zonixweb/features/shops/widgets/settings/limit_row.dart';

/// The card at the top of the shop detail page: identity, limits, and the
/// shop-wide switches.
class ShopSummaryCard extends StatelessWidget {
  const ShopSummaryCard({
    super.key,
    required this.shop,
    required this.staffCount,
    required this.productCount,
    required this.onEditStaffLimit,
    required this.onEditProductLimit,
    required this.onEditMaxActiveDevices,
    required this.onToggleActive,
    required this.onToggleStaffDelete,
  });

  final Shop shop;
  final int staffCount;
  final int productCount;
  final VoidCallback onEditStaffLimit;
  final VoidCallback onEditProductLimit;
  final VoidCallback onEditMaxActiveDevices;

  /// Null while a toggle is being saved, which disables the switch.
  final ValueChanged<bool>? onToggleActive;
  final ValueChanged<bool>? onToggleStaffDelete;

  static const _gap = SizedBox(height: AppDimens.spacing10);
  static const _divider = Divider(height: 1);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppDimens.spacing6),
                      CodeChip(code: shop.slug),
                    ],
                  ),
                ),
                ActiveBadge(isActive: shop.isActive),
              ],
            ),
            const SizedBox(height: 18),
            _divider,
            const SizedBox(height: AppDimens.spacing14),
            InfoRow(
              icon: Icons.badge_outlined,
              label: 'Owner UID',
              value: shop.ownerUid,
            ),
            _gap,
            InfoRow(
              icon: Icons.event_outlined,
              label: 'Created',
              value: shop.createdAt,
            ),
            const SizedBox(height: AppDimens.spacing14),
            _divider,
            _gap,
            LimitRow(
              icon: Icons.groups_2_outlined,
              label: 'Staff limit',
              unit: 'staff',
              limit: shop.staffLimit,
              used: staffCount,
              onEdit: onEditStaffLimit,
            ),
            _gap,
            _divider,
            _gap,
            LimitRow(
              icon: Icons.inventory_2_outlined,
              label: 'Product limit',
              unit: 'products',
              limit: shop.productLimit,
              used: productCount,
              onEdit: onEditProductLimit,
            ),
            _gap,
            _divider,
            _gap,
            SettingValueRow(
              icon: Icons.devices_outlined,
              label: 'Max devices — Staff',
              value: '${shop.maxActiveDevicesStaff} per user',
              onEdit: onEditMaxActiveDevices,
            ),
            _gap,
            _divider,
            _gap,
            SettingValueRow(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Max devices — Owner/Admin',
              value: '${shop.maxActiveDevicesOwner} per user',
              onEdit: onEditMaxActiveDevices,
            ),
            _gap,
            _divider,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text(
                'Inactive shops are blocked from mobile login',
              ),
              value: shop.isActive,
              onChanged: onToggleActive,
            ),
            _divider,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow staff deletion'),
              subtitle: const Text(
                'Shows a Delete option for staff members '
                'in the mobile app',
              ),
              value: shop.staffDeleteEnabled,
              onChanged: onToggleStaffDelete,
            ),
          ],
        ),
      ),
    );
  }
}
