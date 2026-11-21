import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/features/contact_zonix/utils/sri_lanka_phone.dart';

/// What the mobile app's "Contact Zonix" sheet shows for a combination of
/// the two toggles:
///   phone ON  + form OFF → number, Call Now, WhatsApp
///   phone OFF + form ON  → only "Send a Request"
///   both ON              → number, Call Now, WhatsApp, "or", Send a Request
///   both OFF             → the tile is hidden entirely
/// Phone ON with an empty number counts as phone OFF. Buttons are inert.
class JoinContactPreview extends StatelessWidget {
  const JoinContactPreview({
    super.key,
    required this.phoneEnabled,
    required this.phone,
    required this.requestFormEnabled,
    required this.message,
  });

  final bool phoneEnabled;
  final String phone;
  final bool requestFormEnabled;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showsPhone = phoneEnabled && phone.trim().isNotEmpty;
    final showsForm = requestFormEnabled;
    final muted = TextStyle(
      fontStyle: FontStyle.italic,
      color: colorScheme.onSurfaceVariant,
    );

    if (!showsPhone && !showsForm) {
      return Container(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        child: Column(
          children: [
            Icon(Icons.visibility_off_outlined, color: colorScheme.outline),
            const SizedBox(height: AppDimens.spacing8),
            const Text(
              'Hidden in the app',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              phoneEnabled && phone.trim().isEmpty
                  ? 'Phone contact is on but has no number, so it counts as '
                        'off. The "Contact Zonix" tile is not shown.'
                  : 'Both are off, so the "Contact Zonix" tile is not shown '
                        'on the shop code screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final defaultText = switch ((showsPhone, showsForm)) {
      (true, false) => "(App's default text for phone contact)",
      (false, true) => "(App's default text for the request form)",
      _ => "(App's default text for phone and request form)",
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          elevation: 6,
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
            bottom: Radius.circular(12),
          ),
          child: Padding(
            padding: AppDimens.paddingAll20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spacing16),
                const Text(
                  'Contact Zonix',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ZonixColors.navy,
                  ),
                ),
                const SizedBox(height: AppDimens.spacing8),
                Text(
                  message.trim().isEmpty ? defaultText : message.trim(),
                  textAlign: TextAlign.center,
                  style: message.trim().isEmpty ? muted : null,
                ),
                if (showsPhone) ...[
                  const SizedBox(height: AppDimens.spacing16),
                  Text(
                    displaySriLankaPhone(phone),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacing12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call Now'),
                        ),
                      ),
                      const SizedBox(width: AppDimens.spacing10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (showsPhone && showsForm) ...[
                  const SizedBox(height: AppDimens.spacing12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spacing8,
                        ),
                        child: Text('or', style: muted),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ],
                if (showsForm) ...[
                  const SizedBox(height: AppDimens.spacing12),
                  FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Send a Request'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
