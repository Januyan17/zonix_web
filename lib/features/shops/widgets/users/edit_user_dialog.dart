import 'package:flutter/material.dart';
import 'package:zonixweb/core/widgets/dialog_header.dart';
import 'package:zonixweb/features/shops/models/shop_user.dart';
import 'package:zonixweb/features/shops/widgets/users/role_selector.dart';

class EditUserRequest {
  const EditUserRequest({
    required this.displayName,
    required this.role,
    required this.isEnabled,
  });

  final String displayName;
  final String role;
  final bool isEnabled;
}

class EditUserDialog extends StatefulWidget {
  const EditUserDialog({super.key, required this.user});

  final ShopUser user;

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _displayNameController = TextEditingController(
    text: widget.user.displayName,
  );
  late String _role = widget.user.role;
  late bool _isEnabled = widget.user.isEnabled;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DialogHeader(
                  icon: Icons.edit_outlined,
                  title: 'Edit user',
                  subtitle: widget.user.username,
                ),
                const SizedBox(height: 22),
                RoleSelector(
                  role: _role,
                  onChanged: (v) => setState(() => _role = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Material(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: SwitchListTile(
                    title: const Text('Enabled'),
                    subtitle: const Text(
                      'Disabled users keep their record but can\'t sign in',
                    ),
                    value: _isEnabled,
                    onChanged: (v) => setState(() => _isEnabled = v),
                  ),
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
                        Navigator.of(context).pop(
                          EditUserRequest(
                            displayName: _displayNameController.text.trim(),
                            role: _role,
                            isEnabled: _isEnabled,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
