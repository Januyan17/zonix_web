import 'package:flutter/material.dart';

class ActiveBadge extends StatelessWidget {
  const ActiveBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        isActive ? Icons.check_circle : Icons.pause_circle_outline,
        size: 16,
        color: isActive ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
      ),
      label: Text(isActive ? 'Active' : 'Inactive'),
      backgroundColor: isActive
          ? colorScheme.tertiaryContainer.withValues(alpha: 0.6)
          : colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isActive
            ? colorScheme.onTertiaryContainer
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}
