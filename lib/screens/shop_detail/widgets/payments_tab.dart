import 'package:flutter/material.dart';

import '../../../models/shop_billing.dart';
import '../../../services/billing_service.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/zonix_colors.dart';
import '../../../utils/date_format.dart';
import '../../../utils/error_utils.dart';
import '../../../utils/money_format.dart';
import '../../../widgets/billing_widgets.dart';

/// The shop detail page's "Payments" tab: the shop's monthly plan (amount
/// and next due date), a month-by-month paid/unpaid strip, and the full
/// payment history. Live, so a payment marked from the Payments page shows
/// up here too.
class ShopPaymentsTab extends StatefulWidget {
  const ShopPaymentsTab({
    super.key,
    required this.slug,
    required this.shopName,
    this.billingService,
  });

  final String slug;
  final String shopName;
  final BillingService? billingService;

  @override
  State<ShopPaymentsTab> createState() => _ShopPaymentsTabState();
}

class _ShopPaymentsTabState extends State<ShopPaymentsTab>
    with AutomaticKeepAliveClientMixin {
  late final BillingService _service =
      widget.billingService ?? BillingService();
  late Stream<ShopBilling> _stream = _service.watchShop(widget.slug);

  @override
  bool get wantKeepAlive => true;

  Future<void> _markPaid(ShopBilling billing, {DateTime? period}) {
    return recordPaymentFlow(
      context,
      service: _service,
      slug: widget.slug,
      shopName: widget.shopName,
      billing: billing,
      period: period,
    );
  }

  Future<void> _editPlan(ShopBilling billing) async {
    final result = await showBillingPlanDialog(context, billing: billing);
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.setPlan(
        widget.slug,
        monthlyAmount: result.monthlyAmount,
        nextDueAt: result.nextDueAt,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Billing plan saved')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save plan: ${describeError(e)}')),
      );
    }
  }

  Future<void> _deletePayment(ShopPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment?'),
        content: Text(
          'Remove the ${formatMoney(payment.amount)} payment for '
          '${monthLabel(payment.period)} (paid '
          '${formatShortDate(payment.paidAt)})? The next due date '
          'won\'t change — edit the plan if it should.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deletePayment(widget.slug, payment.id);
      messenger.showSnackBar(const SnackBar(content: Text('Payment deleted')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete: ${describeError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<ShopBilling>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: AppDimens.paddingAll24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(describeError(snapshot.error!)),
                  const SizedBox(height: AppDimens.spacing16),
                  FilledButton(
                    onPressed: () => setState(
                      () => _stream = _service.watchShop(widget.slug),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final billing = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: AppDimens.paddingAll20,
              children: [
                _PlanCard(
                  billing: billing,
                  onMarkPaid: () => _markPaid(billing),
                  onEditPlan: () => _editPlan(billing),
                ),
                const SizedBox(height: AppDimens.spacing24),
                _SectionTitle(
                  icon: Icons.calendar_month_outlined,
                  label: 'Months',
                ),
                const SizedBox(height: AppDimens.spacing10),
                _MonthStrip(
                  billing: billing,
                  onTapUnpaid: (m) => _markPaid(billing, period: m),
                ),
                const SizedBox(height: AppDimens.spacing24),
                _SectionTitle(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payment history (${billing.payments.length})',
                  trailing: billing.payments.isEmpty
                      ? null
                      : Text(
                          'Total ${formatMoney(billing.totalPaid)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(height: AppDimens.spacing10),
                if (billing.payments.isEmpty)
                  Card(
                    child: Padding(
                      padding: AppDimens.paddingAll24,
                      child: Center(
                        child: Text(
                          'No payments recorded yet.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < billing.payments.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _PaymentTile(
                            payment: billing.payments[i],
                            onDelete: () => _deletePayment(billing.payments[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconLg, color: colorScheme.primary),
        const SizedBox(width: AppDimens.spacing8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
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
            row(
              Icons.history_rounded,
              'Last payment',
              last == null
                  ? 'None yet'
                  : '${formatMoney(last.amount)} on '
                        '${formatShortDate(last.paidAt)}',
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

/// The last 12 months (plus next month), each paid ✓ or not. Tapping an
/// unpaid month opens "Mark as paid" for it.
class _MonthStrip extends StatelessWidget {
  const _MonthStrip({required this.billing, required this.onTapUnpaid});

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
                  final total = paid.fold<double>(0, (t, p) => t + p.amount);
                  return Tooltip(
                    message: isPaid
                        ? '${monthLabel(m)}: ${formatMoney(total)} paid'
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

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onDelete});

  final ShopPayment payment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final note = payment.note;
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: ZonixColors.emeraldContainer,
        child: Icon(Icons.check_rounded, color: ZonixColors.onEmeraldContainer),
      ),
      title: Text(
        '${monthLabel(payment.period)} · ${formatMoney(payment.amount)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          'Paid on ${formatShortDate(payment.paidAt)}',
          if (note != null && note.isNotEmpty) note,
        ].join('\n'),
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      isThreeLine: note != null && note.isNotEmpty,
      trailing: IconButton(
        tooltip: 'Delete payment',
        icon: Icon(Icons.delete_outline, color: colorScheme.error),
        onPressed: onDelete,
      ),
    );
  }
}
