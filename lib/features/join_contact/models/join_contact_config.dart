import 'package:cloud_firestore/cloud_firestore.dart';

/// The "Contact Zonix — I would like to join" button on the mobile app's
/// shop code screen, from `platform_config/joinContact`.
class JoinContactConfig {
  const JoinContactConfig({
    required this.enabled,
    required this.phone,
    required this.message,
    this.updatedAt,
  });

  /// What the page starts from when the document doesn't exist yet.
  static const empty = JoinContactConfig(
    enabled: false,
    phone: '',
    message: '',
  );

  static const int phoneMaxLength = 40;
  static const int messageMaxLength = 500;

  /// Shows or hides the button in the app.
  final bool enabled;

  final String phone;

  /// Shown above the number in the popup. Empty means the app uses its own
  /// default text.
  final String message;

  final DateTime? updatedAt;

  static JoinContactConfig fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return empty;
    return JoinContactConfig(
      enabled: data['enabled'] as bool? ?? false,
      phone: data['phone'] as String? ?? '',
      message: data['message'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Null when valid. The phone is required while the button is shown, at most
/// [JoinContactConfig.phoneMaxLength] characters, with at least 7 digits.
String? joinContactPhoneError(String? value, {required bool enabled}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return enabled ? 'Enter a phone number to show the button' : null;
  }
  if (v.length > JoinContactConfig.phoneMaxLength) {
    return 'At most ${JoinContactConfig.phoneMaxLength} characters';
  }
  final digits = RegExp(r'\d').allMatches(v).length;
  if (digits < 7) return 'Enter a phone number with at least 7 digits';
  return null;
}
