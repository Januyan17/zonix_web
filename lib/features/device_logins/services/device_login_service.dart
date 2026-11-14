import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:zonixweb/features/device_logins/models/device_login.dart';

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
}
