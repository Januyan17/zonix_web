class ShopUser {
  final String id;
  final String username;
  final String displayName;
  final String email;
  final String role;
  final bool isEnabled;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  const ShopUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  factory ShopUser.fromMap(Map<String, dynamic> map) {
    return ShopUser(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      isEnabled: map['is_enabled'] as bool,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isDeleted: map['is_deleted'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'email': email,
      'role': role,
      'is_enabled': isEnabled,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted,
    };
  }
}
