import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';

class AdminNavItem extends StatelessWidget {
  const AdminNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    this.color,
    this.onTap,
    this.badgeLabel,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final Color? color;
  final VoidCallback? onTap;

  /// Shown as a bubble on the icon when non-null.
  final String? badgeLabel;

  Widget _badged(Widget icon) {
    final label = badgeLabel;
    if (label == null) return icon;
    return Badge(label: Text(label), child: icon);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg =
        color ??
        (selected ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final bg = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.6)
        : Colors.transparent;
    final radius = BorderRadius.circular(AppDimens.radiusLarge);

    final content = extended
        ? Row(
            children: [
              _badged(Icon(icon, size: AppDimens.iconXl, color: fg)),
              const SizedBox(width: AppDimens.spacing12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: AppDimens.fontBodyLg,
                  ),
                ),
              ),
            ],
          )
        : Center(
            child: _badged(Icon(icon, size: AppDimens.iconXxl, color: fg)),
          );

    // The ink sits inside the margin, so hover and press highlight the
    // rounded item itself rather than the full width of the rail.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: extended ? AppDimens.spacing12 : AppDimens.spacing16,
        vertical: 3,
      ),
      child: Tooltip(
        message: extended ? '' : label,
        child: Material(
          color: bg,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: fg.withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: extended ? AppDimens.spacing14 : 0,
                vertical: AppDimens.spacing12,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
