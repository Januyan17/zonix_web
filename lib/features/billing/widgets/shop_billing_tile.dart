import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';
import 'package:zonixweb/features/billing/services/billing_service.dart';
import 'package:zonixweb/features/billing/widgets/billing_due_badge.dart';

class ShopBillingTile extends StatelessWidget {
  const ShopBillingTile({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onMarkPaid,
  });

  final ShopBillingEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final billing = entry.billing;
    final last = billing.lastPayment;
    final details = [
      if (billing.nextDueAt != null)
        'Due ${formatShortDate(billing.nextDueAt!)}',
      if (billing.monthlyAmount != null) formatMoney(billing.monthlyAmount!),
      if (last != null) 'Last paid ${formatShortDate(last.paidAt)}',
      if (billing.paidThrough != null)
        'Paid until ${shortMonthLabel(billing.paidThrough!)}',
    ].join(' · ');

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: AppDimens.paddingH16V12,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimens.spacing4),
                  Wrap(
                    spacing: AppDimens.spacing8,
                    runSpacing: AppDimens.spacing4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      BillingDueBadge(billing: billing, compact: true),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          style: TextStyle(
                            fontSize: AppDimens.fontLabel,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spacing8),
            OutlinedButton.icon(
              onPressed: onMarkPaid,
              icon: const Icon(
                Icons.check_circle_outline,
                size: AppDimens.iconLg,
              ),
              label: const Text('Mark paid'),
            ),
          ],
        ),
      ),
    );
  }
}
