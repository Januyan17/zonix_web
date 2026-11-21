import 'package:zonixweb/features/shops/models/shop.dart';

class ShopListEntry {
  const ShopListEntry({
    required this.slug,
    required this.indexedName,
    required this.shop,
  });

  final String slug;
  final String indexedName;
  final Shop? shop;
}
