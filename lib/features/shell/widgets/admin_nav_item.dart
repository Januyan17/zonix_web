import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';

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
    // The rail is dark: selected items sit on a glowing cyan pill with navy
    // text, the rest are soft white.
    final fg =
        color ??
        (selected ? ZonixColors.navy : Colors.white.withValues(alpha: 0.72));
    final radius = BorderRadius.circular(AppDimens.radiusLarge + 2);

    final decoration = selected
        ? BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: [ZonixColors.cyan, Color(0xFF22C3A6)],
            ),
            boxShadow: [
              BoxShadow(
                color: ZonixColors.cyan.withValues(alpha: 0.40),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(borderRadius: radius);

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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: AppDimens.fontBodyLg,
                    letterSpacing: 0.1,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: decoration,
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              hoverColor: Colors.white.withValues(alpha: 0.07),
              splashColor: ZonixColors.cyan.withValues(alpha: 0.18),
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
      ),
    );
  }
}
