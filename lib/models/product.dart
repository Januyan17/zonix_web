/// A product belonging to a shop (shops/{slug}/products/{id}).
///
/// The mobile app that writes these documents isn't part of this repo, so
/// field names are read defensively: each getter tries a handful of common
/// aliases and falls back to null/omitted rather than throwing, so an
/// unexpected schema shows a partial card instead of crashing the admin
/// portal.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.sku,
    this.price,
    this.cost,
    this.stock,
    this.imageUrl,
    this.isDeleted = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? sku;
  final double? price;
  final double? cost;
  final int? stock;
  final String? imageUrl;
  final bool isDeleted;
  final String? createdAt;

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static double? _pickDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static int? _pickInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toInt();
    }
    return null;
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: _pickString(map, ['name', 'title', 'product_name']) ?? 'Untitled product',
      description: _pickString(map, ['description', 'desc', 'details']),
      category: _pickString(map, ['category', 'category_name', 'type']),
      sku: _pickString(map, ['sku', 'code', 'product_code']),
      price: _pickDouble(map, ['price', 'selling_price', 'unit_price']),
      cost: _pickDouble(map, ['cost', 'unit_cost', 'cost_price']),
      stock: _pickInt(map, ['stock', 'quantity', 'stock_quantity', 'qty']),
      imageUrl: _pickString(map, ['image_url', 'imageUrl', 'photo_url', 'image']),
      isDeleted: map['is_deleted'] == true,
      createdAt: _pickString(map, ['created_at']),
    );
  }

  /// Canonical field names used when this admin portal itself creates or
  /// edits a product, matching the snake_case convention the rest of this
  /// schema (staff_limit, unit_cost, image_url, ...) already uses.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'sku': sku,
      'price': price,
      'cost': cost,
      'stock': stock,
      'image_url': imageUrl,
      'is_deleted': isDeleted,
      'created_at': createdAt,
    };
  }
}
