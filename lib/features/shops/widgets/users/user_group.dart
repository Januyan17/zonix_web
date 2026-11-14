import 'package:flutter/material.dart';

import 'package:zonixweb/features/shops/models/shop_user.dart';
import 'package:zonixweb/features/shops/widgets/users/user_card.dart';

class UserGroup extends StatelessWidget {
  const UserGroup({
    super.key,
    required this.label,
    required this.users,
    required this.onReissueLogin,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDevices,
  });

  final String label;
  final List<ShopUser> users;
  final ValueChanged<ShopUser> onReissueLogin;
  final ValueChanged<ShopUser> onEdit;
  final ValueChanged<ShopUser> onDelete;
  final ValueChanged<ShopUser> onViewDevices;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeCount = users.where((u) => u.isEnabled && !u.isDeleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · $activeCount active of ${users.length}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (users.isEmpty)
          Text(
            'None yet.',
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final u in users) ...[
            UserCard(
              user: u,
              onReissueLogin: () => onReissueLogin(u),
              onEdit: () => onEdit(u),
              onDelete: () => onDelete(u),
              onViewDevices: () => onViewDevices(u),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
