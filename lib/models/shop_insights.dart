import 'shop_stats.dart';

/// The percentage change from [previous] to [current], as a fraction
/// (0.25 = up 25%).
///
/// Null when [previous] is zero: growth from nothing is undefined, and
/// rendering it as "+100%" or "∞%" would put a number on the page that
/// means nothing. Callers show "no prior activity" instead.
double? percentChange(double previous, double current) {
  if (previous == 0) return null;
  return (current - previous) / previous;
}

/// One product's contribution to a shop's sales over some range, summed
/// from the line items on its sale documents rather than from the catalog.
///
/// Deliberately built from the sales side: a product renamed, re-priced or
/// deleted from the catalog still sold what it sold, and the line items
/// carry the price and cost as they were at the time of sale.
class ProductPerformance {
  const ProductPerformance({
    required this.key,
    required this.name,
    required this.unitsSold,
    required this.revenue,
    required this.cogs,
    required this.saleCount,
  });

  /// The line item's product id when it carries one, otherwise its
  /// lowercased name. The mobile app that writes these documents isn't part
  /// of this repo, so items that identify themselves only by label still
  /// have to group together rather than each becoming its own row.
  final String key;

  final String name;

  /// Fractional because quantity can be a weight, not just a count.
  final double unitsSold;

  final double revenue;
  final double cogs;

  /// How many separate sales this product appeared on — a product moving
  /// 100 units across 100 baskets is a different story from 100 units
  /// across two.
  final int saleCount;

  double get grossProfit => revenue - cogs;

  /// Null when the product sold for nothing (a giveaway or a zero-priced
  /// line), where a margin percentage has no meaning.
  double? get margin => revenue == 0 ? null : grossProfit / revenue;
}

/// Sales activity in one hour-of-day slot, summed across every day in the
/// range — the shape of a trading day, for staffing and opening hours.
class HourBucket {
  const HourBucket({
    required this.hour,
    required this.salesCount,
    required this.revenue,
  });

  /// 0–23, in the timezone the sale's `created_at` was written in.
  final int hour;

  final int salesCount;
  final double revenue;
}

/// Sales activity on one day of the week, summed across every such day in
/// the range.
class WeekdayBucket {
  const WeekdayBucket({
    required this.weekday,
    required this.salesCount,
    required this.revenue,
  });

  /// [DateTime.monday]–[DateTime.sunday] (1–7).
  final int weekday;

  final int salesCount;
  final double revenue;
}

/// Sales that were rung up and then deleted.
///
/// Every other figure on the page skips soft-deleted documents, which is
/// right for revenue but hides the deletions themselves. A void is a normal
/// part of running a till — a mis-scan, a customer changing their mind —
/// but a shop voiding a large share of its sales, or a large share of its
/// money, is worth a look.
class VoidStats {
  const VoidStats({
    required this.count,
    required this.value,
    required this.keptCount,
  });

  final int count;

  /// What those voided sales would have totalled.
  final double value;

  /// Sales in the same range that were not deleted — the rest of the
  /// denominator behind [rate].
  final int keptCount;

  int get totalRung => count + keptCount;

  /// Voided share of everything rung up, or null when nothing was.
  double? get rate => totalRung == 0 ? null : count / totalRung;
}

/// A range's figures set against the equally-long range immediately before
/// it, so each stat tile can carry a direction as well as a number.
class StatsComparison {
  const StatsComparison({
    required this.current,
    required this.previous,
    required this.previousRange,
  });

  final ShopStats current;
  final ShopStats previous;
  final StatsDateRange previousRange;

  double? get revenueChange =>
      percentChange(previous.totalRevenue, current.totalRevenue);

  double? get netProfitChange =>
      percentChange(previous.netProfit, current.netProfit);

  double? get expensesChange =>
      percentChange(previous.totalExpenses, current.totalExpenses);

  double? get salesCountChange =>
      percentChange(previous.salesCount.toDouble(), current.salesCount.toDouble());

  double? get averageOrderValueChange {
    final before = previous.averageOrderValue;
    final now = current.averageOrderValue;
    if (before == null || now == null) return null;
    return percentChange(before, now);
  }
}
