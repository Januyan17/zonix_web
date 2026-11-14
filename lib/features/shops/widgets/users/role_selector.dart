import 'package:flutter/material.dart';

class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'staff',
          label: Text('Staff'),
          icon: Icon(Icons.badge_outlined, size: 17),
        ),
        ButtonSegment(
          value: 'owner',
          label: Text('Owner'),
          icon: Icon(Icons.workspace_premium_outlined, size: 17),
        ),
      ],
      selected: {role},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}
