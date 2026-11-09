import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/history_request.dart';
import '../utils/error_utils.dart';
import 'app_version_service.dart' show NotSignedInException;

/// One page of [HistoryRequest]s plus the cursor to fetch the next one.
class HistoryRequestPage {
  const HistoryRequestPage({
    required this.requests,
    required this.cursor,
    required this.hasMore,
  });

  final List<HistoryRequest> requests;

  /// The last document of this page, passed back as `startAfter` for the
  /// next one. Null when the page was empty.
  final DocumentSnapshot<Map<String, dynamic>>? cursor;

  /// False once a page comes back short — there's nothing after it.
  final bool hasMore;
}

/// Reads and answers `shops/{shopId}/history_requests/{deviceId}`: a
/// phone's request to download history older than the current month.
/// Security rules (deployed from the mobile repo) let platform super admins
/// read and update any request, including through a collection group query.
///
/// The collection-group queries need indexes; without them Firestore fails
/// with a "requires an index" error whose message holds the link to create
/// it, which callers should show as-is.
class HistoryRequestService {
  HistoryRequestService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const pageSize = 25;
  static const pendingLimit = 50;

  /// Live pending requests across every shop, newest first. Needs the
  /// collection-group index (status ASC, requested_at DESC).
  ///
  /// Prefer [PendingHistoryRequests.instance] over calling this directly:
  /// it shares one listener between the nav badge and the screen.
  Stream<List<HistoryRequest>> watchPending() {
    return _firestore
        .collectionGroup('history_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requested_at', descending: true)
        .limit(pendingLimit)
        .snapshots()
        .map((s) => s.docs.map(HistoryRequest.fromSnapshot).toList());
  }

  /// Newest first, one-off read. With [shopId], that shop's subcollection;
  /// otherwise every shop through a collection group query (which needs
  /// the collection-group requested_at DESC index).
  Future<HistoryRequestPage> getRecent({
    String? shopId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query = shopId == null
        ? _firestore.collectionGroup('history_requests')
        : _firestore
              .collection('shops')
              .doc(shopId)
              .collection('history_requests');
    query = query.orderBy('requested_at', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(limit).get();
    final docs = snapshot.docs;
    return HistoryRequestPage(
      requests: docs.map(HistoryRequest.fromSnapshot).toList(),
      cursor: docs.isEmpty ? null : docs.last,
      hasMore: docs.length == limit,
    );
  }

  /// One request, re-read after approving/denying so the row shows the
  /// server's resolved approved_at.
  Future<HistoryRequest> getOne(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    return HistoryRequest.fromSnapshot(await ref.get());
  }

  /// Allows the phone to download older history for 24 hours from now
  /// (server time). Approving an expired request restarts the 24 hours.
  Future<void> approve(DocumentReference<Map<String, dynamic>> ref) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const NotSignedInException();
    await ref.update({
      'status': 'approved',
      'approved_at': FieldValue.serverTimestamp(),
      'approved_by': uid,
    });
  }

  Future<void> deny(DocumentReference<Map<String, dynamic>> ref) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const NotSignedInException();
    await ref.update({'status': 'denied', 'approved_by': uid});
  }
}

/// One shared live listener on [HistoryRequestService.watchPending], for the
/// nav badge and the History requests screen alike.
///
/// The admin shell is rebuilt on every page change; subscribing there
/// directly would open a fresh Firestore listener — and pay for up to 50
/// document reads again — on each navigation. This subscribes when the
/// first listener attaches and cancels when the last one goes (e.g. on
/// logout, when no shell is left on screen).
class PendingHistoryRequests extends ChangeNotifier {
  PendingHistoryRequests._();

  static final instance = PendingHistoryRequests._();

  HistoryRequestService? _service;
  StreamSubscription<List<HistoryRequest>>? _subscription;

  List<HistoryRequest>? _requests;
  String? _error;

  /// Null until the first snapshot arrives.
  List<HistoryRequest>? get requests => _requests;

  /// Set when the listener failed (e.g. a missing index) — shown verbatim.
  String? get error => _error;

  bool get loading => _requests == null && _error == null;

  int get count => _requests?.length ?? 0;

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
      _service ??= HistoryRequestService();
      _subscription = _service!.watchPending().listen(
        (requests) {
          _requests = requests;
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
    // Forget the last result: the next subscriber may be a different admin
    // after a logout, and must not see the previous session's data.
    _requests = null;
    _error = null;
  }

  /// Re-subscribes after an error (e.g. once a missing index is created).
  void retry() {
    _subscription?.cancel();
    _subscription = null;
    _requests = null;
    _error = null;
    notifyListeners();
    if (hasListeners) _start();
  }
}
