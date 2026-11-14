import 'package:flutter/material.dart';

class DeleteShopDialog extends StatefulWidget {
  const DeleteShopDialog({
    super.key,
    required this.slug,
    required this.shopName,
  });

  final String slug;
  final String shopName;

  @override
  State<DeleteShopDialog> createState() => _DeleteShopDialogState();
}

class _DeleteShopDialogState extends State<DeleteShopDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          const Expanded(child: Text('Delete this shop?')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes "${widget.shopName}" (${widget.slug}), '
            'its owner and staff records, and all products, sales, expenses, '
            'and income data. Staff will immediately lose access. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          Text(
            'Type the shop code "${widget.slug}" to confirm:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _matches = v == widget.slug),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}
