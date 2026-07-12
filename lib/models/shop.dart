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

  const Shop({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.ownerUid,
    required this.createdAt,
    this.staffLimit,
    this.productLimit,
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
    };
  }
}
