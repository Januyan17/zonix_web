import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';

/// "Overdue by 3 days" / "Due today" / "Due in 2 days" / "Next: 10/12/2026"
/// / "Not set up", as a Chip.
class BillingDueBadge extends StatelessWidget {
  const BillingDueBadge({
    super.key,
    required this.billing,
    this.compact = false,
  });

  final ShopBilling billing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final days = billing.daysUntilDue(now);

    final (IconData icon, String label, Color fg, Color bg) = switch (billing
        .dueStateAt(now)) {
      BillingDueState.notSet => (
        Icons.event_busy_outlined,
        'Not set up',
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
      ),
      BillingDueState.overdue => (
        Icons.warning_amber_rounded,
        'Overdue ${_days(-days!)}',
        colorScheme.onErrorContainer,
        colorScheme.errorContainer,
      ),
      BillingDueState.dueToday => (
        Icons.notifications_active_outlined,
        'Due today',
        const Color(0xFF7A4B00),
        const Color(0xFFFFE8C2),
      ),
      BillingDueState.dueSoon => (
        Icons.notifications_outlined,
        'Due in ${_days(days!)}',
        const Color(0xFF7A4B00),
        const Color(0xFFFFF3DC),
      ),
      BillingDueState.upcoming => (
        Icons.check_circle_outline,
        compact
            ? 'Due ${formatShortDate(billing.nextDueAt!)}'
            : 'Paid up · next ${formatShortDate(billing.nextDueAt!)}',
        ZonixColors.onEmeraldContainer,
        ZonixColors.emeraldContainer,
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

  static String _days(int n) => n == 1 ? '1 day' : '$n days';
}
