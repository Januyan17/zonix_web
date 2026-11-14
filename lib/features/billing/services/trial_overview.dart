import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';

/// A trial counts as "ending soon" when it has this many days or fewer left.
const kTrialEndingSoonDays = 2;

/// Live free-trial status of every shop, for the Payments page's "Free
/// trials" tab and the nav badge (a trial that has ended means the shop's
/// app is locked and a payment is waiting to be collected).
///
/// `shops` can't be listed by security rule, so this follows the portal's
/// `admin_shop_index` and keeps one document listener per shop, the same
/// one-get-per-shop pattern the shop list already uses. A minute timer
/// re-checks the clock, so a trial that runs out while the portal is open
/// moves to "ended" without any document changing.
///
/// Same lifecycle as the other shared overviews: subscribes with the first
/// listener, cancels everything (and forgets the data) when the last goes.
class TrialOverview extends ChangeNotifier {
  TrialOverview._();

  static final instance = TrialOverview._();

  FirebaseFirestore? _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _indexSub;
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _shopSubs = {};
  final Map<String, Shop> _shops = {};
  Timer? _ticker;
  String _lastSignature = '';

  bool _indexLoaded = false;
  String? _error;

  String? get error => _error;
  bool get loading => !_indexLoaded && _error == null;

  /// Shops with the trial switched on, in no particular order.
  List<Shop> get trialShops =>
      _shops.values.where((s) => s.trial.trialEnabled).toList();

  /// Trials that have ended: the app is locked, collect the payment.
  int get endedCount {
    final now = DateTime.now();
    return trialShops
        .where((s) => s.trial.stateAt(now) == ShopTrialState.ended)
        .length;
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
      _indexSub = _firestore!
          .collection('admin_shop_index')
          .snapshots()
          .listen(
            (snapshot) {
              _indexLoaded = true;
              _error = null;
              _syncShops(snapshot.docs.map((d) => d.id).toSet());
              _notify();
            },
            onError: (Object e) {
              _error = describeError(e);
              notifyListeners();
            },
          );
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        // Only rebuild when the clock actually moved a trial between
        // groups (or its "days left" figure), not every minute.
        if (_signature() != _lastSignature) _notify();
      });
    } catch (e) {
      _error = describeError(e);
    }
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
              if (shop == null) {
                _shops.remove(slug);
              } else {
                _shops[slug] = shop;
              }
              _notify();
            },
            // One unreadable shop (e.g. mid-deletion) mustn't break the rest.
            onError: (Object _) {},
          );
    }
  }

  String _signature() {
    final now = DateTime.now();
    final parts = [
      for (final s in trialShops)
        '${s.id}:${s.trial.stateAt(now).name}:${s.trial.daysLeftAt(now)}',
    ]..sort();
    return parts.join('|');
  }

  void _notify() {
    _lastSignature = _signature();
    notifyListeners();
  }

  void _stop() {
    _indexSub?.cancel();
    _indexSub = null;
    for (final sub in _shopSubs.values) {
      sub.cancel();
    }
    _shopSubs.clear();
    _shops.clear();
    _ticker?.cancel();
    _ticker = null;
    _indexLoaded = false;
    _error = null;
    _lastSignature = '';
  }

  void retry() {
    _stop();
    notifyListeners();
    if (hasListeners) _start();
  }
}
