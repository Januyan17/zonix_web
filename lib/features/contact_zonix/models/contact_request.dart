import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/zonix_colors.dart';

enum ContactRequestStatus {
  newRequest('new', 'New', Icons.fiber_new_rounded),
  contacted('contacted', 'Contacted', Icons.phone_callback_rounded),
  onboarded('onboarded', 'Onboarded', Icons.verified_rounded),
  rejected('rejected', 'Rejected', Icons.block_rounded);

  const ContactRequestStatus(this.value, this.label, this.icon);

  /// The value stored in contact_requests.status.
  final String value;
  final String label;
  final IconData icon;

  static ContactRequestStatus fromValue(String? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => ContactRequestStatus.newRequest,
  );

  /// Foreground / background for the status pill, from existing tokens.
  (Color, Color) colors(ColorScheme scheme) => switch (this) {
    newRequest => (ZonixColors.onCyanContainer, ZonixColors.cyanContainer),
    contacted => (ZonixColors.navy, ZonixColors.navyContainer),
    onboarded => (ZonixColors.onEmeraldContainer, ZonixColors.emeraldContainer),
    rejected => (scheme.onErrorContainer, scheme.errorContainer),
  };
}

/// One row of `public.contact_requests`: a shop asking to join Zonix from
/// the mobile app's "Send a Request" form.
class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.createdAt,
    required this.ownerName,
    required this.shopName,
    required this.phone,
    required this.status,
    this.city,
    this.message,
    this.platform,
    this.appVersion,
    this.adminNote,
    this.handledAt,
    this.handledBy,
  });

  static const int noteMaxLength = 1000;

  final String id;
  final DateTime createdAt;
  final String ownerName;
  final String shopName;

  /// E.164, +94XXXXXXXXX.
  final String phone;
  final String? city;
  final String? message;
  final String? platform;
  final String? appVersion;
  final ContactRequestStatus status;
  final String? adminNote;
  final DateTime? handledAt;
  final String? handledBy;

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  factory ContactRequest.fromMap(Map<String, dynamic> map) {
    return ContactRequest(
      id: map['id'] as String,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ownerName: _text(map['owner_name']) ?? '',
      shopName: _text(map['shop_name']) ?? '',
      phone: _text(map['phone']) ?? '',
      city: _text(map['city']),
      message: _text(map['message']),
      platform: _text(map['platform']),
      appVersion: _text(map['app_version']),
      status: ContactRequestStatus.fromValue(map['status'] as String?),
      adminNote: _text(map['admin_note']),
      handledAt: DateTime.tryParse(
        map['handled_at'] as String? ?? '',
      )?.toLocal(),
      handledBy: _text(map['handled_by']),
    );
  }

  ContactRequest copyWith({
    ContactRequestStatus? status,
    String? Function()? adminNote,
  }) {
    return ContactRequest(
      id: id,
      createdAt: createdAt,
      ownerName: ownerName,
      shopName: shopName,
      phone: phone,
      city: city,
      message: message,
      platform: platform,
      appVersion: appVersion,
      status: status ?? this.status,
      adminNote: adminNote == null ? this.adminNote : adminNote(),
      handledAt: handledAt,
      handledBy: handledBy,
    );
  }

  /// Search across shop name, owner name, phone (digits too) and city.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    return shopName.toLowerCase().contains(q) ||
        ownerName.toLowerCase().contains(q) ||
        (city?.toLowerCase().contains(q) ?? false) ||
        phone.toLowerCase().contains(q) ||
        (qDigits.length >= 3 &&
            (phoneDigits.contains(qDigits) ||
                // 077… typed against +9477…
                (qDigits.startsWith('0') &&
                    phoneDigits.contains(qDigits.substring(1)))));
  }
}
