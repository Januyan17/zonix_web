import 'package:flutter/material.dart';

class LimitResult {
  const LimitResult(this.limit);

  final int? limit;
}

/// Editor for a "max N the owner can create from the mobile app" limit.
class LimitDialog extends StatefulWidget {
  const LimitDialog({
    super.key,
    required this.title,
    required this.description,
    required this.fieldLabel,
    required this.currentLimit,
  });

  final String title;
  final String description;
  final String fieldLabel;
  final int? currentLimit;

  @override
  State<LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<LimitDialog> {
  late bool _unlimited = widget.currentLimit == null;
  late final _controller = TextEditingController(
    text: widget.currentLimit == null ? '' : '${widget.currentLimit}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unlimited'),
            value: _unlimited,
            onChanged: (v) => setState(() => _unlimited = v),
          ),
          if (!_unlimited)
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: widget.fieldLabel),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_unlimited) {
              Navigator.of(context).pop(const LimitResult(null));
              return;
            }
            final value = int.tryParse(_controller.text.trim());
            if (value == null || value < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid number')),
              );
              return;
            }
            Navigator.of(context).pop(LimitResult(value));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
