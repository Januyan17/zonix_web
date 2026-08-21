import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/models/platform_stats.dart';
import 'package:zonixweb/utils/platform_aggregate.dart';

ShopHealth _shop({
  String slug = 's',
  DateTime? lastSaleAt,
  int staffCount = 0,
  int? staffLimit,
  int productCount = 0,
  int? productLimit,
  Map<int, int> devicesByBuild = const {},
  int usersWithoutBuild = 0,
}) {
  return ShopHealth(
    slug: slug,
    name: slug,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    staffCount: staffCount,
    enabledUserCount: 0,
    productCount: productCount,
    staffLimit: staffLimit,
    productLimit: productLimit,
    lastSaleAt: lastSaleAt,
    devicesByBuild: devicesByBuild,
    usersWithoutBuild: usersWithoutBuild,
    shopLinksEnabled: false,
    staffDeleteEnabled: false,
    maxActiveDevicesStaff: 1,
  );
}

void main() {
  group('buildGrowthSeries', () {
    final now = DateTime(2026, 8, 20);

    test('returns one point per month, including empty months', () {
      final series = buildGrowthSeries([], months: 6, now: now);
      expect(series.length, 6);
      expect(series.every((p) => p.newShops == 0), isTrue);
      expect(series.first.month, DateTime(2026, 3));
      expect(series.last.month, DateTime(2026, 8));
    });

    test('buckets signups into their month', () {
      final series = buildGrowthSeries([
        DateTime(2026, 8, 2),
        DateTime(2026, 8, 19),
        DateTime(2026, 7, 5),
      ], months: 3, now: now);

      expect(series.map((p) => p.newShops).toList(), [0, 1, 2]);
    });

    test('cumulative carries shops created before the window', () {
      final series = buildGrowthSeries([
        DateTime(2024, 1, 1),
        DateTime(2024, 5, 1),
        DateTime(2026, 8, 3),
      ], months: 3, now: now);

      // Two shops predate the window, so the running total starts at 2.
      expect(series.map((p) => p.cumulative).toList(), [2, 2, 3]);
      expect(series.last.newShops, 1);
    });

    test('crosses a year boundary without losing months', () {
      final series = buildGrowthSeries([
        DateTime(2025, 12, 10),
      ], months: 3, now: DateTime(2026, 1, 15));

      expect(series.map((p) => p.month).toList(), [
        DateTime(2025, 11),
        DateTime(2025, 12),
        DateTime(2026, 1),
      ]);
      expect(series[1].newShops, 1);
    });
  });

  group('readBuildNumber', () {
    test('reads the plausible field spellings', () {
      expect(readBuildNumber({'app_build': 5}), 5);
      expect(readBuildNumber({'appBuild': 6}), 6);
      expect(readBuildNumber({'build_number': 7}), 7);
      expect(readBuildNumber({'buildNumber': 8}), 8);
    });

    test('accepts a numeric string but never a dotted version', () {
      expect(readBuildNumber({'app_build': '9'}), 9);
      expect(readBuildNumber({'app_build': ' 10 '}), 10);
      expect(readBuildNumber({'app_build': '1.0.3'}), isNull);
    });

    test('returns null when no build field is present', () {
      expect(readBuildNumber({'role': 'staff'}), isNull);
      expect(readBuildNumber({}), isNull);
    });
  });

  group('mergeBuildAdoption', () {
    test('sums device counts per build across shops', () {
      final merged = mergeBuildAdoption([
        _shop(slug: 'a', devicesByBuild: {5: 2, 4: 1}, usersWithoutBuild: 1),
        _shop(slug: 'b', devicesByBuild: {5: 3}, usersWithoutBuild: 2),
      ]);

      expect(merged.devicesByBuild, {5: 5, 4: 1});
      expect(merged.usersWithoutBuild, 3);
      expect(merged.reportingDevices, 6);
      expect(merged.buildsDescending, [5, 4]);
      expect(merged.hasData, isTrue);
    });

    test('reports no data when nothing reports a build', () {
      final merged = mergeBuildAdoption([_shop(usersWithoutBuild: 4)]);
      expect(merged.hasData, isFalse);
      expect(merged.reportingDevices, 0);
    });

    test('blockedBy counts only devices under the floor', () {
      final merged = mergeBuildAdoption([
        _shop(devicesByBuild: {3: 1, 4: 2, 5: 6}),
      ]);
      expect(merged.blockedBy(5), 3);
      expect(merged.blockedBy(0), 0);
      expect(merged.blockedBy(6), 9);
    });
  });

  group('ShopHealth activity', () {
    final now = DateTime(2026, 8, 20);

    test('grades by days since the last sale', () {
      expect(
        _shop(lastSaleAt: DateTime(2026, 8, 20)).activity(now: now),
        ShopActivity.live,
      );
      expect(
        _shop(lastSaleAt: DateTime(2026, 8, 15)).activity(now: now),
        ShopActivity.live,
      );
      expect(
        _shop(lastSaleAt: DateTime(2026, 8, 13)).activity(now: now),
        ShopActivity.quiet,
      );
      expect(
        _shop(lastSaleAt: DateTime(2026, 7, 1)).activity(now: now),
        ShopActivity.dormant,
      );
    });

    test('a shop that never sold is its own state, not dormant', () {
      expect(_shop().activity(now: now), ShopActivity.neverSold);
      expect(_shop().daysSinceLastSale(now: now), isNull);
    });
  });

  group('ShopHealth needsAttention', () {
    final now = DateTime(2026, 8, 20);

    test('a live shop never needs attention', () {
      expect(
        _shop(lastSaleAt: DateTime(2026, 8, 19)).needsAttention(now: now),
        isFalse,
      );
    });

    test('quiet and dormant shops do', () {
      expect(
        _shop(lastSaleAt: DateTime(2026, 8, 10)).needsAttention(now: now),
        isTrue,
      );
      expect(
        _shop(lastSaleAt: DateTime(2026, 6, 1)).needsAttention(now: now),
        isTrue,
      );
    });

    test('a brand-new shop that never sold is inside its grace period', () {
      final fresh = ShopHealth(
        slug: 'fresh',
        name: 'fresh',
        isActive: true,
        createdAt: DateTime(2026, 8, 18),
        staffCount: 0,
        enabledUserCount: 0,
        productCount: 0,
        staffLimit: null,
        productLimit: null,
        lastSaleAt: null,
        devicesByBuild: const {},
        usersWithoutBuild: 0,
        shopLinksEnabled: false,
        staffDeleteEnabled: false,
        maxActiveDevicesStaff: 1,
      );
      expect(fresh.activity(now: now), ShopActivity.neverSold);
      expect(fresh.needsAttention(now: now), isFalse);
    });

    test('an old shop that never sold does need attention', () {
      final stalled = ShopHealth(
        slug: 'stalled',
        name: 'stalled',
        isActive: true,
        createdAt: DateTime(2026, 5, 1),
        staffCount: 0,
        enabledUserCount: 0,
        productCount: 0,
        staffLimit: null,
        productLimit: null,
        lastSaleAt: null,
        devicesByBuild: const {},
        usersWithoutBuild: 0,
        shopLinksEnabled: false,
        staffDeleteEnabled: false,
        maxActiveDevicesStaff: 1,
      );
      expect(stalled.needsAttention(now: now), isTrue);
    });
  });

  group('ShopHealth utilization', () {
    test('is null when the limit is unlimited', () {
      expect(_shop(staffCount: 3).staffUtilization, isNull);
      expect(_shop(productCount: 9).productUtilization, isNull);
    });

    test('can exceed 1.0 when a limit was lowered under the headcount', () {
      final shop = _shop(staffCount: 5, staffLimit: 3);
      expect(shop.staffUtilization, closeTo(1.67, 0.01));
      expect(shop.isNearAnyLimit, isTrue);
    });

    test('flags a shop at 80% of either cap', () {
      expect(_shop(staffCount: 4, staffLimit: 5).isNearAnyLimit, isTrue);
      expect(_shop(productCount: 8, productLimit: 10).isNearAnyLimit, isTrue);
      expect(_shop(staffCount: 1, staffLimit: 5).isNearAnyLimit, isFalse);
    });
  });

  group('aggregateShopVolume', () {
    final start = DateTime(2026, 8, 1);
    final end = DateTime(2026, 8, 3);

    Map<String, dynamic> sale(
      String date,
      double total, {
      bool deleted = false,
      List<Map<String, dynamic>>? items,
    }) => {
      'created_at': DateTime.parse(date).toIso8601String(),
      'total': total,
      'is_deleted': deleted,
      'items': ?items,
    };

    test('totals revenue and fills a day per calendar day', () {
      final result = aggregateShopVolume(
        sales: [sale('2026-08-01', 100), sale('2026-08-03', 50)],
        expenses: const [],
        additionalIncome: const [],
        productCount: 0,
        start: start,
        end: end,
      );

      expect(result.series.length, 3);
      expect(result.stats.totalRevenue, 150);
      expect(result.stats.salesCount, 2);
      expect(result.series.map((d) => d.revenue).toList(), [100, 0, 50]);
    });

    test('skips soft-deleted documents', () {
      final result = aggregateShopVolume(
        sales: [sale('2026-08-01', 100, deleted: true), sale('2026-08-01', 20)],
        expenses: const [],
        additionalIncome: const [],
        productCount: 0,
        start: start,
        end: end,
      );

      expect(result.stats.totalRevenue, 20);
      expect(result.stats.salesCount, 1);
    });

    test('excludes documents outside the range on both ends', () {
      final result = aggregateShopVolume(
        sales: [
          sale('2026-07-31', 999),
          sale('2026-08-02', 10),
          sale('2026-08-04', 999),
        ],
        expenses: const [],
        additionalIncome: const [],
        productCount: 0,
        start: start,
        end: end,
      );

      expect(result.stats.totalRevenue, 10);
    });

    test('computes COGS as unit_cost x quantity over items', () {
      final result = aggregateShopVolume(
        sales: [
          sale(
            '2026-08-01',
            100,
            items: [
              {'unit_cost': 10, 'quantity': 3},
              {'unit_cost': 5, 'quantity': 2},
            ],
          ),
        ],
        expenses: const [],
        additionalIncome: const [],
        productCount: 0,
        start: start,
        end: end,
      );

      expect(result.stats.totalCogs, 40);
      expect(result.stats.grossProfit, 60);
    });

    test('net profit folds in expenses and additional income', () {
      final result = aggregateShopVolume(
        sales: [sale('2026-08-01', 100)],
        expenses: [
          {'created_at': '2026-08-01T00:00:00.000', 'amount': 30},
        ],
        additionalIncome: [
          {'created_at': '2026-08-02T00:00:00.000', 'amount': 5},
        ],
        productCount: 0,
        start: start,
        end: end,
      );

      expect(result.stats.totalExpenses, 30);
      expect(result.stats.totalAdditionalIncome, 5);
      expect(result.stats.netProfit, 75);
      expect(result.series[0].expenses, 30);
    });
  });

  group('sumDailySeries', () {
    test('adds shops day by day', () {
      final a = aggregateShopVolume(
        sales: [
          {'created_at': '2026-08-01T00:00:00.000', 'total': 10},
        ],
        expenses: const [],
        additionalIncome: const [],
        productCount: 0,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 2),
      ).series;

      final b = aggregateShopVolume(
        sales: [
          {'created_at': '2026-08-02T00:00:00.000', 'total': 7},
        ],
        expenses: const [],
        additionalIncome: const [],
        productCount: 0,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 2),
      ).series;

      final summed = sumDailySeries([a, b]);
      expect(summed.map((d) => d.revenue).toList(), [10, 7]);
    });

    test('is empty for no shops', () {
      expect(sumDailySeries([]), isEmpty);
    });
  });
}
