import 'package:cloud_firestore/cloud_firestore.dart';

/// A phone's request to download sales history older than the current
/// month, at `shops/{shopId}/history_requests/{deviceId}` — one document per
/// phone. The phone writes it as "pending"; an admin approves (valid for 24
/// hours from approved_at) or denies it here.
///
/// Every field is parsed leniently so an older or partial document never
/// takes the page down: strings default to '' and timestamps to null.
class HistoryRequest {
  const HistoryRequest({
    required this.ref,
    this.shopId = '',
    this.shopName = '',
    this.deviceId = '',
    this.deviceName = '',
    this.userId = '',
    this.username = '',
    this.displayName = '',
    this.role = '',
    this.status = '',
    this.requestedAt,
    this.approvedAt,
    this.approvedBy,
  });

  /// The document itself — what approve/deny write to. Null only for
  /// instances built by hand (tests).
  final DocumentReference<Map<String, dynamic>>? ref;

  final String shopId;
  final String shopName;
  final String deviceId;

  /// e.g. "samsung SM-A155F".
  final String deviceName;

  final String userId;
  final String username;
  final String displayName;

  /// "owner" or "staff".
  final String role;

  /// Raw status as stored: "pending", "approved" or "denied". See
  /// history_request_state.dart for what it effectively means right now.
  final String status;

  final DateTime? requestedAt;

  /// Null until approved, and for a moment after approving while the
  /// server timestamp is pending.
  final DateTime? approvedAt;

  final String? approvedBy;

  factory HistoryRequest.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return HistoryRequest.fromMap(doc.data() ?? const {}, ref: doc.reference);
  }

  factory HistoryRequest.fromMap(
    Map<String, dynamic> map, {
    DocumentReference<Map<String, dynamic>>? ref,
  }) {
    String str(String key) {
      final v = map[key];
      return v is String ? v : (v == null ? '' : v.toString());
    }

    // The path is the source of truth for which shop and phone this is;
    // the stored copies are only a fallback for docs built without a ref.
    final pathShopId = ref?.parent.parent?.id;
    final storedShopId = str('shop_id');
    final storedDeviceId = str('device_id');
    final approvedBy = map['approved_by'];

    return HistoryRequest(
      ref: ref,
      shopId: pathShopId ?? storedShopId,
      shopName: str('shop_name'),
      deviceId: ref?.id ?? storedDeviceId,
      deviceName: str('device_name'),
      userId: str('user_id'),
      username: str('username'),
      displayName: str('display_name'),
      role: str('role'),
      status: str('status'),
      requestedAt: _toDateTime(map['requested_at']),
      approvedAt: _toDateTime(map['approved_at']),
      approvedBy: approvedBy is String ? approvedBy : null,
    );
  }

  static DateTime? _toDateTime(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Best available name for the shop: name, then id.
  String get shopLabel =>
      shopName.isNotEmpty ? shopName : (shopId.isNotEmpty ? shopId : '—');

  /// Best available name for the user: display name, then username.
  String get userLabel => displayName.isNotEmpty
      ? displayName
      : (username.isNotEmpty ? username : (userId.isNotEmpty ? userId : '—'));

  /// Best available name for the phone, for the confirmation copy.
  String get deviceLabel => deviceName.isNotEmpty
      ? deviceName
      : (deviceId.isNotEmpty ? deviceId : 'this phone');
}
