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
import '../models/shop_insights.dart';
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

  /// Cost and quantity come out of the same walk over the line items:
  /// they read the same two fields of the same maps, and doing it twice
  /// would double the work over the largest collection on the page.
  ({double cogs, double units}) sumItems(List<ActivityDoc> docs) {
    var cogs = 0.0;
    var units = 0.0;
    for (final doc in docs) {
      final data = doc.data;
      if (data['is_deleted'] == true) continue;
      if (!_inRange(data, range)) continue;
      final items = data['items'] as List<dynamic>? ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        final unitCost = (item['unit_cost'] as num?)?.toDouble() ?? 0;
        final quantity = itemQuantity(item);
        cogs += unitCost * quantity;
        units += quantity;
      }
    }
    return (cogs: cogs, units: units);
  }

  final items = sumItems(activity.sales);

  return ShopStats(
    salesCount: countActiveInRange(activity.sales),
    totalRevenue: sumField(activity.sales, 'total'),
    totalCogs: items.cogs,
    totalExpenses: sumField(activity.expenses, 'amount'),
    totalAdditionalIncome: sumField(activity.additionalIncome, 'amount'),
    productCount: countActive(activity.products),
    unitsSold: items.units,
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

// --- Line-item field readers -------------------------------------------
//
// A sale's `items` are written by the mobile app, which isn't part of this
// repo. Only `unit_cost` and `quantity` were already relied on here; every
// other field these readers need is tried across the plausible spellings
// and falls back rather than throwing, matching how Product and
// ShopTransaction read theirs.

num? _itemNum(Map<dynamic, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String? _itemString(Map<dynamic, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// A line's quantity, defaulting to 1 rather than 0 when absent: an item
/// present on a sale was sold at least once, and defaulting to zero would
/// silently drop it from every unit count.
double itemQuantity(Map<dynamic, dynamic> item) {
  return _itemNum(item, ['quantity', 'qty', 'count'])?.toDouble() ?? 1;
}

/// What a line actually brought in. Prefers a line total the app already
/// computed — that one has any per-line discount baked in — and only falls
/// back to price × quantity when there is none.
double itemRevenue(Map<dynamic, dynamic> item) {
  final explicit = _itemNum(item, [
    'total',
    'line_total',
    'lineTotal',
    'subtotal',
    'amount',
  ]);
  if (explicit != null) return explicit.toDouble();
  final unitPrice = _itemNum(item, ['unit_price', 'price', 'selling_price']);
  if (unitPrice == null) return 0;
  return unitPrice.toDouble() * itemQuantity(item);
}

/// How a line item identifies its product. The document id when it carries
/// one; otherwise the lowercased name, so lines that name the same product
/// still group into one row instead of one row each.
String? _itemKey(Map<dynamic, dynamic> item, String? name) {
  final id = _itemString(item, [
    'product_id',
    'productId',
    'product',
    'id',
    'sku',
  ]);
  if (id != null) return id;
  return name?.toLowerCase();
}

String? _itemName(Map<dynamic, dynamic> item) {
  return _itemString(item, ['name', 'product_name', 'productName', 'title']);
}

/// Per-product sales performance over [range] (same semantics as
/// [statsFrom]), best-selling first by revenue.
///
/// Summed from the line items of each sale, so it reflects what was
/// charged at the time rather than the catalog's current price. Two
/// consequences worth knowing when reading it next to the stat tiles:
///
///  * Line revenue need not add up to the sale's `total` — a whole-sale
///    discount, a rounding, or a tax line lives on the sale, not on its
///    items — so this ranks products against each other rather than
///    reconciling to the revenue tile.
///  * A sale carrying no items at all contributes nothing here, which is
///    why the caller shows the section as empty rather than as zeroes.
List<ProductPerformance> productPerformanceFrom(
  ShopActivity activity, {
  StatsDateRange? range,
}) {
  final byKey = <String, ProductPerformance>{};

  for (final doc in activity.sales) {
    final data = doc.data;
    if (data['is_deleted'] == true) continue;
    if (!_inRange(data, range)) continue;

    final items = data['items'] as List<dynamic>? ?? const [];
    // One sale counts once towards a product's saleCount however many
    // separate lines of it the basket holds.
    final seenInThisSale = <String>{};

    for (final item in items) {
      if (item is! Map) continue;
      final name = _itemName(item);
      final key = _itemKey(item, name);
      if (key == null) continue;

      final quantity = itemQuantity(item);
      final revenue = itemRevenue(item);
      final cogs = (_itemNum(item, ['unit_cost', 'cost', 'cost_price'])
                  ?.toDouble() ??
              0) *
          quantity;

      final existing = byKey[key];
      final isNewSale = seenInThisSale.add(key);
      byKey[key] = ProductPerformance(
        key: key,
        // Keep the first name seen for a key; a later line that carries
        // only an id shouldn't blank out a label already established.
        name: existing?.name ?? name ?? 'Unnamed item',
        unitsSold: (existing?.unitsSold ?? 0) + quantity,
        revenue: (existing?.revenue ?? 0) + revenue,
        cogs: (existing?.cogs ?? 0) + cogs,
        saleCount: (existing?.saleCount ?? 0) + (isNewSale ? 1 : 0),
      );
    }
  }

  final ranked = byKey.values.toList();
  ranked.sort((a, b) {
    final byRevenue = b.revenue.compareTo(a.revenue);
    if (byRevenue != 0) return byRevenue;
    // Ties broken by units then name so the order is stable across
    // rebuilds rather than following map insertion.
    final byUnits = b.unitsSold.compareTo(a.unitsSold);
    if (byUnits != 0) return byUnits;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return ranked;
}

/// Catalog products that sold nothing at all in [range] — shelf space and
/// stock money tied up in things nobody is buying.
///
/// A product counts as sold if any line item in the range matches it by
/// document id or by name, since which of those a line carries depends on
/// the mobile app. Returned alphabetically, matching [productsFrom].
List<Product> deadStockFrom(
  ShopActivity activity, {
  StatsDateRange? range,
}) {
  final sold = <String>{};
  for (final performance in productPerformanceFrom(activity, range: range)) {
    sold.add(performance.key.toLowerCase());
    sold.add(performance.name.toLowerCase());
  }

  return productsFrom(activity.products)
      .where(
        (product) =>
            !sold.contains(product.id.toLowerCase()) &&
            !sold.contains(product.name.toLowerCase()),
      )
      .toList();
}

/// Sales per hour of the trading day, all 24 slots present so a quiet hour
/// reads as a gap rather than being skipped.
///
/// Bucketed by the local hour of each sale's `created_at`, which is the
/// same clock the shop was standing at when it rang the sale up.
List<HourBucket> hourlySalesFrom(
  ShopActivity activity, {
  StatsDateRange? range,
}) {
  final counts = List<int>.filled(24, 0);
  final revenue = List<double>.filled(24, 0);

  for (final doc in activity.sales) {
    final data = doc.data;
    if (data['is_deleted'] == true) continue;
    if (!_inRange(data, range)) continue;
    final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '');
    if (createdAt == null) continue;
    counts[createdAt.hour]++;
    revenue[createdAt.hour] += (data['total'] as num?)?.toDouble() ?? 0;
  }

  return List.generate(
    24,
    (hour) => HourBucket(
      hour: hour,
      salesCount: counts[hour],
      revenue: revenue[hour],
    ),
  );
}

/// Sales per day of the week, Monday first, all seven present.
///
/// Only meaningful over a range spanning more than a week; the caller
/// hides it for a single day.
List<WeekdayBucket> weekdaySalesFrom(
  ShopActivity activity, {
  StatsDateRange? range,
}) {
  final counts = List<int>.filled(7, 0);
  final revenue = List<double>.filled(7, 0);

  for (final doc in activity.sales) {
    final data = doc.data;
    if (data['is_deleted'] == true) continue;
    if (!_inRange(data, range)) continue;
    final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '');
    if (createdAt == null) continue;
    final index = createdAt.weekday - 1;
    counts[index]++;
    revenue[index] += (data['total'] as num?)?.toDouble() ?? 0;
  }

  return List.generate(
    7,
    (index) => WeekdayBucket(
      weekday: index + 1,
      salesCount: counts[index],
      revenue: revenue[index],
    ),
  );
}

/// Sales rung up and then deleted in [range], against those that stood.
///
/// This is the one figure on the page that looks at soft-deleted documents
/// rather than skipping them.
VoidStats voidedSalesFrom(ShopActivity activity, {StatsDateRange? range}) {
  var count = 0;
  var value = 0.0;
  var kept = 0;

  for (final doc in activity.sales) {
    final data = doc.data;
    if (!_inRange(data, range)) continue;
    if (data['is_deleted'] == true) {
      count++;
      value += (data['total'] as num?)?.toDouble() ?? 0;
    } else {
      kept++;
    }
  }

  return VoidStats(count: count, value: value, keptCount: kept);
}

/// The equally-long range ending the day before [range] starts — what
/// "vs. previous period" compares against.
///
/// Null for an unbounded range: all time has nothing before it. Built with
/// calendar arithmetic rather than [Duration] so a daylight-saving shift
/// inside the window can't slide the boundary onto the wrong day.
StatsDateRange? precedingRange(StatsDateRange? range) {
  if (range == null) return null;
  final days = range.dayCount;
  final start = range.start;
  return StatsDateRange(
    start: DateTime(start.year, start.month, start.day - days),
    end: DateTime(start.year, start.month, start.day - 1),
  );
}

/// [range]'s figures alongside the period immediately before it. Null when
/// there is no previous period to compare with (all time).
StatsComparison? comparisonFrom(
  ShopActivity activity, {
  required StatsDateRange? range,
}) {
  final previous = precedingRange(range);
  if (previous == null) return null;
  // Only comparable if the previous period's documents were actually
  // fetched; otherwise its emptiness would be an artifact of the window,
  // and every tile would read "up ∞%".
  if (!activity.covers(from: previous.start, to: previous.end)) return null;

  return StatsComparison(
    current: statsFrom(activity, range: range),
    previous: statsFrom(activity, range: previous),
    previousRange: previous,
  );
}
