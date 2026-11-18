import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zonixweb/core/utils/avatar_color.dart';
import 'package:zonixweb/core/widgets/menu_row.dart';
import 'package:zonixweb/features/shops/models/shop_user.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    required this.onReissueLogin,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDevices,
    this.onRoleChanged,
    this.onEnabledChanged,
  });

  final ShopUser user;
  final VoidCallback onReissueLogin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDevices;

  /// Quick role switch from the card itself (no need to open Edit).
  final ValueChanged<String>? onRoleChanged;

  /// Quick sign-in enable/disable from the card itself.
  final ValueChanged<bool>? onEnabledChanged;

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
        _RolePill(role: user.role, isOwner: isOwner, onChanged: onRoleChanged),
        const SizedBox(width: 6),
        Tooltip(
          message: user.isEnabled
              ? 'Can sign in · tap to disable'
              : 'Sign-in disabled · tap to enable',
          child: Transform.scale(
            scale: 0.8,
            child: Switch(value: user.isEnabled, onChanged: onEnabledChanged),
          ),
        ),
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
              case 'devices':
                onViewDevices();
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
              PopupMenuItem(
                value: 'devices',
                height: 40,
                child: MenuRow(
                  icon: Icons.devices_outlined,
                  label: 'Active devices',
                  color: menuColors.onSurface,
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

/// Role badge that doubles as a one-tap Staff/Owner switcher.
class _RolePill extends StatelessWidget {
  const _RolePill({
    required this.role,
    required this.isOwner,
    required this.onChanged,
  });

  final String role;
  final bool isOwner;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isOwner
        ? colorScheme.primaryContainer.withValues(alpha: 0.6)
        : colorScheme.surfaceContainerHighest;
    final fg = isOwner
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOwner ? Icons.workspace_premium_outlined : Icons.badge_outlined,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
          if (onChanged != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: fg),
          ],
        ],
      ),
    );

    if (onChanged == null) return pill;

    return PopupMenuButton<String>(
      tooltip: 'Change role',
      initialValue: role,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value != role) onChanged!(value);
      },
      itemBuilder: (menuContext) {
        final menuColors = Theme.of(menuContext).colorScheme;
        return [
          for (final (value, label, icon) in const [
            ('staff', 'Staff', Icons.badge_outlined),
            ('owner', 'Owner', Icons.workspace_premium_outlined),
          ])
            PopupMenuItem(
              value: value,
              height: 40,
              child: MenuRow(
                icon: value == role ? Icons.check_rounded : icon,
                label: label,
                color: value == role
                    ? menuColors.primary
                    : menuColors.onSurface,
              ),
            ),
        ];
      },
      child: pill,
    );
  }
}
