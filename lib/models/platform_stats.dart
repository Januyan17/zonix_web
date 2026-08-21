import 'shop_stats.dart';

/// How recently a shop has rung up a sale. A POS shop that stops selling is
/// the earliest visible sign of churn, so this is graded rather than a
/// boolean.
enum ShopActivity {
  /// Sold within the last [ShopActivityThresholds.quietDays] days.
  live,

  /// No sale for a week or more, but under a month.
  quiet,

  /// No sale for a month or more.
  dormant,

  /// Never recorded a sale at all — a shop that was created but never
  /// onboarded, which is a different problem from one that went quiet.
  neverSold,
}

class ShopActivityThresholds {
  ShopActivityThresholds._();

  static const quietDays = 7;
  static const dormantDays = 30;
}

/// One month's worth of shop signups.
class ShopGrowthPoint {
  const ShopGrowthPoint({
    required this.month,
    required this.newShops,
    required this.cumulative,
  });

  /// First day of the month this point covers.
  final DateTime month;

  final int newShops;

  /// Total shops in existence at the end of this month, including those
  /// created before the charted window.
  final int cumulative;
}

/// Everything the overview page knows about one shop, gathered from its
/// document plus small reads of its users, products, and most recent sale.
class ShopHealth {
  const ShopHealth({
    required this.slug,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.staffCount,
    required this.enabledUserCount,
    required this.productCount,
    required this.staffLimit,
    required this.productLimit,
    required this.lastSaleAt,
    required this.devicesByBuild,
    required this.usersWithoutBuild,
    required this.shopLinksEnabled,
    required this.staffDeleteEnabled,
    required this.maxActiveDevicesStaff,
  });

  final String slug;
  final String name;
  final bool isActive;
  final DateTime? createdAt;

  /// Non-deleted users with role 'staff'. Excludes the owner, matching what
  /// the shop's staff limit actually caps.
  final int staffCount;

  final int enabledUserCount;
  final int productCount;
  final int? staffLimit;
  final int? productLimit;
  final DateTime? lastSaleAt;

  /// Build number reported by each user document, counted. Empty until the
  /// mobile app starts writing its build number onto the user doc it
  /// already syncs.
  final Map<int, int> devicesByBuild;

  final int usersWithoutBuild;

  final bool shopLinksEnabled;
  final bool staffDeleteEnabled;
  final int maxActiveDevicesStaff;

  int? daysSinceLastSale({DateTime? now}) {
    final last = lastSaleAt;
    if (last == null) return null;
    return (now ?? DateTime.now()).difference(last).inDays;
  }

  ShopActivity activity({DateTime? now}) {
    final days = daysSinceLastSale(now: now);
    if (days == null) return ShopActivity.neverSold;
    if (days >= ShopActivityThresholds.dormantDays) return ShopActivity.dormant;
    if (days >= ShopActivityThresholds.quietDays) return ShopActivity.quiet;
    return ShopActivity.live;
  }

  /// Fraction of the staff limit in use, or null when unlimited. Can exceed
  /// 1.0: a limit lowered below the current headcount doesn't retroactively
  /// remove anyone.
  double? get staffUtilization {
    final limit = staffLimit;
    if (limit == null || limit == 0) return null;
    return staffCount / limit;
  }

  double? get productUtilization {
    final limit = productLimit;
    if (limit == null || limit == 0) return null;
    return productCount / limit;
  }

  /// Whether this shop belongs on the churn-risk list.
  ///
  /// A shop that has never sold gets a grace period equal to the quiet
  /// threshold: one created yesterday has not had a chance to ring anything
  /// up, and counting it as churn risk would bury the shops that genuinely
  /// stalled after trading normally.
  bool needsAttention({DateTime? now}) {
    final at = now ?? DateTime.now();
    final state = activity(now: at);
    if (state == ShopActivity.live) return false;
    if (state == ShopActivity.neverSold) {
      final created = createdAt;
      if (created == null) return true;
      return at.difference(created).inDays >= ShopActivityThresholds.quietDays;
    }
    return true;
  }

  /// Near enough to a cap to be worth a conversation before the owner hits
  /// it mid-shift.
  bool get isNearAnyLimit {
    const threshold = 0.8;
    final staff = staffUtilization;
    final product = productUtilization;
    return (staff != null && staff >= threshold) ||
        (product != null && product >= threshold);
  }
}

/// How many shops have each optional feature turned on.
class FeatureAdoption {
  const FeatureAdoption({
    required this.totalShops,
    required this.shopLinksEnabled,
    required this.staffDeleteEnabled,
    required this.staffLimitSet,
    required this.productLimitSet,
    required this.multiDeviceStaff,
  });

  final int totalShops;
  final int shopLinksEnabled;
  final int staffDeleteEnabled;
  final int staffLimitSet;
  final int productLimitSet;

  /// Shops allowing staff more than one concurrent device.
  final int multiDeviceStaff;
}

/// Which build each reporting device is on, and how that lands against the
/// currently published update gate.
class BuildAdoption {
  const BuildAdoption({
    required this.devicesByBuild,
    required this.usersWithoutBuild,
  });

  /// Build number to device count, across every shop.
  final Map<int, int> devicesByBuild;

  /// User documents that report no build number at all. Before the mobile
  /// app starts writing one this is every user, which is why the page says
  /// so rather than rendering an empty chart.
  final int usersWithoutBuild;

  bool get hasData => devicesByBuild.isNotEmpty;

  int get reportingDevices =>
      devicesByBuild.values.fold(0, (sum, count) => sum + count);

  /// Builds newest-first, so the current release leads the list.
  List<int> get buildsDescending {
    final builds = devicesByBuild.keys.toList()..sort((a, b) => b.compareTo(a));
    return builds;
  }

  /// Devices that a floor of [minSupportedBuild] would hard-block right now.
  int blockedBy(int minSupportedBuild) {
    var blocked = 0;
    devicesByBuild.forEach((build, count) {
      if (build < minSupportedBuild) blocked += count;
    });
    return blocked;
  }
}

/// One shop's contribution to platform volume, from the on-demand scan.
class ShopVolume {
  const ShopVolume({
    required this.slug,
    required this.name,
    required this.stats,
  });

  final String slug;
  final String name;
  final ShopStats stats;
}

/// The result of the on-demand volume scan across every shop.
class PlatformVolume {
  const PlatformVolume({
    required this.shops,
    required this.series,
    required this.range,
    required this.computedAt,
  });

  /// Sorted by revenue, highest first.
  final List<ShopVolume> shops;

  /// Revenue and expenses per day, summed across every shop.
  final List<DailyStat> series;

  final StatsDateRange range;
  final DateTime computedAt;

  double get totalRevenue =>
      shops.fold(0, (sum, s) => sum + s.stats.totalRevenue);

  double get totalNetProfit =>
      shops.fold(0, (sum, s) => sum + s.stats.netProfit);

  int get totalSalesCount =>
      shops.fold(0, (sum, s) => sum + s.stats.salesCount);

  int get sellingShopCount =>
      shops.where((s) => s.stats.salesCount > 0).length;
}

/// Everything the overview page loads on entry.
class PlatformHealth {
  const PlatformHealth({
    required this.shops,
    required this.growth,
    required this.features,
    required this.builds,
    required this.loadedAt,
  });

  final List<ShopHealth> shops;
  final List<ShopGrowthPoint> growth;
  final FeatureAdoption features;
  final BuildAdoption builds;
  final DateTime loadedAt;

  int get totalShops => shops.length;
  int get activeShops => shops.where((s) => s.isActive).length;
  int get inactiveShops => shops.where((s) => !s.isActive).length;

  /// Shops that have gone quiet or worse — the churn-risk list. Excludes
  /// brand-new shops still inside their grace period.
  List<ShopHealth> stale({DateTime? now}) {
    final at = now ?? DateTime.now();
    return shops.where((s) => s.needsAttention(now: at)).toList();
  }

  List<ShopHealth> get nearLimit =>
      shops.where((s) => s.isNearAnyLimit).toList();
}
