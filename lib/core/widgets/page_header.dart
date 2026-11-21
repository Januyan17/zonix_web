import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';

/// Hero banner at the top of an admin page: a dark navy gradient band with
/// a glowing icon tile, a bold title, an optional muted description under
/// it, and an optional action on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.tag,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Shown in a glowing tile left of the title.
  final IconData? icon;

  /// Small uppercase label above the title, e.g. "ANALYTICS".
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final icon = this.icon;
    final tag = this.tag;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final trailing = this.trailing == null
            ? null
            : _OnDark(child: this.trailing!);

        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tag != null) ...[
              Text(
                tag.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: ZonixColors.cyan.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: AppDimens.spacing4),
            ],
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: narrow ? 22 : 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                height: 1.15,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppDimens.spacing8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: AppDimens.fontBody,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        );

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              GlowIconTile(icon: icon, size: narrow ? 46 : 54),
              SizedBox(width: narrow ? AppDimens.spacing14 : 18),
            ],
            Expanded(child: text),
            if (trailing != null && !narrow) ...[
              const SizedBox(width: AppDimens.spacing16),
              trailing,
            ],
          ],
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: ZonixColors.navy.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: ZonixColors.cyan.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                const Positioned.fill(child: ZonixHeaderBackground()),
                Padding(
                  padding: EdgeInsets.all(narrow ? 20 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      row,
                      if (trailing != null && narrow) ...[
                        const SizedBox(height: AppDimens.spacing16),
                        Align(alignment: Alignment.centerLeft, child: trailing),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Re-themes buttons placed on the dark banner so they read as glass
/// controls instead of navy-on-navy.
class _OnDark extends StatelessWidget {
  const _OnDark({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
    );
    return Theme(
      data: theme.copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            side: BorderSide(color: ZonixColors.cyan.withValues(alpha: 0.55)),
            minimumSize: const Size(64, 44),
            shape: shape,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: ZonixColors.cyan,
            shape: shape,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ZonixColors.cyan,
            foregroundColor: ZonixColors.navy,
            minimumSize: const Size(64, 44),
            shape: shape,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: Colors.white),
        ),
      ),
      child: child,
    );
  }
}
