import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';

/// A labelled proportion bar. The count is always printed beside it, so the
/// bar is a second encoding of the number rather than the only one.
class ProportionRow extends StatelessWidget {
  const ProportionRow({
    super.key,
    required this.label,
    required this.count,
    required this.total,
    this.color,
  });

  final String label;
  final int count;
  final int total;

  /// Bar fill. Defaults to the single-series chart color; the activity mix
  /// overrides it per row because there the rows are grades of the same
  /// scale (selling → dormant) rather than unrelated counts.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : count / total;

    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppDimens.fontBody,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                color ?? ZonixColors.chartBlue,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacing12),
        SizedBox(
          width: 56,
          child: Text(
            '$count / $total',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: AppDimens.fontLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
