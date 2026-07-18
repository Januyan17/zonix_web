class Shop {
  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final String ownerUid;
  final String createdAt;

  /// Max number of active staff (role == 'staff') the shop owner can create
  /// from the mobile app. Null means unlimited.
  final int? staffLimit;

  /// Max number of active products the shop owner can create from the
  /// mobile app. Null means unlimited.
  final int? productLimit;

  /// Whether the mobile/POS app shows a "Delete" option for staff members.
  /// Defaults to false when unset on the document.
  final bool staffDeleteEnabled;

  /// Max number of devices a staff (non-owner) account can be signed in on
  /// at once; the mobile app signs out the oldest session(s) once this is
  /// exceeded on a new device. Defaults to 1 when unset on the document.
  final int maxActiveDevicesStaff;

  /// Same as [maxActiveDevicesStaff] but for the owner/admin account only.
  /// Defaults to 1 when unset on the document.
  final int maxActiveDevicesOwner;

  const Shop({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.ownerUid,
    required this.createdAt,
    this.staffLimit,
    this.productLimit,
    this.staffDeleteEnabled = false,
    this.maxActiveDevicesStaff = 1,
    this.maxActiveDevicesOwner = 1,
  });

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      isActive: map['is_active'] as bool,
      ownerUid: map['owner_uid'] as String,
      createdAt: map['created_at'] as String,
      staffLimit: (map['staff_limit'] as num?)?.toInt(),
      productLimit: (map['product_limit'] as num?)?.toInt(),
      staffDeleteEnabled: map['staff_delete_enabled'] as bool? ?? false,
      maxActiveDevicesStaff:
          (map['max_active_devices_staff'] as num?)?.toInt() ?? 1,
      maxActiveDevicesOwner:
          (map['max_active_devices_owner'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'is_active': isActive,
      'owner_uid': ownerUid,
      'created_at': createdAt,
      'staff_limit': staffLimit,
      'product_limit': productLimit,
      'staff_delete_enabled': staffDeleteEnabled,
      'max_active_devices_staff': maxActiveDevicesStaff,
      'max_active_devices_owner': maxActiveDevicesOwner,
    };
  }
}
