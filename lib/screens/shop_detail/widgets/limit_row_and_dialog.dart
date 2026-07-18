import 'package:flutter/material.dart';

/// Shared "N / limit" row with an inline edit button, used for both the
/// staff limit and product limit displays — identical layout, only the
/// icon/label/unit text differs.
class LimitRow extends StatelessWidget {
  const LimitRow({
    super.key,
    required this.icon,
    required this.label,
    required this.unit,
    required this.limit,
    required this.used,
    required this.onEdit,
  });

  final IconData icon;
  final String label;
  final String unit;
  final int? limit;
  final int used;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final overLimit = limit != null && used > limit!;
    final valueText = limit == null ? 'Unlimited' : '$used / $limit $unit';

    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            valueText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: overLimit ? colorScheme.error : null,
            ),
          ),
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(
            minimumSize: const Size(40, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

/// A plain "label: value" row with an inline edit button, for a numeric
/// setting that (unlike [LimitRow]) has no usage count to display alongside
/// it — just the configured value.
class SettingValueRow extends StatelessWidget {
  const SettingValueRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(
            minimumSize: const Size(40, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

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

class LimitResult {
  const LimitResult(this.limit);

  final int? limit;
}

/// Shared "max N the owner can create from the mobile app" editor, used for
/// both the staff limit and product limit — identical behavior, only the
/// copy differs.
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
  State<LimitDialog> createState() => LimitDialogState();
}

class LimitDialogState extends State<LimitDialog> {
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
