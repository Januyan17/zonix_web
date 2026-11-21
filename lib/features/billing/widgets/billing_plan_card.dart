import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';
import 'package:zonixweb/features/billing/widgets/billing_due_badge.dart';

class BillingPlanCard extends StatelessWidget {
  const BillingPlanCard({
    super.key,
    required this.billing,
    required this.onMarkPaid,
    required this.onEditPlan,
  });

  final ShopBilling billing;
  final VoidCallback onMarkPaid;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final last = billing.lastPayment;
    final state = billing.dueStateAt(DateTime.now());

    Widget row(IconData icon, String label, String value, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing6),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppDimens.iconLg,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimens.spacing10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BillingDueBadge(billing: billing),
            ),
            const SizedBox(height: AppDimens.spacing12),
            if (!billing.isSetUp && billing.payments.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spacing8),
                child: Text(
                  'Set a monthly amount and due date to get reminded when '
                  'this shop\'s payment is due, or just mark a payment — '
                  'the next due date is set one month after it.',
                  style: TextStyle(
                    fontSize: AppDimens.fontBody,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            row(
              Icons.notifications_outlined,
              'Next due date',
              billing.nextDueAt == null
                  ? 'Not set'
                  : formatShortDate(billing.nextDueAt!),
              color: state == BillingDueState.overdue
                  ? colorScheme.error
                  : null,
            ),
            row(
              Icons.payments_outlined,
              'Monthly amount',
              billing.monthlyAmount == null
                  ? 'Not set'
                  : formatMoney(billing.monthlyAmount!),
            ),
            if (billing.paidThrough != null)
              row(
                Icons.event_available_outlined,
                'Paid until',
                'End of ${monthLabel(billing.paidThrough!)}',
              ),
            row(
              Icons.history_rounded,
              'Last payment',
              last == null
                  ? 'None yet'
                  : '${formatMoney(last.amount)} on '
                        '${formatShortDate(last.paidAt)}'
                        '${last.months > 1 ? ' (${last.months} months)' : ''}',
            ),
            const SizedBox(height: AppDimens.spacing12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppDimens.spacing10,
              runSpacing: AppDimens.spacing10,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditPlan,
                  icon: const Icon(
                    Icons.edit_calendar_outlined,
                    size: AppDimens.iconLg,
                  ),
                  label: const Text('Edit plan'),
                ),
                FilledButton.icon(
                  onPressed: onMarkPaid,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: AppDimens.iconLg,
                  ),
                  label: const Text('Mark as paid'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
