import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';
import 'package:zonixweb/features/billing/services/billing_service.dart';
import 'package:zonixweb/features/billing/widgets/billing_plan_card.dart';
import 'package:zonixweb/features/billing/widgets/billing_plan_dialog.dart';
import 'package:zonixweb/features/billing/widgets/payment_month_strip.dart';
import 'package:zonixweb/features/billing/widgets/payment_tile.dart';
import 'package:zonixweb/features/billing/widgets/record_payment_flow.dart';

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
          '${payment.coverageLabel} (paid '
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
                BillingPlanCard(
                  billing: billing,
                  onMarkPaid: () => _markPaid(billing),
                  onEditPlan: () => _editPlan(billing),
                ),
                const SizedBox(height: AppDimens.spacing24),
                SectionHeader(
                  icon: Icons.calendar_month_outlined,
                  label: 'Months',
                ),
                const SizedBox(height: AppDimens.spacing10),
                PaymentMonthStrip(
                  billing: billing,
                  onTapUnpaid: (m) => _markPaid(billing, period: m),
                ),
                const SizedBox(height: AppDimens.spacing24),
                SectionHeader(
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
                          PaymentTile(
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
