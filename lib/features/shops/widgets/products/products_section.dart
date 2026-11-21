import 'package:flutter/material.dart';
import 'package:zonixweb/features/shops/models/product.dart';
import 'package:zonixweb/features/shops/widgets/products/product_card.dart';
import 'package:zonixweb/features/shops/widgets/products/product_detail_dialog.dart';

class ProductsSection extends StatelessWidget {
  const ProductsSection({
    super.key,
    required this.loading,
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  final bool loading;
  final List<Product> products;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No products yet.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final product in products)
          ProductCard(
            product: product,
            onTap: () => showDialog(
              context: context,
              builder: (_) => ProductDetailDialog(product: product),
            ),
            onEdit: () => onEdit(product),
            onDelete: () => onDelete(product),
          ),
      ],
    );
  }
}
