import 'package:flutter/material.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/core/widgets/menu_row.dart';
import 'package:zonixweb/features/shops/models/product.dart';
import 'package:zonixweb/features/shops/widgets/products/product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outOfStock = product.stock != null && product.stock! <= 0;

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ProductImage(url: product.imageUrl),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: colorScheme.surface.withValues(alpha: 0.85),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: colorScheme.onSurface,
                        ),
                        tooltip: 'Product actions',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              onEdit();
                            case 'delete':
                              onDelete();
                          }
                        },
                        itemBuilder: (menuContext) {
                          final menuColors = Theme.of(menuContext).colorScheme;
                          return [
                            PopupMenuItem(
                              value: 'edit',
                              height: 40,
                              child: MenuRow(
                                icon: Icons.edit_outlined,
                                label: 'Edit',
                                color: menuColors.onSurface,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              height: 40,
                              child: MenuRow(
                                icon: Icons.delete_outline,
                                label: 'Delete',
                                color: menuColors.error,
                              ),
                            ),
                          ];
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    if (product.category != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.category!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          product.price != null
                              ? formatMoney(product.price!)
                              : '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        if (product.stock != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: outOfStock
                                  ? colorScheme.errorContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              outOfStock
                                  ? 'Out of stock'
                                  : '${product.stock} left',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: outOfStock
                                    ? colorScheme.onErrorContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
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
