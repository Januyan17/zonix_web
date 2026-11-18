import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:zonixweb/features/device_logins/models/device_login.dart';
import 'package:zonixweb/features/device_logins/models/device_session.dart';

/// One page of [DeviceLogin]s plus the cursor to fetch the next one.
class DeviceLoginPage {
  const DeviceLoginPage({
    required this.logins,
    required this.cursor,
    required this.hasMore,
  });

  final List<DeviceLogin> logins;

  /// The last document of this page, passed back as `startAfter` for the
  /// next one. Null when the page was empty.
  final DocumentSnapshot<Map<String, dynamic>>? cursor;

  /// False once a page comes back short — there's nothing after it.
  final bool hasMore;
}

/// Reads the top-level `device_logins` collection, written by the mobile app
/// once per install. Security rules (deployed from the mobile repo) allow
/// only platform super admins to read; nobody can update.
///
/// One-off get() reads only, never snapshots(): reads are billed per
/// document, so the list is paged and refreshed on demand.
class DeviceLoginService {
  DeviceLoginService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const pageSize = 25;

  CollectionReference<Map<String, dynamic>> get _logins =>
      _firestore.collection('device_logins');

  /// Newest first. With [shopId], only that shop's logins — that query
  /// needs the composite index (shop_id ASC, created_at DESC); without it
  /// Firestore fails with a "requires an index" error whose message holds
  /// the link to create it, which callers should show as-is.
  Future<DeviceLoginPage> fetchPage({
    String? shopId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _logins;
    if (shopId != null) {
      query = query.where('shop_id', isEqualTo: shopId);
    }
    query = query.orderBy('created_at', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(limit).get();
    final docs = snapshot.docs;
    return DeviceLoginPage(
      logins: docs.map(DeviceLogin.fromSnapshot).toList(),
      cursor: docs.isEmpty ? null : docs.last,
      hasMore: docs.length == limit,
    );
  }

  /// Permanently deletes `device_logins` documents by id — history only;
  /// live sessions are untouched, so nobody is signed out. Rules allow this
  /// for platform super admins only. Batched in chunks under Firestore's
  /// 500-writes-per-batch limit.
  Future<void> deleteLogins(Iterable<String> ids) async {
    final all = ids.toList();
    for (var i = 0; i < all.length; i += 450) {
      final batch = _firestore.batch();
      for (final id in all.skip(i).take(450)) {
        batch.delete(_logins.doc(id));
      }
      await batch.commit();
    }
  }

  /// The user's live sign-ins in one shop. Small by construction — the
  /// mobile app trims it to the shop's active-device limit (usually 1-2) —
  /// so this costs about one read per person (an empty result still bills
  /// one read).
  Future<List<DeviceSession>> fetchActiveSessions({
    required String shopId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('shops/$shopId/users/$userId/sessions')
        .get();
    return snapshot.docs.map(DeviceSession.fromSnapshot).toList();
  }

  /// [fetchActiveSessions] for each `shopId/userId` key, in parallel.
  /// A failed lookup leaves that key out rather than failing the rest, so
  /// those devices show as "status unknown" instead of breaking the page.
  Future<Map<String, List<DeviceSession>>> fetchActiveSessionsFor(
    Iterable<String> userKeys,
  ) async {
    final entries = await Future.wait(
      userKeys.map((key) async {
        final slash = key.indexOf('/');
        try {
          final sessions = await fetchActiveSessions(
            shopId: key.substring(0, slash),
            userId: key.substring(slash + 1),
          );
          return MapEntry(key, sessions);
        } catch (_) {
          return null;
        }
      }),
    );
    return {
      for (final e in entries)
        if (e != null) e.key: e.value,
    };
  }
}
