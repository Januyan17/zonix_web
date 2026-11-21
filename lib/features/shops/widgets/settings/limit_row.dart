import 'package:flutter/material.dart';

/// A "used / limit" row with an inline edit button.
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
