import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/features/shops/models/shop.dart';

/// The single live copy of the portal's shop data, shared by every page.
///
/// Before this existed, the nav badges, the Payments page, the free-trial
/// overview and the Shops list each opened their own listener on
/// `admin_shop_index` and fetched every `shops/{slug}` document again — the
/// same N documents read three to five times on every page load. Now there
/// is exactly one index listener and one listener per shop document, and
/// everything derives from them. Once loaded, only documents that actually
/// change are read again.
///
/// Lifecycle matches the other shared overviews: subscribes when the first
/// listener attaches, cancels everything (and forgets the data) when the
/// last one goes — e.g. on logout, when no shell is left on screen.
class ShopDirectory extends ChangeNotifier {
  ShopDirectory._();

  static final instance = ShopDirectory._();

  FirebaseFirestore? _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _indexSub;
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _shopSubs = {};

  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _indexDocs;
  final Map<String, Shop?> _shops = {};
  String? _error;
  int _indexRevision = 0;
  final List<Completer<void>> _indexWaiters = [];

  /// `admin_shop_index` docs, newest first (by `createdAt`, the same order
  /// the Shops page always used). Null until the first snapshot arrives.
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? get indexDocs =>
      _indexDocs;

  /// Bumped only when the index itself changes, so consumers that derive
  /// from it alone (billing) can skip work on shop-document updates.
  int get indexRevision => _indexRevision;

  String? get error => _error;
  bool get indexLoaded => _indexDocs != null;
  bool get loading => _indexDocs == null && _error == null;

  /// True once the shop document for [slug] has been received (it may
  /// still be null if the doc is missing or unreadable).
  bool isShopLoaded(String slug) => _shops.containsKey(slug);

  /// The parsed `shops/{slug}` document, or null if missing, malformed or
  /// not loaded yet (see [isShopLoaded]).
  Shop? shop(String slug) => _shops[slug];

  /// Every successfully parsed shop, in no particular order.
  Iterable<Shop> get shops => _shops.values.whereType<Shop>();

  /// Resolves with the index once loaded. Used by one-off readers (e.g. a
  /// dropdown) so they don't pay for a separate read of the collection.
  /// Holds a listener while waiting so the subscription is running.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> indexOnce() async {
    if (_indexDocs != null) return _indexDocs!;
    void keepAlive() {}
    addListener(keepAlive);
    try {
      while (_indexDocs == null) {
        if (_error != null) throw StateError(_error!);
        final waiter = Completer<void>();
        _indexWaiters.add(waiter);
        await waiter.future;
      }
      return _indexDocs!;
    } finally {
      removeListener(keepAlive);
    }
  }

  @override
  void addListener(VoidCallback listener) {
    final first = !hasListeners;
    super.addListener(listener);
    if (first) _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop();
  }

  void _start() {
    if (_indexSub != null) return;
    try {
      _firestore ??= FirebaseFirestore.instance;
      // Unordered on the server so docs lacking `createdAt` are still seen
      // (billing and trials always included them); sorted here instead.
      _indexSub = _firestore!
          .collection('admin_shop_index')
          .snapshots()
          .listen(
            (snapshot) {
              final docs = [...snapshot.docs]..sort(_newestFirst);
              _indexDocs = docs;
              _error = null;
              _indexRevision++;
              _syncShops(docs.map((d) => d.id).toSet());
              _wakeWaiters();
              notifyListeners();
            },
            onError: (Object e) {
              _error = describeError(e);
              _wakeWaiters();
              notifyListeners();
            },
          );
    } catch (e) {
      _error = describeError(e);
    }
  }

  static int _newestFirst(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final ca = a.data()['createdAt'];
    final cb = b.data()['createdAt'];
    final sa = ca is String ? ca : '';
    final sb = cb is String ? cb : '';
    return sb.compareTo(sa);
  }

  void _syncShops(Set<String> slugs) {
    for (final slug in _shopSubs.keys.toList()) {
      if (!slugs.contains(slug)) {
        _shopSubs.remove(slug)?.cancel();
        _shops.remove(slug);
      }
    }
    for (final slug in slugs) {
      if (_shopSubs.containsKey(slug)) continue;
      _shopSubs[slug] = _firestore!
          .collection('shops')
          .doc(slug)
          .snapshots()
          .listen(
            (doc) {
              final data = doc.data();
              Shop? shop;
              if (data != null) {
                try {
                  shop = Shop.fromMap(data);
                } catch (_) {
                  // A malformed shop doc is skipped, never fatal.
                }
              }
              _shops[slug] = shop;
              notifyListeners();
            },
            // One unreadable shop (e.g. mid-deletion) mustn't break the rest.
            onError: (Object _) {
              _shops[slug] = null;
              notifyListeners();
            },
          );
    }
  }

  void _wakeWaiters() {
    for (final w in _indexWaiters) {
      if (!w.isCompleted) w.complete();
    }
    _indexWaiters.clear();
  }

  void _stop() {
    _indexSub?.cancel();
    _indexSub = null;
    for (final sub in _shopSubs.values) {
      sub.cancel();
    }
    _shopSubs.clear();
    // Forget everything: the next subscriber may be a different admin
    // after a logout, and must not see the previous session's data.
    _shops.clear();
    _indexDocs = null;
    _error = null;
    _indexRevision++;
  }

  /// Re-subscribes after an error.
  void retry() {
    _stop();
    notifyListeners();
    if (hasListeners) _start();
  }
}
