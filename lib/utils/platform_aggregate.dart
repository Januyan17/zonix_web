/// Pure aggregation behind the platform overview page. Kept free of
/// Firestore types so the arithmetic that drives churn-risk and revenue
/// figures can be tested directly on plain maps.
library;

import '../models/platform_stats.dart';
import '../models/shop_stats.dart';

/// Buckets shop signup dates into the last [months] calendar months,
/// including months with no signups so the bar chart keeps an even time
/// axis. [cumulative] counts every shop in existence at the end of each
/// month, including those created before the window starts.
List<ShopGrowthPoint> buildGrowthSeries(
  List<DateTime> createdAts, {
  int months = 12,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final firstMonth = DateTime(at.year, at.month - (months - 1));

  final counts = List<int>.filled(months, 0);
  var priorToWindow = 0;

  for (final createdAt in createdAts) {
    final month = DateTime(createdAt.year, createdAt.month);
    if (month.isBefore(firstMonth)) {
      priorToWindow++;
      continue;
    }
    final index =
        (month.year - firstMonth.year) * 12 + (month.month - firstMonth.month);
    if (index < 0 || index >= months) continue;
    counts[index]++;
  }

  var running = priorToWindow;
  return List.generate(months, (i) {
    running += counts[i];
    return ShopGrowthPoint(
      month: DateTime(firstMonth.year, firstMonth.month + i),
      newShops: counts[i],
      cumulative: running,
    );
  });
}

/// The build number a user document reports, or null when it reports none.
/// The mobile app that writes these documents isn't part of this repo, so
/// the field name is read across the plausible spellings rather than
/// assumed — matching how ShopTransaction reads its label field.
int? readBuildNumber(Map<String, dynamic> userData) {
  const keys = [
    'app_build',
    'appBuild',
    'build_number',
    'buildNumber',
    'app_build_number',
  ];
  for (final key in keys) {
    final value = userData[key];
    if (value is num) return value.toInt();
    // A build number stored as a string is still a build number, but a
    // dotted version string is not — "1.0.3" must never be coerced.
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

/// Merges every shop's per-build device counts into one platform-wide view.
BuildAdoption mergeBuildAdoption(List<ShopHealth> shops) {
  final merged = <int, int>{};
  var withoutBuild = 0;
  for (final shop in shops) {
    withoutBuild += shop.usersWithoutBuild;
    shop.devicesByBuild.forEach((build, count) {
      merged[build] = (merged[build] ?? 0) + count;
    });
  }
  return BuildAdoption(
    devicesByBuild: merged,
    usersWithoutBuild: withoutBuild,
  );
}

/// Totals plus a per-day series from a single pass over one shop's
/// transaction collections.
class ShopVolumeResult {
  const ShopVolumeResult({required this.stats, required this.series});

  final ShopStats stats;
  final List<DailyStat> series;
}

/// Aggregates one shop's raw transaction documents into both totals and a
/// daily series in a single pass.
///
/// This deliberately mirrors the field semantics ShopService.getShopStats
/// and getDailySeries already use — soft-deleted docs skipped, `total` on
/// sales and `amount` elsewhere, COGS as unit_cost x quantity over `items`,
/// and a range inclusive of both end days. It exists so the platform scan
/// reads each shop's sales collection once instead of twice; the per-shop
/// page still uses the original methods.
ShopVolumeResult aggregateShopVolume({
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> expenses,
  required List<Map<String, dynamic>> additionalIncome,
  required int productCount,
  required DateTime start,
  required DateTime end,
}) {
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final dayCount = endDay.difference(startDay).inDays + 1;

  final revenueByDay = List<double>.filled(dayCount, 0);
  final expensesByDay = List<double>.filled(dayCount, 0);

  int? dayIndex(Map<String, dynamic> data) {
    final raw = data['created_at'] as String?;
    if (raw == null) return null;
    final createdAt = DateTime.tryParse(raw);
    if (createdAt == null) return null;
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final index = day.difference(startDay).inDays;
    if (index < 0 || index >= dayCount) return null;
    return index;
  }

  var salesCount = 0;
  var totalRevenue = 0.0;
  var totalCogs = 0.0;
  var totalExpenses = 0.0;
  var totalIncome = 0.0;

  for (final data in sales) {
    if (data['is_deleted'] == true) continue;
    final index = dayIndex(data);
    if (index == null) continue;
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    salesCount++;
    totalRevenue += total;
    revenueByDay[index] += total;

    final items = data['items'] as List<dynamic>? ?? const [];
    for (final item in items) {
      if (item is! Map) continue;
      final unitCost = (item['unit_cost'] as num?)?.toDouble() ?? 0;
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
      totalCogs += unitCost * quantity;
    }
  }

  for (final data in expenses) {
    if (data['is_deleted'] == true) continue;
    final index = dayIndex(data);
    if (index == null) continue;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    totalExpenses += amount;
    expensesByDay[index] += amount;
  }

  for (final data in additionalIncome) {
    if (data['is_deleted'] == true) continue;
    if (dayIndex(data) == null) continue;
    totalIncome += (data['amount'] as num?)?.toDouble() ?? 0;
  }

  return ShopVolumeResult(
    stats: ShopStats(
      salesCount: salesCount,
      totalRevenue: totalRevenue,
      totalCogs: totalCogs,
      totalExpenses: totalExpenses,
      totalAdditionalIncome: totalIncome,
      productCount: productCount,
    ),
    series: List.generate(
      dayCount,
      (i) => DailyStat(
        day: startDay.add(Duration(days: i)),
        revenue: revenueByDay[i],
        expenses: expensesByDay[i],
      ),
    ),
  );
}

/// Sums per-shop daily series into one platform-wide series. Every shop's
/// series covers the same range, so the days line up index for index.
List<DailyStat> sumDailySeries(List<List<DailyStat>> perShop) {
  if (perShop.isEmpty) return const [];
  final length = perShop.first.length;
  final revenue = List<double>.filled(length, 0);
  final expenses = List<double>.filled(length, 0);

  for (final series in perShop) {
    if (series.length != length) continue;
    for (var i = 0; i < length; i++) {
      revenue[i] += series[i].revenue;
      expenses[i] += series[i].expenses;
    }
  }

  return List.generate(
    length,
    (i) => DailyStat(
      day: perShop.first[i].day,
      revenue: revenue[i],
      expenses: expenses[i],
    ),
  );
}
