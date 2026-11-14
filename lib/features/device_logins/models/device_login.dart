import 'package:cloud_firestore/cloud_firestore.dart';

/// One first-login of a mobile app install into a shop, from the top-level
/// `device_logins` collection. The mobile app writes it once per install: a
/// reinstall or cleared app data gets a new [deviceId] and a new document;
/// logging out and back in on the same install does not.
///
/// Every field is parsed leniently — older or partial documents must never
/// take the page down — so strings default to '' and numbers to null.
class DeviceLogin {
  const DeviceLogin({
    required this.id,
    this.shopId = '',
    this.shopSlug = '',
    this.shopName = '',
    this.userId = '',
    this.username = '',
    this.displayName = '',
    this.role = '',
    this.deviceId = '',
    this.deviceName = '',
    this.platform = '',
    this.osVersion = '',
    this.appVersion = '',
    this.appBuild,
    this.createdAt,
  });

  /// The Firestore document id.
  final String id;

  final String shopId;
  final String shopSlug;
  final String shopName;
  final String userId;
  final String username;
  final String displayName;

  /// "owner" or "staff".
  final String role;

  final String deviceId;

  /// e.g. "samsung SM-A155F".
  final String deviceName;

  /// "android" or "ios".
  final String platform;

  /// e.g. "Android 15".
  final String osVersion;

  /// The dotted version string, e.g. "1.0.1". Display only — never compared.
  final String appVersion;

  /// The build number, the same number the App Version screen's
  /// minSupportedBuild is expressed in. Null when missing.
  final int? appBuild;

  /// Server time of the first login. Null when missing or malformed.
  final DateTime? createdAt;

  factory DeviceLogin.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return DeviceLogin.fromMap(doc.id, doc.data() ?? const {});
  }

  factory DeviceLogin.fromMap(String id, Map<String, dynamic> map) {
    String str(String key) {
      final v = map[key];
      return v is String ? v : (v == null ? '' : v.toString());
    }

    return DeviceLogin(
      id: id,
      shopId: str('shop_id'),
      shopSlug: str('shop_slug'),
      shopName: str('shop_name'),
      userId: str('user_id'),
      username: str('username'),
      displayName: str('display_name'),
      role: str('role'),
      deviceId: str('device_id'),
      deviceName: str('device_name'),
      platform: str('platform'),
      osVersion: str('os_version'),
      appVersion: str('app_version'),
      appBuild: _toInt(map['app_build']),
      createdAt: _toDateTime(map['created_at']),
    );
  }

  static int? _toInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static DateTime? _toDateTime(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Best available name for the shop: name, then slug, then id.
  String get shopLabel => shopName.isNotEmpty
      ? shopName
      : (shopSlug.isNotEmpty ? shopSlug : (shopId.isNotEmpty ? shopId : '—'));

  /// Best available name for the user: display name, then username.
  String get userLabel => displayName.isNotEmpty
      ? displayName
      : (username.isNotEmpty ? username : (userId.isNotEmpty ? userId : '—'));
}
