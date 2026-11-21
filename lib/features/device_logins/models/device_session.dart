import 'package:cloud_firestore/cloud_firestore.dart';

/// One live sign-in of a mobile app install, from
/// `shops/{shopId}/users/{uid}/sessions/{deviceId}`.
///
/// The mobile app writes this on every login (so [loggedInAt] is the most
/// recent login on that install) and deletes it on logout, or when a newer
/// login pushes the account over its active-device limit. So a document
/// existing means "signed in on this install right now"; it is not a
/// heartbeat, so it says nothing about whether the app is open.
class DeviceSession {
  const DeviceSession({
    required this.deviceId,
    this.deviceName = '',
    this.loggedInAt,
  });

  /// Same id as [DeviceLogin.deviceId] — the document id is the device id.
  final String deviceId;
  final String deviceName;

  /// Server time of the latest login on this install. Null when missing.
  final DateTime? loggedInAt;

  factory DeviceSession.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DeviceSession.fromMap(doc.id, doc.data() ?? const {});
  }

  factory DeviceSession.fromMap(String id, Map<String, dynamic> map) {
    final rawId = map['device_id'];
    final name = map['device_name'];
    final at = map['logged_in_at'];
    return DeviceSession(
      deviceId: rawId is String && rawId.isNotEmpty ? rawId : id,
      deviceName: name is String ? name : '',
      loggedInAt: at is Timestamp
          ? at.toDate()
          : (at is DateTime
                ? at
                : (at is String ? DateTime.tryParse(at) : null)),
    );
  }
}
