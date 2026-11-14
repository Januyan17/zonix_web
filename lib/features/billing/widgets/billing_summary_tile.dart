import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';

class BillingSummaryTile extends StatelessWidget {
  const BillingSummaryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = highlight ? colorScheme.onErrorContainer : colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: Card(
        color: highlight ? colorScheme.errorContainer : null,
        child: Padding(
          padding: AppDimens.paddingAll14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: AppDimens.spacing12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: AppDimens.fontTitle,
                      fontWeight: FontWeight.w700,
                      color: highlight ? fg : null,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppDimens.fontLabel,
                      color: highlight ? fg : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
