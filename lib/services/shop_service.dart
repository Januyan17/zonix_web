import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../models/shop_activity.dart';
import '../models/shop_user.dart';
import '../models/user_session.dart';
import '../utils/shop_activity_aggregate.dart';

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

  /// Currently-active login sessions for a shop user, newest first. Every
  /// doc in this subcollection represents a device that's presently logged
  /// in — there's no inactive state to filter out.
  Future<List<UserSession>> getUserSessions({
    required String slug,
    required String uid,
  }) async {
    final snapshot = await _firestore
        .collection('shops')
        .doc(slug)
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .orderBy('logged_in_at', descending: true)
        .get();
    return snapshot.docs.map((d) => UserSession.fromMap(d.data())).toList();
  }

  /// Force-logs-out a single device: the mobile app listens to its own
  /// session doc in real time and signs out immediately once it's deleted.
  Future<void> deleteUserSession({
    required String slug,
    required String uid,
    required String deviceId,
  }) async {
    await _firestore
        .collection('shops')
        .doc(slug)
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(deviceId)
        .delete();
  }

  Future<List<ShopUser>> getShopUsers(String slug) async {
    final snapshot = await _firestore
        .collection('shops')
        .doc(slug)
        .collection('users')
        .get();
    return snapshot.docs.map((d) => ShopUser.fromMap(d.data())).toList();
  }

  /// The shop's raw product catalog. Callers map it with productsFrom,
  /// which is also what turns the copy carried by [getShopActivity] into
  /// [Product]s — one code path for both, so the two can never disagree on
  /// ordering or on which products count as deleted.
  Future<List<ActivityDoc>> getProductDocs(String slug) async {
    final snapshot = await _firestore
        .collection('shops')
        .doc(slug)
        .collection('products')
        .get();
    return snapshot.docs
        .map((d) => ActivityDoc(id: d.id, data: d.data()))
        .toList();
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

  /// Controls whether the mobile/POS app shows a "Delete" option for staff
  /// members. Defaults to false/off when unset on the shop document.
  Future<void> setStaffDeleteEnabled(String slug, bool enabled) async {
    await _firestore.collection('shops').doc(slug).update({
      'staff_delete_enabled': enabled,
    });
  }

  /// Max number of devices staff/owner accounts can be signed in on at
  /// once; the mobile app watches this doc live and signs out the oldest
  /// session(s) for an affected account as soon as it's exceeded.
  Future<void> setMaxActiveDevices(
    String slug, {
    required int staff,
    required int owner,
  }) async {
    await _firestore.collection('shops').doc(slug).update({
      'max_active_devices_staff': staff,
      'max_active_devices_owner': owner,
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

  /// Writes all five shop-link fields at once. A cleared input must arrive
  /// here as null, not as an empty string: the mobile app treats any
  /// non-empty value as a link and would keep printing a QR code for it on
  /// every receipt. Nulls are written explicitly rather than omitted so the
  /// stale value on the document is actually overwritten. Values are stored
  /// raw (the handle or address as typed) — the URL each one resolves to is
  /// derived at print time by the mobile app, never stored.
  Future<void> setShopLinks(
    String slug, {
    required String? website,
    required String? facebook,
    required String? instagram,
    required String? tiktok,
    required bool linksEnabled,
  }) async {
    await _firestore.collection('shops').doc(slug).update({
      'website': website,
      'facebook': facebook,
      'instagram': instagram,
      'tiktok': tiktok,
      'shop_links_enabled': linksEnabled,
    });
  }

  /// A shop's transaction documents for the day range [from, to]
  /// (inclusive of both ends; null on a side means unbounded), in a single
  /// read of each collection. Callers derive the stat tiles, the trend
  /// chart, and the itemized transaction list from this one result (see
  /// shop_activity_aggregate.dart) instead of re-reading per date range.
  ///
  /// The server-side bound is deliberately coarse — see
  /// [activityQueryBounds] — and exists only to keep a shop's whole sales
  /// history from crossing the network to answer a question about one
  /// week. The exact range filter still runs client-side on what comes
  /// back, so the figures don't depend on how the mobile app happens to
  /// serialize its dates. A document whose created_at isn't an ISO8601
  /// string is outside every bounded window, exactly as the client-side
  /// filter already treats it.
  ///
  /// [includeProducts] backs the product-count tile only; views that show
  /// transactions alone skip that read. The catalog is never date-scoped —
  /// a product is current regardless of when it was added.
  Future<ShopActivity> getShopActivity(
    String slug, {
    DateTime? from,
    DateTime? to,
    bool includeProducts = true,
  }) async {
    final shopRef = _firestore.collection('shops').doc(slug);
    final bounds = activityQueryBounds(from: from, to: to);

    Query<Map<String, dynamic>> scoped(String collection) {
      Query<Map<String, dynamic>> query = shopRef.collection(collection);
      final startAt = bounds.startAt;
      final endBefore = bounds.endBefore;
      if (startAt != null) {
        query = query.where('created_at', isGreaterThanOrEqualTo: startAt);
      }
      if (endBefore != null) {
        query = query.where('created_at', isLessThan: endBefore);
      }
      return query;
    }

    final results = await Future.wait([
      scoped('sales').get(),
      scoped('expenses').get(),
      scoped('additional_income').get(),
      if (includeProducts) shopRef.collection('products').get(),
    ]);

    List<ActivityDoc> docs(int index) {
      if (index >= results.length) return const [];
      return results[index].docs
          .map((d) => ActivityDoc(id: d.id, data: d.data()))
          .toList();
    }

    return ShopActivity(
      sales: docs(0),
      expenses: docs(1),
      additionalIncome: docs(2),
      products: docs(3),
      from: from,
      to: to,
    );
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
      // New shops start with no links, and with the owner locked out of
      // editing them from the mobile app until an admin opts them in.
      shopLinksEnabled: false,
    );

    final ownerUser = ShopUser(
      id: ownerUid,
      username: ownerUsername,
      displayName: ownerDisplayName,
      email: email,
      role: 'owner',
      // New shops start disabled and need platform-admin approval (via the
      // Enabled toggle) before the owner can sign in.
      isEnabled: false,
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
