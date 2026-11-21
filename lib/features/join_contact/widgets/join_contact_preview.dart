import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';

/// A mock of the popup the mobile app shows when "Contact Zonix" is tapped:
/// the message, then the number in large bold text, then Copy and Call.
/// The buttons are for show only.
class JoinContactPreview extends StatelessWidget {
  const JoinContactPreview({
    super.key,
    required this.phone,
    required this.message,
  });

  final String phone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedStyle = TextStyle(
      fontStyle: FontStyle.italic,
      color: colorScheme.onSurfaceVariant,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surface,
          child: Padding(
            padding: AppDimens.paddingAll20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Contact Zonix',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppDimens.spacing12),
                Text(
                  message.trim().isEmpty
                      ? "(The app's default text)"
                      : message.trim(),
                  textAlign: TextAlign.center,
                  style: message.trim().isEmpty ? mutedStyle : null,
                ),
                const SizedBox(height: AppDimens.spacing16),
                SelectableText(
                  phone.trim().isEmpty ? 'No number set' : phone.trim(),
                  textAlign: TextAlign.center,
                  style: phone.trim().isEmpty
                      ? mutedStyle.copyWith(fontSize: 20)
                      : const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                ),
                const SizedBox(height: AppDimens.spacing20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spacing10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Call'),
                      ),
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
