import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';

/// "No trial" / "Trial active: N days left" / "Trial ended: app locked",
/// in the same Chip style as the shop's Active badge. Used on the shop
/// detail page and, [compact], on the shop list tiles.
class TrialStatusBadge extends StatelessWidget {
  const TrialStatusBadge({
    super.key,
    required this.trial,
    this.compact = false,
  });

  final ShopTrial trial;

  /// Shorter labels and tighter padding, for the fixed-height list tiles.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final (IconData icon, String label, Color fg, Color bg) = switch (trial
        .stateAt(now)) {
      ShopTrialState.off => (
        Icons.hourglass_disabled_outlined,
        'No trial',
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
      ),
      ShopTrialState.active => (
        Icons.hourglass_top_rounded,
        _activeLabel(trial.daysLeftAt(now)),
        colorScheme.onPrimaryContainer,
        colorScheme.primaryContainer.withValues(alpha: 0.6),
      ),
      ShopTrialState.ended => (
        Icons.lock_outline,
        compact ? 'Trial ended' : 'Trial ended: app locked',
        colorScheme.onErrorContainer,
        colorScheme.errorContainer,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: AppDimens.iconSm, color: fg),
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg),
      visualDensity: compact ? VisualDensity.compact : null,
      materialTapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
    );
  }

  String _activeLabel(int? daysLeft) {
    if (daysLeft == null) return compact ? 'Trial' : 'Trial active: starting…';
    final unit = daysLeft == 1 ? 'day' : 'days';
    return compact
        ? 'Trial: ${daysLeft}d left'
        : 'Trial active: $daysLeft $unit left';
  }
}
