import 'package:flutter/material.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/core/widgets/info_row.dart';
import 'package:zonixweb/features/shops/models/product.dart';
import 'package:zonixweb/features/shops/widgets/products/product_image.dart';

class ProductDetailDialog extends StatelessWidget {
  const ProductDetailDialog({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outOfStock = product.stock != null && product.stock! <= 0;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ProductImage(url: product.imageUrl),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.category!,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (product.price != null)
                          Expanded(
                            child: ProductDetailStat(
                              label: 'Price',
                              value: formatMoney(product.price!),
                            ),
                          ),
                        if (product.cost != null)
                          Expanded(
                            child: ProductDetailStat(
                              label: 'Cost',
                              value: formatMoney(product.cost!),
                            ),
                          ),
                        if (product.stock != null)
                          Expanded(
                            child: ProductDetailStat(
                              label: 'Stock',
                              value: outOfStock
                                  ? 'Out of stock'
                                  : '${product.stock}',
                              valueColor: outOfStock ? colorScheme.error : null,
                            ),
                          ),
                      ],
                    ),
                    if (product.sku != null) ...[
                      const SizedBox(height: 14),
                      InfoRow(
                        icon: Icons.qr_code_outlined,
                        label: 'SKU',
                        value: product.sku!,
                      ),
                    ],
                    if (product.description != null &&
                        product.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Text(
                        product.description!,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailStat extends StatelessWidget {
  const ProductDetailStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
