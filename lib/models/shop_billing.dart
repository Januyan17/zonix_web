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

/// Most months one payment may cover (e.g. a 3-year prepayment).
const kMaxPaymentMonths = 36;

/// A subscription payment, as recorded by the admin. Covers the months in
/// [periods] — one for a normal monthly payment, several when the customer
/// pays for more (any months, not necessarily consecutive).
class ShopPayment {
  ShopPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    required List<DateTime> periods,
    this.note,
    this.recordedAt,
  }) : assert(periods.isNotEmpty),
       periods = normalizePeriods(periods);

  final String id;
  final double amount;

  /// The exact date the customer paid.
  final DateTime paidAt;

  /// The months covered, each the 1st of its month, oldest first, no
  /// duplicates.
  final List<DateTime> periods;

  final String? note;

  /// When the admin entered it. Null for a moment while pending.
  final DateTime? recordedAt;

  /// The first month covered.
  DateTime get period => periods.first;

  /// The last month covered.
  DateTime get lastPeriod => periods.last;

  int get months => periods.length;

  bool covers(DateTime month) => periods.contains(monthOf(month));

  /// "November 2026", "Nov 2026 – Feb 2027" for a run of months, or
  /// "Nov 2026, Jan 2027" when there are gaps.
  String get coverageLabel => describePeriods(periods);

  factory ShopPayment.fromMap(Map<String, dynamic> map) {
    final paidAt = toDateTime(map['paid_at']) ?? DateTime(1970);
    final first = parsePeriodKey(map['period'] as String?) ?? monthOf(paidAt);

    // Newest format: an explicit list of months. Older payments have only
    // period (+ months for a consecutive run); those read as before.
    final raw = map['periods'];
    var periods = <DateTime>[
      if (raw is List)
        for (final k in raw)
          if (k is String) ?parsePeriodKey(k),
    ];
    if (periods.isEmpty) {
      final count = ((map['months'] as num?)?.toInt() ?? 1).clamp(
        1,
        kMaxPaymentMonths,
      );
      periods = [
        for (var i = 0; i < count; i++) DateTime(first.year, first.month + i),
      ];
    }

    return ShopPayment(
      id: map['id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paidAt: paidAt,
      periods: periods,
      note: map['note'] as String?,
      recordedAt: toDateTime(map['recorded_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'paid_at': Timestamp.fromDate(paidAt),
    // period/months kept alongside the list so older readers still work.
    'period': periodKey(period),
    'months': months,
    'periods': [for (final p in periods) periodKey(p)],
    'note': note,
    'recorded_at': Timestamp.fromDate(recordedAt ?? DateTime.now()),
  };
}

/// Months as 1st-of-month dates, de-duplicated and sorted oldest first.
List<DateTime> normalizePeriods(Iterable<DateTime> months) =>
    {for (final m in months) monthOf(m)}.toList()..sort();

/// See [ShopPayment.coverageLabel].
String describePeriods(List<DateTime> months) {
  final sorted = normalizePeriods(months);
  if (sorted.isEmpty) return 'No months';
  if (sorted.length == 1) return monthLabel(sorted.first);
  var consecutive = true;
  for (var i = 1; i < sorted.length; i++) {
    final prev = sorted[i - 1];
    if (sorted[i] != DateTime(prev.year, prev.month + 1)) {
      consecutive = false;
      break;
    }
  }
  if (consecutive) {
    return '${shortMonthLabel(sorted.first)} – ${shortMonthLabel(sorted.last)}';
  }
  return sorted.map(shortMonthLabel).join(', ');
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

  /// Payments covering [period]'s month — including multi-month ones that
  /// started earlier (normally zero or one).
  List<ShopPayment> paymentsFor(DateTime period) {
    return payments.where((p) => p.covers(period)).toList();
  }

  /// The last month covered by any payment, or null if none.
  DateTime? get paidThrough {
    DateTime? latest;
    for (final p in payments) {
      if (latest == null || p.lastPeriod.isAfter(latest)) {
        latest = p.lastPeriod;
      }
    }
    return latest;
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
