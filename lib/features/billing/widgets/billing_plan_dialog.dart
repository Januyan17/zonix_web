import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';
import 'package:zonixweb/features/billing/utils/billing_amount.dart';
import 'package:zonixweb/features/billing/widgets/billing_date_field.dart';

/// The plan: usual monthly amount and next due date.
class BillingPlanResult {
  const BillingPlanResult({
    required this.monthlyAmount,
    required this.nextDueAt,
  });

  final double? monthlyAmount;
  final DateTime? nextDueAt;
}

Future<BillingPlanResult?> showBillingPlanDialog(
  BuildContext context, {
  required ShopBilling billing,
}) {
  return showDialog<BillingPlanResult>(
    context: context,
    builder: (_) => _BillingPlanDialog(billing: billing),
  );
}

class _BillingPlanDialog extends StatefulWidget {
  const _BillingPlanDialog({required this.billing});

  final ShopBilling billing;

  @override
  State<_BillingPlanDialog> createState() => _BillingPlanDialogState();
}

class _BillingPlanDialogState extends State<_BillingPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: formatAmountInput(widget.billing.monthlyAmount),
  );
  late DateTime? _nextDueAt = widget.billing.nextDueAt;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickNextDue() async {
    final picked = await pickBillingDate(context, _nextDueAt);
    if (picked == null || !mounted) return;
    setState(() => _nextDueAt = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly billing'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly amount',
                  prefixText: 'Rs ',
                  prefixIcon: Icon(Icons.payments_outlined),
                  helperText: 'Pre-filled when marking a payment',
                ),
                validator: (v) => amountError(v, required: false),
              ),
              const SizedBox(height: AppDimens.spacing16),
              BillingDateField(
                label: 'Next due date',
                icon: Icons.notifications_outlined,
                value: _nextDueAt,
                onPick: _pickNextDue,
                helperText: 'You will be reminded from this date',
              ),
              if (_nextDueAt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _nextDueAt = null),
                    child: const Text('Clear due date'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              BillingPlanResult(
                monthlyAmount: parseAmount(_amountController.text),
                nextDueAt: _nextDueAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
