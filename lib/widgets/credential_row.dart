import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_dimens.dart';

/// A labeled, copyable value row — used for showing generated credentials
/// (shop code, username, password) with an optional show/hide toggle for
/// sensitive values like passwords.
class CredentialRow extends StatefulWidget {
  const CredentialRow({
    super.key,
    required this.label,
    required this.value,
    this.isSensitive = false,
  });

  final String label;
  final String value;
  final bool isSensitive;

  @override
  State<CredentialRow> createState() => _CredentialRowState();
}

class _CredentialRowState extends State<CredentialRow> {
  late bool _hidden = widget.isSensitive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = _hidden ? '•' * widget.value.length : widget.value;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spacing8,
        horizontal: AppDimens.spacing8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppDimens.labelColumnWidth,
            child: Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
                fontSize: AppDimens.fontBody,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              displayValue,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (widget.isSensitive)
            IconButton(
              icon: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: AppDimens.iconLg,
              ),
              tooltip: _hidden ? 'Show' : 'Hide',
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: AppDimens.iconLg),
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.label} copied'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
