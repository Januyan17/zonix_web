import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/models/platform_stats.dart';
import 'package:zonixweb/models/shop_stats.dart';

/// The platform-wide figures derived on top of the health load and the
/// volume scan: the liveness census, and the concentration/averages that
/// say whether the revenue total is broad or is two shops.
ShopHealth _shop({required String slug, DateTime? lastSaleAt}) => ShopHealth(
  slug: slug,
  name: slug,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  staffCount: 0,
  enabledUserCount: 0,
  productCount: 0,
  staffLimit: null,
  productLimit: null,
  lastSaleAt: lastSaleAt,
  devicesByBuild: const {},
  usersWithoutBuild: 0,
  shopLinksEnabled: false,
  staffDeleteEnabled: false,
  maxActiveDevicesStaff: 1,
);

ShopVolume _volume(String slug, double revenue, {int sales = 1, double cogs = 0}) =>
    ShopVolume(
      slug: slug,
      name: slug,
      stats: ShopStats(
        salesCount: sales,
        totalRevenue: revenue,
        totalCogs: cogs,
        totalExpenses: 0,
        totalAdditionalIncome: 0,
        productCount: 0,
      ),
    );

PlatformVolume _platformVolume(List<ShopVolume> shops) => PlatformVolume(
  // Sorted revenue-first, as the service produces it — topShopsShare reads
  // it as a prefix.
  shops: [...shops]
    ..sort((a, b) => b.stats.totalRevenue.compareTo(a.stats.totalRevenue)),
  series: const [],
  range: StatsDateRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 7)),
  computedAt: DateTime(2026, 8, 7),
);

void main() {
  group('PlatformHealth.activityMix', () {
    final now = DateTime(2026, 8, 20);

    test('grades every shop by how recently it sold', () {
      final health = PlatformHealth(
        shops: [
          _shop(slug: 'live', lastSaleAt: now.subtract(const Duration(days: 1))),
          _shop(slug: 'quiet', lastSaleAt: now.subtract(const Duration(days: 8))),
          _shop(
            slug: 'dormant',
            lastSaleAt: now.subtract(const Duration(days: 40)),
          ),
          _shop(slug: 'never'),
        ],
        growth: const [],
        features: const FeatureAdoption(
          totalShops: 4,
          shopLinksEnabled: 0,
          staffDeleteEnabled: 0,
          staffLimitSet: 0,
          productLimitSet: 0,
          multiDeviceStaff: 0,
        ),
        builds: const BuildAdoption(devicesByBuild: {}, usersWithoutBuild: 0),
        loadedAt: now,
      );

      final mix = health.activityMix(now: now);
      expect(mix.live, 1);
      expect(mix.quiet, 1);
      expect(mix.dormant, 1);
      expect(mix.neverSold, 1);
      // A census, not a worklist: unlike stale(), nothing is held back by
      // the new-shop grace period.
      expect(mix.total, health.totalShops);
    });
  });

  group('PlatformVolume derived figures', () {
    test('averages, median and concentration', () {
      final volume = _platformVolume([
        _volume('a', 1000, sales: 5),
        _volume('b', 200, sales: 5),
        _volume('c', 100, sales: 10),
        // Never sold: excluded from the per-shop averages, which measure
        // the shops that actually trade.
        _volume('d', 0, sales: 0),
      ]);

      expect(volume.totalRevenue, 1300);
      expect(volume.sellingShopCount, 3);
      expect(volume.averageOrderValue, closeTo(1300 / 20, 1e-9));
      expect(volume.averageRevenuePerSellingShop, closeTo(1300 / 3, 1e-9));
      expect(volume.medianRevenuePerSellingShop, 200);
      // One shop is 1000/1300 of everything.
      expect(volume.topShopsShare(1), closeTo(1000 / 1300, 1e-9));
      // Asking for more shops than exist is the whole platform, not a crash.
      expect(volume.topShopsShare(50), 1);
    });

    test('an even number of selling shops medians the middle two', () {
      final volume = _platformVolume([
        _volume('a', 400),
        _volume('b', 300),
        _volume('c', 100),
        _volume('d', 50),
      ]);
      expect(volume.medianRevenuePerSellingShop, 200);
    });

    test('gross margin nets off cost of goods', () {
      final volume = _platformVolume([
        _volume('a', 1000, cogs: 400),
        _volume('b', 1000, cogs: 200),
      ]);
      expect(volume.grossMargin, closeTo(0.7, 1e-9));
    });

    test('a platform with no revenue reports nothing rather than zero', () {
      final volume = _platformVolume([_volume('a', 0, sales: 0)]);
      expect(volume.averageOrderValue, isNull);
      expect(volume.averageRevenuePerSellingShop, isNull);
      expect(volume.medianRevenuePerSellingShop, isNull);
      expect(volume.topShopsShare(5), isNull);
      expect(volume.grossMargin, isNull);
    });
  });

  group('PlatformHealth.signupGrowthRate', () {
    PlatformHealth healthWith(List<ShopGrowthPoint> growth) => PlatformHealth(
      shops: const [],
      growth: growth,
      features: const FeatureAdoption(
        totalShops: 0,
        shopLinksEnabled: 0,
        staffDeleteEnabled: 0,
        staffLimitSet: 0,
        productLimitSet: 0,
        multiDeviceStaff: 0,
      ),
      builds: const BuildAdoption(devicesByBuild: {}, usersWithoutBuild: 0),
      loadedAt: DateTime(2026, 8, 20),
    );

    ShopGrowthPoint point(int month, int newShops) => ShopGrowthPoint(
      month: DateTime(2026, month),
      newShops: newShops,
      cumulative: newShops,
    );

    test('compares this month with last', () {
      expect(
        healthWith([point(7, 4), point(8, 6)]).signupGrowthRate,
        closeTo(0.5, 1e-9),
      );
    });

    test('growth from a month with no signups is undefined', () {
      expect(healthWith([point(7, 0), point(8, 6)]).signupGrowthRate, isNull);
      expect(healthWith([point(8, 6)]).signupGrowthRate, isNull);
    });
  });
}
