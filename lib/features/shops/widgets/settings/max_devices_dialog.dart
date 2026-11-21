import 'package:flutter/material.dart';
import 'package:zonixweb/features/shops/widgets/settings/limit_dialog.dart';

class MaxDevicesResult {
  const MaxDevicesResult({required this.staff, required this.owner});

  final int staff;
  final int owner;
}

/// Editor for the shop's two max-active-devices settings — staff and
/// owner/admin — each a required non-negative numeric value (0 blocks that
/// role from logging in at all; no "unlimited" option, unlike [LimitDialog]).
/// Saved together in one write.
class MaxDevicesDialog extends StatefulWidget {
  const MaxDevicesDialog({
    super.key,
    required this.currentStaff,
    required this.currentOwner,
  });

  final int currentStaff;
  final int currentOwner;

  @override
  State<MaxDevicesDialog> createState() => _MaxDevicesDialogState();
}

class _MaxDevicesDialogState extends State<MaxDevicesDialog> {
  late final _staffController = TextEditingController(
    text: '${widget.currentStaff}',
  );
  late final _ownerController = TextEditingController(
    text: '${widget.currentOwner}',
  );

  @override
  void dispose() {
    _staffController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Max active devices'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Max number of devices an account can be signed in on at once. '
            'Signing in on a new device beyond the limit signs out the '
            'oldest session(s). Set to 0 to block that role from logging in '
            'at all.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _staffController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Max devices — Staff'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max devices — Owner/Admin',
            ),
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
            final staff = int.tryParse(_staffController.text.trim());
            final owner = int.tryParse(_ownerController.text.trim());
            if (staff == null || staff < 0 || owner == null || owner < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter numbers of 0 or more')),
              );
              return;
            }
            Navigator.of(
              context,
            ).pop(MaxDevicesResult(staff: staff, owner: owner));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
