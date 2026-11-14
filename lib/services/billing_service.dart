import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/shop_billing.dart';
import '../utils/error_utils.dart';

/// One shop's billing, with the name/slug needed to list it.
class ShopBillingEntry {
  const ShopBillingEntry({
    required this.slug,
    required this.name,
    required this.billing,
  });

  final String slug;
  final String name;
  final ShopBilling billing;
}

/// What the admin entered when marking a payment.
class PaymentInput {
  PaymentInput({
    required this.amount,
    required this.paidAt,
    required List<DateTime> periods,
    required this.nextDueAt,
    this.note,
  }) : periods = normalizePeriods(periods);

  final double amount;
  final DateTime paidAt;

  /// The months this payment covers (any months, oldest first).
  final List<DateTime> periods;
  final DateTime? nextDueAt;
  final String? note;

  int get months => periods.length;
}

/// Monthly subscription tracking per shop.
///
/// Everything lives on the shop's `admin_shop_index/{slug}` doc
/// (billing_amount, billing_next_due_at, billing_payments): that collection
/// is already readable and writable only by platform super admins, so shop
/// owners never see it and no security-rule change is needed. Deleting a
/// shop deletes its index doc, and with it the billing history.
class BillingService {
  BillingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _index =>
      _firestore.collection('admin_shop_index');

  Stream<ShopBilling> watchShop(String slug) {
    return _index
        .doc(slug)
        .snapshots()
        .map((doc) => ShopBilling.fromMap(doc.data()));
  }

  Stream<List<ShopBillingEntry>> watchAll() {
    return _index.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (d) => ShopBillingEntry(
              slug: d.id,
              name: d.data()['name'] as String? ?? d.id,
              billing: ShopBilling.fromMap(d.data()),
            ),
          )
          .toList(),
    );
  }

  /// Sets the usual monthly amount and the next due date. Null clears.
  Future<void> setPlan(
    String slug, {
    required double? monthlyAmount,
    required DateTime? nextDueAt,
  }) async {
    await _index.doc(slug).update({
      'billing_amount': monthlyAmount,
      'billing_next_due_at': nextDueAt == null
          ? null
          : Timestamp.fromDate(dateOnly(nextDueAt)),
    });
  }

  /// Appends a payment and moves the next due date on, atomically.
  Future<void> recordPayment(String slug, PaymentInput input) async {
    final ref = _index.doc(slug);
    final payment = ShopPayment(
      id: ref.collection('_ids').doc().id,
      amount: input.amount,
      paidAt: dateOnly(input.paidAt),
      periods: input.periods,
      note: input.note,
      recordedAt: DateTime.now(),
    );
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Shop index entry not found');
      final existing = snap.data()?['billing_payments'];
      tx.update(ref, {
        'billing_payments': [
          if (existing is List) ...existing,
          payment.toMap(),
        ],
        if (input.nextDueAt != null)
          'billing_next_due_at': Timestamp.fromDate(dateOnly(input.nextDueAt!)),
      });
    });
  }

  /// Removes one payment from the history. The next due date is left as
  /// is — edit the plan to move it back if needed.
  Future<void> deletePayment(String slug, String paymentId) async {
    final ref = _index.doc(slug);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.data()?['billing_payments'];
      if (existing is! List) return;
      tx.update(ref, {
        'billing_payments': [
          for (final p in existing)
            if (!(p is Map && p['id'] == paymentId)) p,
        ],
      });
    });
  }
}

/// One shared live listener on [BillingService.watchAll], for the nav badge
/// and the Payments screen alike, so switching pages doesn't re-subscribe.
/// Same lifecycle as PendingHistoryRequests: subscribes with the first
/// listener, cancels (and forgets the data) when the last one goes.
class ShopBillingOverview extends ChangeNotifier {
  ShopBillingOverview._();

  static final instance = ShopBillingOverview._();

  BillingService? _service;
  StreamSubscription<List<ShopBillingEntry>>? _subscription;

  List<ShopBillingEntry>? _entries;
  String? _error;

  List<ShopBillingEntry>? get entries => _entries;
  String? get error => _error;
  bool get loading => _entries == null && _error == null;

  /// Shops that are overdue, due today or due soon.
  int get attentionCount {
    final now = DateTime.now();
    return _entries?.where((e) => e.billing.needsAttentionAt(now)).length ?? 0;
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
    if (_subscription != null) return;
    try {
      _service ??= BillingService();
      _subscription = _service!.watchAll().listen(
        (entries) {
          _entries = entries;
          _error = null;
          notifyListeners();
        },
        onError: (Object e) {
          _error = describeError(e);
          notifyListeners();
        },
      );
    } catch (e) {
      _error = describeError(e);
    }
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    _entries = null;
    _error = null;
  }

  void retry() {
    _subscription?.cancel();
    _subscription = null;
    _entries = null;
    _error = null;
    notifyListeners();
    if (hasListeners) _start();
  }
}
