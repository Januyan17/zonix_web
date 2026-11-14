import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';

/// Full-area placeholder for a page or list with nothing in it yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppDimens.radiusSheetTop),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: colorScheme.onPrimaryContainer,
                size: 30,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimens.spacing6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: AppDimens.spacing20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
