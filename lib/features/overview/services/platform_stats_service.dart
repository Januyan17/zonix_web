import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';
import 'package:zonixweb/features/overview/utils/platform_aggregate.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_stats.dart';
import 'package:zonixweb/features/shops/utils/shop_activity_aggregate.dart';

/// Cross-shop analytics for the platform overview page.
///
/// Split into two deliberately different tiers, because their read costs
/// differ by orders of magnitude:
///
///  * [loadHealth] reads each shop's document, its users subcollection, a
///    count of its products and the few most recent sales. Small, bounded,
///    and safe to run whenever the page opens.
///  * [computeVolume] reads the sale, expense, and income documents of
///    every shop inside the requested window. That still grows with
///    activity, so it is never run automatically — the page puts it behind
///    an explicit button.
///
/// Nothing here writes. The existing ShopService is used read-only for the
/// shop index and is otherwise untouched.
class PlatformStatsService {
  PlatformStatsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// How many shops to fan out to at once. Without a bound, a platform with
  /// a few hundred shops would open hundreds of simultaneous queries on a
  /// page load and the browser would start dropping them.
  static const _concurrency = 8;

  CollectionReference<Map<String, dynamic>> get _shopIndex =>
      _firestore.collection('admin_shop_index');

  DocumentReference<Map<String, dynamic>> _shopRef(String slug) =>
      _firestore.collection('shops').doc(slug);

  /// Live (not soft-deleted) products in a shop, counted server-side. A
  /// count aggregation is billed one read per 1000 documents counted,
  /// where fetching the catalog was one read per product. Matches the old
  /// client-side `is_deleted != true` test exactly: everything minus the
  /// docs whose flag is literally true (a bare `isNotEqualTo` query would
  /// also drop docs that lack the field).
  static Future<int> _liveProductCount(
    DocumentReference<Map<String, dynamic>> shopRef,
  ) async {
    final products = shopRef.collection('products');
    final counts = await Future.wait([
      products.count().get(),
      products.where('is_deleted', isEqualTo: true).count().get(),
    ]);
    return (counts[0].count ?? 0) - (counts[1].count ?? 0);
  }

  /// Runs [task] over [items] at most [_concurrency] at a time, preserving
  /// input order in the result.
  static Future<List<R>> _mapBounded<T, R>(
    List<T> items,
    Future<R> Function(T) task,
  ) async {
    final results = <R>[];
    for (var i = 0; i < items.length; i += _concurrency) {
      final end = (i + _concurrency).clamp(0, items.length);
      results.addAll(await Future.wait(items.sublist(i, end).map(task)));
    }
    return results;
  }

  /// The shop slugs and indexed names, newest first. Read once rather than
  /// watched: an analytics page that re-fans-out on every index change
  /// would multiply its own cost.
  Future<List<({String slug, String name})>> _readIndex() async {
    final snapshot = await _shopIndex
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((d) => (slug: d.id, name: d.data()['name'] as String? ?? d.id))
        .toList();
  }

  /// Everything the overview page shows on entry. Cost per shop is one read
  /// per user plus a handful more, independent of catalog size or of how
  /// much sales history exists.
  Future<PlatformHealth> loadHealth({DateTime? now}) async {
    final index = await _readIndex();
    final shops = await _mapBounded(index, (entry) => _loadShopHealth(entry));
    final present = shops.whereType<ShopHealth>().toList();

    return PlatformHealth(
      shops: present,
      growth: buildGrowthSeries(
        present.map((s) => s.createdAt).whereType<DateTime>().toList(),
        now: now,
      ),
      features: _summarizeFeatures(present),
      builds: mergeBuildAdoption(present),
      loadedAt: now ?? DateTime.now(),
    );
  }

  Future<ShopHealth?> _loadShopHealth(
    ({String slug, String name}) entry,
  ) async {
    final ref = _shopRef(entry.slug);
    final results = await Future.wait([
      ref.get(),
      ref.collection('users').get(),
      _liveProductCount(ref),
      // Only the newest few sales, not the collection. A soft-deleted sale
      // could be the newest, so take a small window and pick the first
      // that survives rather than a bare limit(1).
      ref
          .collection('sales')
          .orderBy('created_at', descending: true)
          .limit(5)
          .get(),
    ]);

    final shopDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    if (!shopDoc.exists) return null;
    final shop = Shop.fromMap(shopDoc.data()!);

    final userDocs = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs;
    final productCount = results[2] as int;
    final saleDocs = (results[3] as QuerySnapshot<Map<String, dynamic>>).docs;

    var staffCount = 0;
    var enabledCount = 0;
    var usersWithoutBuild = 0;
    final devicesByBuild = <int, int>{};

    for (final doc in userDocs) {
      final data = doc.data();
      if (data['is_deleted'] == true) continue;
      if (data['role'] == 'staff') staffCount++;
      if (data['is_enabled'] == true) enabledCount++;

      final build = readBuildNumber(data);
      if (build == null) {
        usersWithoutBuild++;
      } else {
        devicesByBuild[build] = (devicesByBuild[build] ?? 0) + 1;
      }
    }

    DateTime? lastSaleAt;
    for (final doc in saleDocs) {
      final data = doc.data();
      if (data['is_deleted'] == true) continue;
      lastSaleAt = DateTime.tryParse(data['created_at'] as String? ?? '');
      if (lastSaleAt != null) break;
    }

    return ShopHealth(
      slug: entry.slug,
      name: shop.name,
      isActive: shop.isActive,
      createdAt: DateTime.tryParse(shop.createdAt),
      staffCount: staffCount,
      enabledUserCount: enabledCount,
      productCount: productCount,
      staffLimit: shop.staffLimit,
      productLimit: shop.productLimit,
      lastSaleAt: lastSaleAt,
      devicesByBuild: devicesByBuild,
      usersWithoutBuild: usersWithoutBuild,
      shopLinksEnabled: shop.shopLinksEnabled,
      staffDeleteEnabled: shop.staffDeleteEnabled,
      maxActiveDevicesStaff: shop.maxActiveDevicesStaff,
    );
  }

  /// Counted from the shop records already in hand — the flags travel on
  /// ShopHealth precisely so this needs no second read of the documents.
  FeatureAdoption _summarizeFeatures(List<ShopHealth> shops) {
    return FeatureAdoption(
      totalShops: shops.length,
      shopLinksEnabled: shops.where((s) => s.shopLinksEnabled).length,
      staffDeleteEnabled: shops.where((s) => s.staffDeleteEnabled).length,
      staffLimitSet: shops.where((s) => s.staffLimit != null).length,
      productLimitSet: shops.where((s) => s.productLimit != null).length,
      multiDeviceStaff: shops.where((s) => s.maxActiveDevicesStaff > 1).length,
    );
  }

  /// The expensive tier: every transaction document of every shop within
  /// [range], in one pass per shop. Only ever called from an explicit user
  /// action.
  ///
  /// The queries are bounded with [activityQueryBounds] — the same coarse,
  /// day-of-slack window the shop detail page uses — so history outside
  /// the range never crosses the network. [aggregateShopVolume] still
  /// filters to the exact days, so the figures are unchanged.
  Future<PlatformVolume> computeVolume({
    required StatsDateRange range,
    void Function(int done, int total)? onProgress,
  }) async {
    final index = await _readIndex();
    final bounds = activityQueryBounds(from: range.start, to: range.end);
    var done = 0;

    final results = await _mapBounded(index, (entry) async {
      final ref = _shopRef(entry.slug);

      Future<QuerySnapshot<Map<String, dynamic>>> scoped(String collection) {
        return ref
            .collection(collection)
            .where('created_at', isGreaterThanOrEqualTo: bounds.startAt)
            .where('created_at', isLessThan: bounds.endBefore)
            .get();
      }

      final snapshots = await Future.wait([
        scoped('sales'),
        scoped('expenses'),
        scoped('additional_income'),
      ]);
      final productCount = await _liveProductCount(ref);

      List<Map<String, dynamic>> data(int i) =>
          snapshots[i].docs.map((d) => d.data()).toList();

      final aggregate = aggregateShopVolume(
        sales: data(0),
        expenses: data(1),
        additionalIncome: data(2),
        productCount: productCount,
        start: range.start,
        end: range.end,
      );

      done++;
      onProgress?.call(done, index.length);

      return (
        volume: ShopVolume(
          slug: entry.slug,
          name: entry.name,
          stats: aggregate.stats,
        ),
        series: aggregate.series,
      );
    });

    final shops = results.map((r) => r.volume).toList()
      ..sort((a, b) => b.stats.totalRevenue.compareTo(a.stats.totalRevenue));

    return PlatformVolume(
      shops: shops,
      series: sumDailySeries(results.map((r) => r.series).toList()),
      range: range,
      computedAt: DateTime.now(),
    );
  }
}
