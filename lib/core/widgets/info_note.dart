import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';

/// Muted inline note for "nothing to show here yet" and similar hints.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacing12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppDimens.iconLg,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimens.spacing8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
