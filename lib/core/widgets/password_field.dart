import 'package:flutter/material.dart';

/// Password input with a visibility-toggle icon, shared by the add-user and
/// reissue-login dialogs. Owns its own obscure/reveal state.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      obscureText: _obscureText,
      validator: (v) =>
          (v == null || v.length < 6) ? 'At least 6 characters' : null,
    );
  }
}
