import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';

/// The last 12 months (plus next month), each paid ✓ or not. Tapping an
/// unpaid month opens "Mark as paid" for it.
class PaymentMonthStrip extends StatelessWidget {
  const PaymentMonthStrip({
    super.key,
    required this.billing,
    required this.onTapUnpaid,
  });

  final ShopBilling billing;
  final ValueChanged<DateTime> onTapUnpaid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = monthOf(DateTime.now());
    final months = [
      for (var i = 1; i >= -11; i--) DateTime(now.year, now.month + i),
    ];
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll14,
        child: Wrap(
          spacing: AppDimens.spacing8,
          runSpacing: AppDimens.spacing8,
          children: [
            for (final m in months)
              Builder(
                builder: (context) {
                  final paid = billing.paymentsFor(m);
                  final isPaid = paid.isNotEmpty;
                  return Tooltip(
                    message: isPaid
                        ? '${monthLabel(m)}: paid — ${paid.map((p) => p.months > 1 ? '${formatMoney(p.amount)} for ${p.coverageLabel}' : formatMoney(p.amount)).join(', ')}'
                        : '${monthLabel(m)}: not paid — tap to mark paid',
                    child: ActionChip(
                      avatar: Icon(
                        isPaid
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: AppDimens.iconSm,
                        color: isPaid
                            ? ZonixColors.emerald
                            : colorScheme.onSurfaceVariant,
                      ),
                      label: Text(shortMonthLabel(m)),
                      backgroundColor: isPaid
                          ? ZonixColors.emeraldContainer
                          : colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: isPaid
                            ? ZonixColors.onEmeraldContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      onPressed: isPaid ? null : () => onTapUnpaid(m),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
