import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';
import 'package:zonixweb/features/shops/services/shop_directory.dart';

/// A trial counts as "ending soon" when it has this many days or fewer left.
const kTrialEndingSoonDays = 2;

/// Live free-trial status of every shop, for the Payments page's "Free
/// trials" tab and the nav badge (a trial that has ended means the shop's
/// app is locked and a payment is waiting to be collected).
///
/// Derived entirely from [ShopDirectory] — the one shared listener on the
/// shop index and shop documents — so it adds no Firestore reads of its
/// own. A minute timer re-checks the clock, so a trial that runs out while
/// the portal is open moves to "ended" without any document changing.
///
/// Same lifecycle as the other shared overviews: attaches to the directory
/// with the first listener, detaches (and forgets) when the last goes.
class TrialOverview extends ChangeNotifier {
  TrialOverview._();

  static final instance = TrialOverview._();

  final ShopDirectory _directory = ShopDirectory.instance;
  bool _attached = false;
  Timer? _ticker;
  String _lastSignature = '';

  String? get error => _directory.error;
  bool get loading => _directory.loading;

  /// Shops with the trial switched on, in no particular order.
  List<Shop> get trialShops =>
      _directory.shops.where((s) => s.trial.trialEnabled).toList();

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
    if (_attached) return;
    _attached = true;
    _directory.addListener(_notify);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      // Only rebuild when the clock actually moved a trial between
      // groups (or its "days left" figure), not every minute.
      if (_signature() != _lastSignature) _notify();
    });
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
    if (!_attached) return;
    _attached = false;
    _directory.removeListener(_notify);
    _ticker?.cancel();
    _ticker = null;
    _lastSignature = '';
  }

  void retry() => _directory.retry();
}
