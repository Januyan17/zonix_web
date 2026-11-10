import 'package:cloud_firestore/cloud_firestore.dart';

/// A shop counts as "due soon" this many days before its next due date.
const kBillingDueSoonDays = 3;

enum BillingDueState {
  /// No next due date has been set for the shop.
  notSet,

  /// Due more than [kBillingDueSoonDays] days from today.
  upcoming,

  /// Due within [kBillingDueSoonDays] days (but not today).
  dueSoon,

  dueToday,

  /// The due date has passed without being moved on by a payment.
  overdue,
}

/// One month's subscription payment, as recorded by the admin.
class ShopPayment {
  const ShopPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.period,
    this.note,
    this.recordedAt,
  });

  final String id;
  final double amount;

  /// The exact date the customer paid.
  final DateTime paidAt;

  /// The month this payment covers, always the 1st of that month.
  final DateTime period;

  final String? note;

  /// When the admin entered it. Null for a moment while pending.
  final DateTime? recordedAt;

  factory ShopPayment.fromMap(Map<String, dynamic> map) {
    final paidAt = toDateTime(map['paid_at']) ?? DateTime(1970);
    return ShopPayment(
      id: map['id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paidAt: paidAt,
      period: parsePeriodKey(map['period'] as String?) ?? monthOf(paidAt),
      note: map['note'] as String?,
      recordedAt: toDateTime(map['recorded_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'paid_at': Timestamp.fromDate(paidAt),
    'period': periodKey(period),
    'note': note,
    'recorded_at': Timestamp.fromDate(recordedAt ?? DateTime.now()),
  };
}

/// A shop's billing plan and payment history, stored on its
/// `admin_shop_index/{slug}` doc (admin-only; never visible to the shop).
class ShopBilling {
  const ShopBilling({
    this.monthlyAmount,
    this.nextDueAt,
    this.payments = const [],
  });

  /// The usual monthly fee — the default amount when marking a payment.
  final double? monthlyAmount;

  /// When the next payment is expected. Null when billing isn't set up.
  final DateTime? nextDueAt;

  /// Newest payment first.
  final List<ShopPayment> payments;

  factory ShopBilling.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ShopBilling();
    final raw = map['billing_payments'];
    final payments = <ShopPayment>[
      if (raw is List)
        for (final p in raw)
          if (p is Map) ShopPayment.fromMap(Map<String, dynamic>.from(p)),
    ]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return ShopBilling(
      monthlyAmount: (map['billing_amount'] as num?)?.toDouble(),
      nextDueAt: toDateTime(map['billing_next_due_at']),
      payments: payments,
    );
  }

  bool get isSetUp => nextDueAt != null || monthlyAmount != null;

  ShopPayment? get lastPayment => payments.isEmpty ? null : payments.first;

  /// Payments covering [period]'s month (normally zero or one).
  List<ShopPayment> paymentsFor(DateTime period) {
    final key = periodKey(period);
    return payments.where((p) => periodKey(p.period) == key).toList();
  }

  bool isPaidFor(DateTime period) => paymentsFor(period).isNotEmpty;

  double get totalPaid => payments.fold(0, (total, p) => total + p.amount);

  /// Whole calendar days from today to the due date: 0 today, negative
  /// when overdue. Null when there's no due date.
  int? daysUntilDue(DateTime now) {
    final due = nextDueAt;
    if (due == null) return null;
    return calendarDaysBetween(now, due);
  }

  BillingDueState dueStateAt(DateTime now) {
    final days = daysUntilDue(now);
    if (days == null) return BillingDueState.notSet;
    if (days < 0) return BillingDueState.overdue;
    if (days == 0) return BillingDueState.dueToday;
    if (days <= kBillingDueSoonDays) return BillingDueState.dueSoon;
    return BillingDueState.upcoming;
  }

  /// Whether the shop needs the admin's attention (shown in the nav badge).
  bool needsAttentionAt(DateTime now) => switch (dueStateAt(now)) {
    BillingDueState.overdue ||
    BillingDueState.dueToday ||
    BillingDueState.dueSoon => true,
    _ => false,
  };
}

/// Tolerates anything that isn't a Timestamp by treating it as unknown, so
/// a hand-edited field never breaks a page.
DateTime? toDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar days from [from] to [to], ignoring time of day and DST.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// The same day next month, clamped to that month's last day
/// (31 Jan -> 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final firstOfTarget = DateTime(d.year, d.month + months);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(firstOfTarget.year, firstOfTarget.month, day);
}

String periodKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime? parsePeriodKey(String? key) {
  if (key == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
  if (match == null) return null;
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(match.group(1)!), month);
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

String shortMonthLabel(DateTime d) =>
    '${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';
