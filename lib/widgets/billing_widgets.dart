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

/// Picks the months a payment covers (any months, ticked on a year view),
/// the amount, the exact paid date and the next due date. The next due
/// date defaults to the end of the paid run (kept in step until the admin
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

/// The default next due date for a payment of [selected] months made on
/// [paidAt], given payments already in [billing]:
/// - a consecutive run of N months: [paidAt] + N months (for one month,
///   exactly the one-month-after-paying rule);
/// - months with gaps: the paid date's day in the first month from the
///   selection's start that is still unpaid, so the gap gets reminded.
DateTime defaultNextDue({
  required DateTime paidAt,
  required List<DateTime> selected,
  required ShopBilling billing,
}) {
  final months = normalizePeriods(selected);
  if (months.isEmpty) return addMonths(paidAt, 1);
  var consecutive = true;
  for (var i = 1; i < months.length; i++) {
    final prev = months[i - 1];
    if (months[i] != DateTime(prev.year, prev.month + 1)) {
      consecutive = false;
      break;
    }
  }
  if (consecutive) return addMonths(dateOnly(paidAt), months.length);

  var m = months.first;
  for (var i = 0; i < kMaxPaymentMonths * 2; i++) {
    if (!months.contains(m) && !billing.isPaidFor(m)) break;
    m = DateTime(m.year, m.month + 1);
  }
  final lastDay = DateTime(m.year, m.month + 1, 0).day;
  return DateTime(m.year, m.month, paidAt.day > lastDay ? lastDay : paidAt.day);
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

  /// Where quick picks start: the tapped month, or the first unpaid one.
  late final DateTime _start = monthOf(
    widget.initialPeriod ?? _firstUnpaidFrom(widget.billing.nextDueAt),
  );

  /// The ticked months (1st of each month).
  late final Set<DateTime> _selected = {_start};

  /// The year shown in the month grid.
  late int _viewYear = _start.year;

  late DateTime _nextDueAt = _computedNextDue();
  bool _nextDueEdited = false;

  /// Once the admin types an amount, changing the months stops
  /// recalculating it from the monthly fee.
  bool _amountEdited = false;

  bool _showNoMonthError = false;

  static const _quickCounts = [3, 6, 12];
  static const _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  DateTime _firstUnpaidFrom(DateTime? from) {
    var month = monthOf(from ?? DateTime.now());
    for (var i = 0; i < 48 && widget.billing.isPaidFor(month); i++) {
      month = DateTime(month.year, month.month + 1);
    }
    return month;
  }

  List<DateTime> get _sortedSelection => normalizePeriods(_selected);

  DateTime _computedNextDue() => defaultNextDue(
    paidAt: _paidAt,
    selected: _sortedSelection,
    billing: widget.billing,
  );

  /// Re-derives the amount and next due date after the selection changed.
  void _selectionChanged() {
    _showNoMonthError = false;
    if (!_nextDueEdited && _selected.isNotEmpty) {
      _nextDueAt = _computedNextDue();
    }
    final fee = widget.billing.monthlyAmount;
    if (!_amountEdited && fee != null && _selected.isNotEmpty) {
      _amountController.text = _amountText(fee * _selected.length);
    }
  }

  void _toggle(DateTime month) {
    setState(() {
      if (!_selected.remove(month)) {
        if (_selected.length >= kMaxPaymentMonths) return;
        _selected.add(month);
      }
      _selectionChanged();
    });
  }

  /// Selects [count] unpaid months in a row from the start month,
  /// skipping any already paid.
  void _quickSelect(int count) {
    setState(() {
      _selected.clear();
      var m = _start;
      for (var i = 0; _selected.length < count && i < count + 48; i++) {
        if (!widget.billing.isPaidFor(m)) _selected.add(m);
        m = DateTime(m.year, m.month + 1);
      }
      _viewYear = _start.year;
      _selectionChanged();
    });
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
      if (!_nextDueEdited) _nextDueAt = _computedNextDue();
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
    final formOk = _formKey.currentState!.validate();
    if (_selected.isEmpty) {
      setState(() => _showNoMonthError = true);
      return;
    }
    if (!formOk) return;
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      PaymentInput(
        amount: parseAmount(_amountController.text)!,
        paidAt: _paidAt,
        periods: _sortedSelection,
        nextDueAt: _nextDueAt,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Widget _buildMonthPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nowYear = DateTime.now().year;
    final selected = _sortedSelection;
    final overlapping = selected.where(widget.billing.isPaidFor).length;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Months paid for',
        prefixIcon: const Icon(Icons.calendar_month_outlined),
        errorText: _showNoMonthError ? 'Select at least one month' : null,
        helperText: selected.isEmpty
            ? 'Tap the months this payment covers'
            : '${describePeriods(selected)} · '
                  '${selected.length} month${selected.length == 1 ? '' : 's'}',
        helperMaxLines: 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous year',
                visualDensity: VisualDensity.compact,
                onPressed: _viewYear > nowYear - 3
                    ? () => setState(() => _viewYear--)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '$_viewYear',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Next year',
                visualDensity: VisualDensity.compact,
                onPressed: _viewYear < nowYear + 3
                    ? () => setState(() => _viewYear++)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppDimens.spacing6,
            crossAxisSpacing: AppDimens.spacing6,
            childAspectRatio: 2.2,
            children: [
              for (var month = 1; month <= 12; month++)
                _monthCell(colorScheme, DateTime(_viewYear, month)),
            ],
          ),
          const SizedBox(height: AppDimens.spacing8),
          Wrap(
            spacing: AppDimens.spacing6,
            runSpacing: AppDimens.spacing6,
            children: [
              for (final n in _quickCounts)
                ActionChip(
                  label: Text(n == 12 ? 'Next 12 months' : 'Next $n months'),
                  onPressed: () => _quickSelect(n),
                ),
              if (_selected.isNotEmpty)
                ActionChip(
                  label: const Text('Clear'),
                  onPressed: () => setState(() {
                    _selected.clear();
                    _selectionChanged();
                  }),
                ),
            ],
          ),
          if (overlapping > 0) ...[
            const SizedBox(height: AppDimens.spacing6),
            Text(
              '$overlapping selected month${overlapping == 1 ? ' is' : 's are'} '
              'already paid',
              style: TextStyle(
                fontSize: AppDimens.fontLabel,
                color: colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _monthCell(ColorScheme colorScheme, DateTime month) {
    final isSelected = _selected.contains(month);
    final isPaid = widget.billing.isPaidFor(month);
    final now = monthOf(DateTime.now());
    final isCurrent = month == now;

    final Color bg;
    final Color fg;
    if (isSelected) {
      bg = colorScheme.primary;
      fg = colorScheme.onPrimary;
    } else if (isPaid) {
      bg = ZonixColors.emeraldContainer;
      fg = ZonixColors.onEmeraldContainer;
    } else {
      bg = colorScheme.surfaceContainerHighest;
      fg = colorScheme.onSurface;
    }

    return Tooltip(
      message: isPaid
          ? '${monthLabel(month)} — already paid'
          : monthLabel(month),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          onTap: () => _toggle(month),
          child: Container(
            decoration: isCurrent
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    border: Border.all(color: colorScheme.primary, width: 1.5),
                  )
                : null,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected || isPaid) ...[
                  Icon(
                    isSelected ? Icons.check_rounded : Icons.check_circle,
                    size: AppDimens.iconXs,
                    color: fg,
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  _monthAbbr[month.month - 1],
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return AlertDialog(
      title: Text('Mark paid — ${widget.shopName}'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMonthPicker(context),
                const SizedBox(height: AppDimens.spacing16),
                TextFormField(
                  controller: _amountController,
                  onChanged: (_) => _amountEdited = true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount received',
                    prefixText: 'Rs ',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    helperText:
                        !_amountEdited &&
                            widget.billing.monthlyAmount != null &&
                            count > 1
                        ? 'Monthly fee × $count months'
                        : null,
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
                      : count <= 1
                      ? 'One month after the paid date'
                      : 'When the paid months run out',
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
          label: Text(
            count > 1 ? 'Save payment ($count months)' : 'Save payment',
          ),
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
          'Payment for ${_inputCoverage(input)} saved. '
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

String _inputCoverage(PaymentInput input) {
  final label = describePeriods(input.periods);
  return input.months <= 1 ? label : '$label (${input.months} months)';
}
