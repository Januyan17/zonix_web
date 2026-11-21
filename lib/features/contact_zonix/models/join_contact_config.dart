/// The single `public.join_contact_config` row (id = 1) in Supabase that
/// drives the "Contact Zonix" tile on the mobile app's shop code screen.
class JoinContactConfig {
  const JoinContactConfig({
    required this.phoneEnabled,
    required this.phone,
    required this.requestFormEnabled,
    this.message,
    this.updatedAt,
    this.updatedBy,
  });

  static const int phoneMaxLength = 40;
  static const int messageMaxLength = 500;

  /// Phone contact: number + Call Now + WhatsApp.
  final bool phoneEnabled;

  /// '' when none, never null.
  final String phone;

  /// "Send a Request" form.
  final bool requestFormEnabled;

  /// Null/empty means the app's own default text.
  final String? message;

  final DateTime? updatedAt;
  final String? updatedBy;

  factory JoinContactConfig.fromMap(Map<String, dynamic> map) {
    final message = (map['message'] as String?)?.trim();
    return JoinContactConfig(
      phoneEnabled: map['phone_enabled'] as bool? ?? false,
      phone: map['phone'] as String? ?? '',
      requestFormEnabled: map['request_form_enabled'] as bool? ?? false,
      message: message == null || message.isEmpty ? null : message,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
      updatedBy: map['updated_by'] as String?,
    );
  }

  /// What the app actually offers: phone ON with an empty number counts as
  /// phone OFF.
  bool get showsPhone => phoneEnabled && phone.trim().isNotEmpty;
  bool get showsForm => requestFormEnabled;

  /// Both off: the "Contact Zonix" tile is hidden in the app.
  bool get hiddenInApp => !showsPhone && !showsForm;

  /// Same editable values (ignores updated_at / updated_by).
  bool sameValuesAs(JoinContactConfig other) =>
      phoneEnabled == other.phoneEnabled &&
      phone == other.phone &&
      requestFormEnabled == other.requestFormEnabled &&
      (message ?? '') == (other.message ?? '');
}
