/// Pure aggregation behind one shop's detail page. Kept free of Firestore
/// types so the arithmetic can be tested directly on plain maps, and so
/// every view on the page can be recomputed from one [ShopActivity]
/// without going back to the network.
///
/// Field semantics match what the rest of the portal already assumes
/// (see also platform_aggregate.dart): soft-deleted docs skipped, `total`
/// on sales and `amount` elsewhere, COGS as unit_cost x quantity over
/// `items`, and a range inclusive of both end days.
library;

import '../models/product.dart';
import '../models/shop_activity.dart';
import '../models/shop_stats.dart';
import '../models/shop_transaction.dart';

/// [range] is inclusive of both end days; null means all time. A document
/// with no parsable created_at falls outside every bounded range, but is
/// still counted when the range is null.
bool _inRange(Map<String, dynamic> data, StatsDateRange? range) {
  if (range == null) return true;
  final raw = data['created_at'] as String?;
  final createdAt = raw == null ? null : DateTime.tryParse(raw);
  if (createdAt == null) return false;
  final endExclusive = range.end.add(const Duration(days: 1));
  return !createdAt.isBefore(range.start) && createdAt.isBefore(endExclusive);
}

/// The `created_at` string bounds for a Firestore query covering the day
/// range [from, to] (inclusive of both ends); null on a side means don't
/// bound it there.
///
/// Two deliberate choices make this safe against a schema this repo
/// doesn't own:
///
///  * **Date-only boundaries.** Every ISO8601 string starts YYYY-MM-DD and
///    sorts lexicographically, so comparing against a bare date works
///    whether the mobile app writes UTC ("...T09:00:00.000Z") or local
///    time with an offset — no assumption about which.
///  * **A day of slack on each end.** No timezone is more than 24h from
///    UTC, so a document written under a different convention than the
///    admin's local calendar day can still only land one day off. The
///    caller filters the result exactly (see [statsFrom]); this only has to
///    avoid *missing* a document, never to be precise.
({String? startAt, String? endBefore}) activityQueryBounds({
  DateTime? from,
  DateTime? to,
}) {
  String dateOnly(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year.toString().padLeft(4, '0')}-$month-$dayOfMonth';
  }

  return (
    startAt: from == null
        ? null
        : dateOnly(DateTime(from.year, from.month, from.day - 1)),
    // Exclusive: the day after [to], plus the same day of slack.
    endBefore: to == null
        ? null
        : dateOnly(DateTime(to.year, to.month, to.day + 2)),
  );
}

/// [range] filters sales/expenses/income by their created_at date; product
/// count is always all-time since it's a catalog size, not an activity
/// metric.
///
/// Filtering happens here rather than in the Firestore query because
/// created_at is stored as an ISO8601 string rather than a Timestamp,
/// which keeps this immune to any timezone mismatch between how the mobile
/// app serializes dates and how a server-side range query would need to
/// bound them.
ShopStats statsFrom(ShopActivity activity, {StatsDateRange? range}) {
  double sumField(List<ActivityDoc> docs, String field) {
    var total = 0.0;
    for (final doc in docs) {
      final data = doc.data;
      if (data['is_deleted'] == true) continue;
      if (!_inRange(data, range)) continue;
      total += (data[field] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  int countActiveInRange(List<ActivityDoc> docs) {
    return docs.where((doc) {
      return doc.data['is_deleted'] != true && _inRange(doc.data, range);
    }).length;
  }

  int countActive(List<ActivityDoc> docs) {
    return docs.where((doc) => doc.data['is_deleted'] != true).length;
  }

  double sumCogs(List<ActivityDoc> docs) {
    var total = 0.0;
    for (final doc in docs) {
      final data = doc.data;
      if (data['is_deleted'] == true) continue;
      if (!_inRange(data, range)) continue;
      final items = data['items'] as List<dynamic>? ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        final unitCost = (item['unit_cost'] as num?)?.toDouble() ?? 0;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        total += unitCost * quantity;
      }
    }
    return total;
  }

  return ShopStats(
    salesCount: countActiveInRange(activity.sales),
    totalRevenue: sumField(activity.sales, 'total'),
    totalCogs: sumCogs(activity.sales),
    totalExpenses: sumField(activity.expenses, 'amount'),
    totalAdditionalIncome: sumField(activity.additionalIncome, 'amount'),
    productCount: countActive(activity.products),
  );
}

/// The itemized activity behind [statsFrom]'s totals: every sale, expense,
/// and additional-income entry in [range] (same semantics as [statsFrom]),
/// newest first.
List<ShopTransaction> transactionsFrom(
  ShopActivity activity, {
  StatsDateRange? range,
}) {
  List<ShopTransaction> mapDocs(
    List<ActivityDoc> docs,
    ShopTransactionType type,
  ) {
    return docs
        .where(
          (doc) => doc.data['is_deleted'] != true && _inRange(doc.data, range),
        )
        .map((doc) => ShopTransaction.fromMap(doc.id, type, doc.data))
        .toList();
  }

  final transactions = [
    ...mapDocs(activity.sales, ShopTransactionType.sale),
    ...mapDocs(activity.expenses, ShopTransactionType.expense),
    ...mapDocs(activity.additionalIncome, ShopTransactionType.income),
  ];
  transactions.sort((a, b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null || bt == null) return 0;
    return bt.compareTo(at);
  });
  return transactions;
}

/// Daily revenue/expense totals for [start, end] (inclusive), for the
/// trend chart. One point per calendar day in the range, zero-filled for
/// days with no activity so the chart doesn't skip gaps.
List<DailyStat> dailySeriesFrom(
  ShopActivity activity, {
  required DateTime start,
  required DateTime end,
}) {
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final dayCount = endDay.difference(startDay).inDays + 1;

  final revenueByDay = List<double>.filled(dayCount, 0);
  final expensesByDay = List<double>.filled(dayCount, 0);

  int? dayIndex(String? rawCreatedAt) {
    if (rawCreatedAt == null) return null;
    final createdAt = DateTime.tryParse(rawCreatedAt);
    if (createdAt == null) return null;
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final index = day.difference(startDay).inDays;
    if (index < 0 || index >= dayCount) return null;
    return index;
  }

  for (final doc in activity.sales) {
    final data = doc.data;
    if (data['is_deleted'] == true) continue;
    final index = dayIndex(data['created_at'] as String?);
    if (index == null) continue;
    revenueByDay[index] += (data['total'] as num?)?.toDouble() ?? 0;
  }
  for (final doc in activity.expenses) {
    final data = doc.data;
    if (data['is_deleted'] == true) continue;
    final index = dayIndex(data['created_at'] as String?);
    if (index == null) continue;
    expensesByDay[index] += (data['amount'] as num?)?.toDouble() ?? 0;
  }

  return List.generate(dayCount, (i) {
    return DailyStat(
      day: startDay.add(Duration(days: i)),
      revenue: revenueByDay[i],
      expenses: expensesByDay[i],
    );
  });
}

/// Active (non-deleted) products, sorted alphabetically by name for a
/// stable, predictable display order.
List<Product> productsFrom(List<ActivityDoc> docs) {
  final products = docs
      .map((doc) => Product.fromMap(doc.id, doc.data))
      .where((p) => !p.isDeleted)
      .toList();
  products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return products;
}
