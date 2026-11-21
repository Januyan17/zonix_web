import 'package:cloud_firestore/cloud_firestore.dart';

/// The lock-popup text and "Contact us to pay" target shared by every shop,
/// stored in `platform_config/trialDefaults`.
///
/// A shop's own `trial_message` / `trial_contact` still win when set; these
/// fill in whatever the shop leaves blank. Both null means the mobile app
/// falls back to its built-in copy, exactly as before.
class TrialDefaults {
  const TrialDefaults({this.message, this.contact, this.updatedAt});

  static const empty = TrialDefaults();

  final String? message;
  final String? contact;
  final DateTime? updatedAt;

  bool get isEmpty => message == null && contact == null;

  factory TrialDefaults.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return empty;
    return TrialDefaults(
      message: _text(data['message']),
      contact: _text(data['contact']),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
