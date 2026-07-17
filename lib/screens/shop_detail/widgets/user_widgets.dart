import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/shop_user.dart';
import '../../../utils/avatar_color.dart';
import 'info_rows.dart';

class UserGroup extends StatelessWidget {
  const UserGroup({
    super.key,
    required this.label,
    required this.users,
    required this.onReissueLogin,
    required this.onEdit,
    required this.onDelete,
  });

  final String label;
  final List<ShopUser> users;
  final ValueChanged<ShopUser> onReissueLogin;
  final ValueChanged<ShopUser> onEdit;
  final ValueChanged<ShopUser> onDelete;

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
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    required this.onReissueLogin,
    required this.onEdit,
    required this.onDelete,
  });

  final ShopUser user;
  final VoidCallback onReissueLogin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarColor = avatarColorForName(user.displayName);
    final isOwner = user.role == 'owner';

    final identityRow = Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: avatarColor.withValues(alpha: 0.15),
          foregroundColor: avatarColor,
          child: Text(
            user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: SelectableText(
                      '${user.username} · ${user.email}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    tooltip: 'Copy login email',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: user.email));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Login email copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final actionsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(user.role),
          backgroundColor: isOwner
              ? colorScheme.primaryContainer.withValues(alpha: 0.6)
              : colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: isOwner
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        if (!user.isEnabled) ...[
          const SizedBox(width: 6),
          Icon(Icons.block, size: 16, color: colorScheme.error),
        ],
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          tooltip: 'User actions',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'reissue':
                onReissueLogin();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (menuContext) {
            final menuColors = Theme.of(menuContext).colorScheme;
            return [
              PopupMenuItem(
                value: 'edit',
                height: 40,
                child: MenuRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: menuColors.onSurface,
                ),
              ),
              PopupMenuItem(
                value: 'reissue',
                height: 40,
                child: MenuRow(
                  icon: Icons.lock_reset_rounded,
                  label: 'Reissue login',
                  color: menuColors.primary,
                ),
              ),
              const PopupMenuDivider(height: 8),
              PopupMenuItem(
                value: 'delete',
                height: 40,
                child: MenuRow(
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  color: menuColors.error,
                ),
              ),
            ];
          },
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identityRow,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actionsRow),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identityRow),
                actionsRow,
              ],
            );
          },
        ),
      ),
    );
  }
}
