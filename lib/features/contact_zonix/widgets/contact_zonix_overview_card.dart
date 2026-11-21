import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/status_pill.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
import 'package:zonixweb/features/contact_zonix/services/contact_request_service.dart';
import 'package:zonixweb/features/contact_zonix/services/join_contact_config_service.dart';

/// Platform overview card: whether phone contact / the request form are on,
/// and how many requests are waiting, linking to the Requests inbox.
class ContactZonixOverviewCard extends StatelessWidget {
  const ContactZonixOverviewCard({super.key, required this.onOpenRequests});

  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        joinContactConfigFeed,
        contactRequestsFeed,
      ]),
      builder: (context, _) {
        final config = joinContactConfigFeed.value;
        final newCount = newContactRequestCount();

        Widget pill(String label, bool? on) {
          final (fg, bg) = switch (on) {
            true => (
              ZonixColors.onEmeraldContainer,
              ZonixColors.emeraldContainer,
            ),
            false => (
              colorScheme.onSurfaceVariant,
              colorScheme.surfaceContainerHighest,
            ),
            null => (
              colorScheme.onSurfaceVariant,
              colorScheme.surfaceContainerHighest,
            ),
          };
          return StatusPill(
            label:
                '$label: ${on == null
                    ? '—'
                    : on
                    ? 'On'
                    : 'Off'}',
            fg: fg,
            bg: bg,
          );
        }

        return HoloPanel(
          icon: Icons.support_agent_rounded,
          tag: 'Onboarding',
          title: 'Contact Zonix',
          subtitle: config == null
              ? 'Settings not loaded'
              : config.hiddenInApp
              ? 'Hidden in the app'
              : 'Shown on the shop code screen',
          trailing: TextButton.icon(
            onPressed: onOpenRequests,
            icon: Badge(
              isLabelVisible: newCount > 0,
              label: Text('$newCount'),
              child: const Icon(Icons.inbox_outlined),
            ),
            label: const Text('Requests'),
          ),
          child: Wrap(
            spacing: AppDimens.spacing8,
            runSpacing: AppDimens.spacing8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              pill('Phone contact', config?.showsPhone),
              pill('Request form', config?.showsForm),
              Text(
                newCount == 0
                    ? 'No new requests'
                    : '$newCount new request${newCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
