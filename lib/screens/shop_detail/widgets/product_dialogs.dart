import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/product.dart';
import '../../../utils/money_format.dart';
import 'info_rows.dart';
import 'product_widgets.dart';

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

class ProductFormResult {
  const ProductFormResult({
    required this.name,
    this.description,
    this.category,
    this.sku,
    this.price,
    this.cost,
    this.stock,
    this.newImageBytes,
    this.newImageExt,
  });

  final String name;
  final String? description;
  final String? category;
  final String? sku;
  final double? price;
  final double? cost;
  final int? stock;

  /// Null means "no new image picked" — on edit, the product keeps its
  /// existing image; on add, it's created with no image.
  final Uint8List? newImageBytes;
  final String? newImageExt;
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.product});

  /// Null for "add product"; set for "edit product".
  final Product? product;

  @override
  State<ProductFormDialog> createState() => ProductFormDialogState();
}

class ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.product?.name ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _categoryController = TextEditingController(
    text: widget.product?.category ?? '',
  );
  late final _skuController = TextEditingController(
    text: widget.product?.sku ?? '',
  );
  late final _priceController = TextEditingController(
    text: widget.product?.price == null ? '' : '${widget.product!.price}',
  );
  late final _costController = TextEditingController(
    text: widget.product?.cost == null ? '' : '${widget.product!.cost}',
  );
  late final _stockController = TextEditingController(
    text: widget.product?.stock == null ? '' : '${widget.product!.stock}',
  );

  Uint8List? _pickedBytes;
  String? _pickedExt;
  bool _picking = false;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      if (mounted) {
        setState(() {
          _pickedBytes = bytes;
          _pickedExt = ext;
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final existingImageUrl = widget.product?.imageUrl;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DialogHeader(
                    icon: _isEdit
                        ? Icons.edit_outlined
                        : Icons.add_box_outlined,
                    title: _isEdit ? 'Edit product' : 'Add product',
                    subtitle: _isEdit
                        ? 'Updates this product in the shop\'s catalog'
                        : 'Creates a new product in the shop\'s catalog',
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: InkWell(
                      onTap: _picking ? null : _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 120,
                        height: 120,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _picking
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : _pickedBytes != null
                            ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                            : existingImageUrl != null
                            ? ProductImage(url: existingImageUrl)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add photo',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (existingImageUrl != null || _pickedBytes != null) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _picking ? null : _pickImage,
                        child: const Text('Change photo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(labelText: 'SKU'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Price'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.trim()) == null
                                ? 'Invalid'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(labelText: 'Cost'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.trim()) == null
                                ? 'Invalid'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(labelText: 'Stock'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null
                                ? 'Invalid'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          String? text(TextEditingController c) =>
                              c.text.trim().isEmpty ? null : c.text.trim();
                          Navigator.of(context).pop(
                            ProductFormResult(
                              name: _nameController.text.trim(),
                              description: text(_descriptionController),
                              category: text(_categoryController),
                              sku: text(_skuController),
                              price: double.tryParse(
                                _priceController.text.trim(),
                              ),
                              cost: double.tryParse(
                                _costController.text.trim(),
                              ),
                              stock: int.tryParse(_stockController.text.trim()),
                              newImageBytes: _pickedBytes,
                              newImageExt: _pickedExt,
                            ),
                          );
                        },
                        icon: Icon(_isEdit ? Icons.check : Icons.add, size: 18),
                        label: Text(_isEdit ? 'Save' : 'Add product'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
