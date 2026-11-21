import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';

/// Small rounded label used for inline statuses and tags.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
  });

  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing8,
        vertical: AppDimens.spacing2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppDimens.iconXs, color: fg),
            const SizedBox(width: AppDimens.spacing4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: AppDimens.fontLabel,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
