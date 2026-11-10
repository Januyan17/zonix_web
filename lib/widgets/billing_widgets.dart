import 'package:flutter/material.dart';

import '../models/shop_billing.dart';
import '../services/billing_service.dart';
import '../theme/app_dimens.dart';
import '../theme/zonix_colors.dart';
import '../utils/date_format.dart';
import '../utils/error_utils.dart';

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

/// Parses an amount typed by the admin ("1,500", "1500.00"). Null if blank
/// or invalid.
double? parseAmount(String text) {
  final cleaned = text.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String? amountError(String? text, {bool required = true}) {
  final v = text?.trim() ?? '';
  if (v.isEmpty) return required ? 'Enter the amount' : null;
  final amount = parseAmount(v);
  if (amount == null) return 'Enter a valid number';
  if (amount <= 0) return 'Amount must be more than 0';
  return null;
}

String _amountText(double? amount) {
  if (amount == null) return '';
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

/// A read-only field that opens a date picker on tap.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.icon = Icons.event_outlined,
    this.helperText,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final IconData icon;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(value == null ? 'Not set' : formatShortDate(value!)),
      ),
    );
  }
}

Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 5),
  );
}

/// Picks the month a payment covers, the next due date defaulting to the
/// paid date + 1 month (kept in step with the paid date until the admin
/// changes it by hand). Returns null if cancelled.
Future<PaymentInput?> showRecordPaymentDialog(
  BuildContext context, {
  required String shopName,
  required ShopBilling billing,
  DateTime? period,
}) {
  return showDialog<PaymentInput>(
    context: context,
    builder: (_) => _RecordPaymentDialog(
      shopName: shopName,
      billing: billing,
      initialPeriod: period,
    ),
  );
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({
    required this.shopName,
    required this.billing,
    this.initialPeriod,
  });

  final String shopName;
  final ShopBilling billing;
  final DateTime? initialPeriod;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: _amountText(widget.billing.monthlyAmount),
  );
  final _noteController = TextEditingController();

  late DateTime _paidAt = dateOnly(DateTime.now());
  late DateTime _period = widget.initialPeriod ?? _defaultPeriod();
  late DateTime _nextDueAt = addMonths(_paidAt, 1);
  bool _nextDueEdited = false;

  /// The first unpaid month from the due date's month (or this month),
  /// so marking "paid" usually needs no change here.
  DateTime _defaultPeriod() {
    final due = widget.billing.nextDueAt;
    var month = monthOf(due ?? DateTime.now());
    for (var i = 0; i < 24 && widget.billing.isPaidFor(month); i++) {
      month = DateTime(month.year, month.month + 1);
    }
    return month;
  }

  List<DateTime> get _periodOptions {
    final now = monthOf(DateTime.now());
    final options = [
      for (var i = -12; i <= 6; i++) DateTime(now.year, now.month + i),
    ];
    if (!options.contains(_period)) options.add(_period);
    options.sort();
    return options;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPaidAt() async {
    final picked = await _pickDate(context, _paidAt);
    if (picked == null || !mounted) return;
    setState(() {
      _paidAt = dateOnly(picked);
      if (!_nextDueEdited) _nextDueAt = addMonths(_paidAt, 1);
    });
  }

  Future<void> _pickNextDue() async {
    final picked = await _pickDate(context, _nextDueAt);
    if (picked == null || !mounted) return;
    setState(() {
      _nextDueAt = dateOnly(picked);
      _nextDueEdited = true;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      PaymentInput(
        amount: parseAmount(_amountController.text)!,
        paidAt: _paidAt,
        period: _period,
        nextDueAt: _nextDueAt,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alreadyPaid = widget.billing.isPaidFor(_period);
    return AlertDialog(
      title: Text('Mark paid — ${widget.shopName}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<DateTime>(
                  initialValue: _period,
                  decoration: InputDecoration(
                    labelText: 'Month paid for',
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    helperText: alreadyPaid
                        ? 'This month already has a payment recorded'
                        : null,
                  ),
                  items: [
                    for (final m in _periodOptions)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          widget.billing.isPaidFor(m)
                              ? '${monthLabel(m)}  ✓'
                              : monthLabel(m),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _period = v);
                  },
                ),
                const SizedBox(height: AppDimens.spacing16),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount received',
                    prefixText: 'Rs ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: amountError,
                ),
                const SizedBox(height: AppDimens.spacing16),
                _DateField(
                  label: 'Paid on',
                  value: _paidAt,
                  onPick: _pickPaidAt,
                ),
                const SizedBox(height: AppDimens.spacing16),
                _DateField(
                  label: 'Next due date (reminder)',
                  icon: Icons.notifications_outlined,
                  value: _nextDueAt,
                  onPick: _pickNextDue,
                  helperText: _nextDueEdited
                      ? null
                      : 'One month after the paid date',
                ),
                const SizedBox(height: AppDimens.spacing16),
                TextFormField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. cash, bank transfer ref',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded, size: AppDimens.iconLg),
          label: const Text('Save payment'),
        ),
      ],
    );
  }
}

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
    text: _amountText(widget.billing.monthlyAmount),
  );
  late DateTime? _nextDueAt = widget.billing.nextDueAt;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickNextDue() async {
    final picked = await _pickDate(context, _nextDueAt);
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
              _DateField(
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

/// Saves a payment through [service] with snackbar feedback. Returns true
/// on success.
Future<bool> recordPaymentFlow(
  BuildContext context, {
  required BillingService service,
  required String slug,
  required String shopName,
  required ShopBilling billing,
  DateTime? period,
}) async {
  final input = await showRecordPaymentDialog(
    context,
    shopName: shopName,
    billing: billing,
    period: period,
  );
  if (input == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await service.recordPayment(slug, input);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Payment for ${monthLabel(input.period)} saved. '
          'Next due ${formatShortDate(input.nextDueAt!)}.',
        ),
      ),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to save payment: ${describeError(e)}')),
    );
    return false;
  }
}
