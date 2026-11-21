import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';

/// Icon + bold title that introduces a page or card section, with an
/// optional trailing action (a button, a switch) pinned to the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconLg, color: theme.colorScheme.primary),
        const SizedBox(width: AppDimens.spacing8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
