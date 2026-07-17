import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../models/shop_stats.dart';
import '../models/shop_transaction.dart';
import '../models/shop_user.dart';

class ShopCodeTakenException implements Exception {
  const ShopCodeTakenException();
}

class ShopCreationResult {
  const ShopCreationResult({
    required this.slug,
    required this.ownerUsername,
    required this.ownerPassword,
  });

  final String slug;
  final String ownerUsername;
  final String ownerPassword;
}

class ReissueLoginResult {
  const ReissueLoginResult({required this.username, required this.password});

  final String username;
  final String password;
}

class ShopService {
  ShopService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _shopIndex =>
      _firestore.collection('admin_shop_index');

  /// The portal's own index of shop slugs, since `shops` can't be listed
  /// by security rule. Ordered newest-first.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchShopIndex() {
    return _shopIndex
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<Shop?> getShop(String slug) async {
    final doc = await _firestore.collection('shops').doc(slug).get();
    if (!doc.exists) return null;
    return Shop.fromMap(doc.data()!);
  }

  Future<List<ShopUser>> getShopUsers(String slug) async {
    final snapshot = await _firestore
        .collection('shops')
        .doc(slug)
        .collection('users')
        .get();
    return snapshot.docs.map((d) => ShopUser.fromMap(d.data())).toList();
  }

  /// Active (non-deleted) products for a shop, sorted alphabetically by
  /// name for a stable, predictable display order.
  Future<List<Product>> getShopProducts(String slug) async {
    final snapshot = await _firestore
        .collection('shops')
        .doc(slug)
        .collection('products')
        .get();
    final products = snapshot.docs
        .map((d) => Product.fromMap(d.id, d.data()))
        .where((p) => !p.isDeleted)
        .toList();
    products.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return products;
  }

  /// A fresh product id, allocated client-side with no network call. Lets
  /// the caller upload the product's image (named after this id) before
  /// the Firestore doc itself is written.
  String newProductId(String slug) =>
      _firestore.collection('shops').doc(slug).collection('products').doc().id;

  /// Creates a product in the shop's catalog. [id] is pre-allocated by the
  /// caller (rather than using .add()) so the same id can be used to name
  /// the uploaded image in Supabase Storage before this write happens.
  Future<void> addProduct({
    required String slug,
    required String id,
    required String name,
    String? description,
    String? category,
    String? sku,
    double? price,
    double? cost,
    int? stock,
    String? imageUrl,
  }) async {
    final product = Product(
      id: id,
      name: name,
      description: description,
      category: category,
      sku: sku,
      price: price,
      cost: cost,
      stock: stock,
      imageUrl: imageUrl,
      isDeleted: false,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _firestore
        .collection('shops')
        .doc(slug)
        .collection('products')
        .doc(id)
        .set(product.toMap());
  }

  Future<void> updateProduct({
    required String slug,
    required String id,
    required String name,
    String? description,
    String? category,
    String? sku,
    double? price,
    double? cost,
    int? stock,
    String? imageUrl,
  }) async {
    await _firestore
        .collection('shops')
        .doc(slug)
        .collection('products')
        .doc(id)
        .update({
          'name': name,
          'description': description,
          'category': category,
          'sku': sku,
          'price': price,
          'cost': cost,
          'stock': stock,
          'image_url': imageUrl,
        });
  }

  Future<void> deleteProduct({required String slug, required String id}) async {
    await _firestore
        .collection('shops')
        .doc(slug)
        .collection('products')
        .doc(id)
        .delete();
  }

  Future<void> setShopActive(String slug, bool isActive) async {
    await _firestore.collection('shops').doc(slug).update({
      'is_active': isActive,
    });
  }

  /// [limit] null means unlimited. Enforcement of this cap happens in the
  /// mobile app when an owner creates staff — this just stores the value;
  /// see the shop detail screen for the count of staff currently in use
  /// against it.
  Future<void> setStaffLimit(String slug, int? limit) async {
    await _firestore.collection('shops').doc(slug).update({
      'staff_limit': limit,
    });
  }

  /// [limit] null means unlimited. Enforcement of this cap happens in the
  /// mobile app when an owner creates a product — this just stores the
  /// value; see the shop detail screen for the count of products currently
  /// in use against it.
  Future<void> setProductLimit(String slug, int? limit) async {
    await _firestore.collection('shops').doc(slug).update({
      'product_limit': limit,
    });
  }

  /// [range] filters sales/expenses/income by their created_at date
  /// (inclusive of both ends); product count is always all-time since it's
  /// a catalog size, not an activity metric. Filtering happens client-side
  /// after fetching, since created_at is stored as an ISO8601 string rather
  /// than a Firestore Timestamp, which keeps this immune to any timezone
  /// mismatch between how the mobile app serializes dates and how a
  /// server-side range query would need to bound them.
  Future<ShopStats> getShopStats(String slug, {StatsDateRange? range}) async {
    final shopRef = _firestore.collection('shops').doc(slug);
    final results = await Future.wait([
      shopRef.collection('sales').get(),
      shopRef.collection('expenses').get(),
      shopRef.collection('additional_income').get(),
      shopRef.collection('products').get(),
    ]);

    bool inRange(Map<String, dynamic> data) {
      if (range == null) return true;
      final raw = data['created_at'] as String?;
      final createdAt = raw == null ? null : DateTime.tryParse(raw);
      if (createdAt == null) return false;
      final endExclusive = range.end.add(const Duration(days: 1));
      return !createdAt.isBefore(range.start) &&
          createdAt.isBefore(endExclusive);
    }

    double sumField(
      QuerySnapshot<Map<String, dynamic>> snapshot,
      String field,
    ) {
      var total = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['is_deleted'] == true) continue;
        if (!inRange(data)) continue;
        total += (data[field] as num?)?.toDouble() ?? 0;
      }
      return total;
    }

    int countActiveInRange(QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        return data['is_deleted'] != true && inRange(data);
      }).length;
    }

    int countActive(QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['is_deleted'] != true)
          .length;
    }

    double sumCogs(QuerySnapshot<Map<String, dynamic>> snapshot) {
      var total = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['is_deleted'] == true) continue;
        if (!inRange(data)) continue;
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

    final salesSnapshot = results[0];
    final expensesSnapshot = results[1];
    final incomeSnapshot = results[2];
    final productsSnapshot = results[3];

    return ShopStats(
      salesCount: countActiveInRange(salesSnapshot),
      totalRevenue: sumField(salesSnapshot, 'total'),
      totalCogs: sumCogs(salesSnapshot),
      totalExpenses: sumField(expensesSnapshot, 'amount'),
      totalAdditionalIncome: sumField(incomeSnapshot, 'amount'),
      productCount: countActive(productsSnapshot),
    );
  }

  /// The itemized activity behind [getShopStats]'s totals: every sale,
  /// expense, and additional-income entry in [range] (inclusive of both
  /// ends, same semantics as getShopStats), newest first. [range] null
  /// means all-time.
  Future<List<ShopTransaction>> getShopTransactions(
    String slug, {
    StatsDateRange? range,
  }) async {
    final shopRef = _firestore.collection('shops').doc(slug);
    final results = await Future.wait([
      shopRef.collection('sales').get(),
      shopRef.collection('expenses').get(),
      shopRef.collection('additional_income').get(),
    ]);

    bool inRange(Map<String, dynamic> data) {
      if (range == null) return true;
      final raw = data['created_at'] as String?;
      final createdAt = raw == null ? null : DateTime.tryParse(raw);
      if (createdAt == null) return false;
      final endExclusive = range.end.add(const Duration(days: 1));
      return !createdAt.isBefore(range.start) &&
          createdAt.isBefore(endExclusive);
    }

    List<ShopTransaction> mapDocs(
      QuerySnapshot<Map<String, dynamic>> snapshot,
      ShopTransactionType type,
    ) {
      return snapshot.docs
          .map((doc) => (doc.id, doc.data()))
          .where((entry) => entry.$2['is_deleted'] != true && inRange(entry.$2))
          .map((entry) => ShopTransaction.fromMap(entry.$1, type, entry.$2))
          .toList();
    }

    final transactions = [
      ...mapDocs(results[0], ShopTransactionType.sale),
      ...mapDocs(results[1], ShopTransactionType.expense),
      ...mapDocs(results[2], ShopTransactionType.income),
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
  Future<List<DailyStat>> getDailySeries(
    String slug, {
    required DateTime start,
    required DateTime end,
  }) async {
    final shopRef = _firestore.collection('shops').doc(slug);
    final results = await Future.wait([
      shopRef.collection('sales').get(),
      shopRef.collection('expenses').get(),
    ]);
    final salesSnapshot = results[0];
    final expensesSnapshot = results[1];

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

    for (final doc in salesSnapshot.docs) {
      final data = doc.data();
      if (data['is_deleted'] == true) continue;
      final index = dayIndex(data['created_at'] as String?);
      if (index == null) continue;
      revenueByDay[index] += (data['total'] as num?)?.toDouble() ?? 0;
    }
    for (final doc in expensesSnapshot.docs) {
      final data = doc.data();
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

  Future<ShopCreationResult> createShop({
    required String slug,
    required String shopName,
    required String ownerDisplayName,
    required String ownerUsername,
    required String ownerPassword,
  }) async {
    final existing = await _firestore.collection('shops').doc(slug).get();
    if (existing.exists) {
      throw const ShopCodeTakenException();
    }

    final email = '$ownerUsername@$slug.zonix.local';

    final secondaryApp = await Firebase.initializeApp(
      name: 'ownerCreation_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    late final String ownerUid;
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: ownerPassword,
      );
      ownerUid = credential.user!.uid;
      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();

    final shop = Shop(
      id: slug,
      name: shopName,
      slug: slug,
      isActive: true,
      ownerUid: ownerUid,
      createdAt: nowIso,
      staffLimit: 1,
      productLimit: 10,
    );

    final ownerUser = ShopUser(
      id: ownerUid,
      username: ownerUsername,
      displayName: ownerDisplayName,
      email: email,
      role: 'owner',
      isEnabled: true,
      createdAt: nowIso,
      updatedAt: nowIso,
      isDeleted: false,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('shops').doc(slug), shop.toMap());
    batch.set(
      _firestore
          .collection('shops')
          .doc(slug)
          .collection('users')
          .doc(ownerUid),
      ownerUser.toMap(),
    );
    batch.set(_shopIndex.doc(slug), {'name': shopName, 'createdAt': nowIso});
    await batch.commit();

    return ShopCreationResult(
      slug: slug,
      ownerUsername: ownerUsername,
      ownerPassword: ownerPassword,
    );
  }

  /// Adds a new owner or staff member to an existing shop: creates their
  /// Auth account on a throwaway secondary app (so it doesn't disturb the
  /// admin's own session) and writes their shops/{slug}/users/{uid} doc.
  /// If role is 'owner', also updates shops/{slug}.owner_uid to point at
  /// them — informational only, since isOwner() checks the role field on
  /// the caller's own membership doc, not this pointer.
  Future<ReissueLoginResult> addShopUser({
    required String slug,
    required String role,
    required String displayName,
    required String username,
    required String password,
  }) async {
    final email = '$username@$slug.zonix.local';

    final secondaryApp = await Firebase.initializeApp(
      name: 'addUser_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    late final String uid;
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      uid = credential.user!.uid;
      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final newUser = ShopUser(
      id: uid,
      username: username,
      displayName: displayName,
      email: email,
      role: role,
      isEnabled: true,
      createdAt: nowIso,
      updatedAt: nowIso,
      isDeleted: false,
    );

    final shopRef = _firestore.collection('shops').doc(slug);
    final batch = _firestore.batch();
    batch.set(shopRef.collection('users').doc(uid), newUser.toMap());
    if (role == 'owner') {
      batch.update(shopRef, {'owner_uid': uid});
    }
    await batch.commit();

    return ReissueLoginResult(username: username, password: password);
  }

  /// Updates an existing owner/staff member's profile fields. Username,
  /// email, and password aren't editable here — changing login credentials
  /// goes through [reissueLogin] instead, since Firebase Auth doesn't allow
  /// changing another user's password or email from the client SDK.
  Future<void> updateShopUser({
    required String slug,
    required String uid,
    required String displayName,
    required String role,
    required bool isEnabled,
  }) async {
    final shopRef = _firestore.collection('shops').doc(slug);
    final batch = _firestore.batch();
    batch.update(shopRef.collection('users').doc(uid), {
      'display_name': displayName,
      'role': role,
      'is_enabled': isEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (role == 'owner') {
      batch.update(shopRef, {'owner_uid': uid});
    }
    await batch.commit();
  }

  /// Removes a shop member's Firestore record, immediately cutting off
  /// their shop access (isMember/isOwner check this doc). Their Firebase
  /// Auth account itself can't be deleted from the client SDK for anyone
  /// but the signed-in user, so it's left behind, harmless and orphaned.
  Future<void> deleteShopUser({
    required String slug,
    required String uid,
  }) async {
    await _firestore
        .collection('shops')
        .doc(slug)
        .collection('users')
        .doc(uid)
        .delete();
  }

  /// Firebase Auth passwords can never be recovered or changed by anyone
  /// other than the signed-in user themself — there's no client-side "change
  /// this other user's password" API, and adding one requires the Admin SDK
  /// (a Cloud Function). Instead this retires the old login and issues a
  /// fresh one: a new Auth account + a new shops/{slug}/users/{uid} doc with
  /// the same role/displayName, and deletes the old membership doc so the
  /// old login immediately stops passing isMember/isOwner. The orphaned old
  /// Auth account is harmless — it exists but grants access to nothing.
  Future<ReissueLoginResult> reissueLogin({
    required String slug,
    required ShopUser oldUser,
    required String newUsername,
    required String newPassword,
  }) async {
    final email = '$newUsername@$slug.zonix.local';

    final secondaryApp = await Firebase.initializeApp(
      name: 'reissueLogin_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    late final String newUid;
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: newPassword,
      );
      newUid = credential.user!.uid;
      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final newUser = ShopUser(
      id: newUid,
      username: newUsername,
      displayName: oldUser.displayName,
      email: email,
      role: oldUser.role,
      isEnabled: true,
      createdAt: oldUser.createdAt,
      updatedAt: nowIso,
      isDeleted: false,
    );

    final shopRef = _firestore.collection('shops').doc(slug);
    final batch = _firestore.batch();
    batch.set(shopRef.collection('users').doc(newUid), newUser.toMap());
    batch.delete(shopRef.collection('users').doc(oldUser.id));
    if (oldUser.role == 'owner') {
      batch.update(shopRef, {'owner_uid': newUid});
    }
    await batch.commit();

    return ReissueLoginResult(username: newUsername, password: newPassword);
  }

  static const _shopSubcollections = [
    'users',
    'products',
    'sales',
    'expenses',
    'additional_income',
  ];

  /// Deletes a shop entirely: every doc in each subcollection, the shop doc
  /// itself, and the portal's index entry. Subcollection docs aren't
  /// auto-deleted by Firestore when a parent doc is removed, and the
  /// isMember/isOwner rules check those subcollection docs directly (not the
  /// parent), so leaving them behind would leave the shop fully functional
  /// for existing staff despite looking deleted in the portal.
  Future<void> deleteShop(String slug) async {
    final shopRef = _firestore.collection('shops').doc(slug);
    for (final sub in _shopSubcollections) {
      await _deleteCollectionInBatches(shopRef.collection(sub));
    }
    final batch = _firestore.batch();
    batch.delete(shopRef);
    batch.delete(_shopIndex.doc(slug));
    await batch.commit();
  }

  Future<void> _deleteCollectionInBatches(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const pageSize = 300;
    while (true) {
      final snapshot = await collection.limit(pageSize).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < pageSize) return;
    }
  }
}
