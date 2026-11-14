import 'package:flutter/material.dart';
import 'package:zonixweb/core/widgets/dialog_header.dart';
import 'package:zonixweb/core/widgets/password_field.dart';
import 'package:zonixweb/features/shops/widgets/users/role_selector.dart';

class AddUserRequest {
  const AddUserRequest({
    required this.role,
    required this.displayName,
    required this.username,
    required this.password,
  });

  final String role;
  final String displayName;
  final String username;
  final String password;
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'staff';

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Add owner or staff',
                  subtitle: 'Creates a new login for this shop',
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
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
                          AddUserRequest(
                            role: _role,
                            displayName: _displayNameController.text.trim(),
                            username: _usernameController.text.trim(),
                            password: _passwordController.text,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add user'),
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
