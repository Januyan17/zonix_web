import 'package:cloud_firestore/cloud_firestore.dart';

/// A currently-active login session for a shop user on a single device.
/// A doc existing at shops/{slug}/users/{uid}/sessions/{deviceId} means
/// that device is currently logged in — there's no inactive/historical
/// state to filter out.
class UserSession {
  final String deviceId;
  final String deviceName;
  final DateTime loggedInAt;

  const UserSession({
    required this.deviceId,
    required this.deviceName,
    required this.loggedInAt,
  });

  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      loggedInAt: (map['logged_in_at'] as Timestamp).toDate(),
    );
  }
}
