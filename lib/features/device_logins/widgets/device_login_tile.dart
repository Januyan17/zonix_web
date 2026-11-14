import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/widgets/status_pill.dart';
import 'package:zonixweb/features/device_logins/models/device_login.dart';

/// One device-login row: when, which shop, who, and on what device/build,
/// with the "Old build" / "Repeat install" badges. Shared by the Device
/// logins screen and the shop detail page's recent-logins section.
class DeviceLoginTile extends StatelessWidget {
  const DeviceLoginTile({
    super.key,
    required this.login,
    this.oldBuild = false,
    this.repeatInstall = false,
    this.showShop = true,
  });

  final DeviceLogin login;
  final bool oldBuild;
  final bool repeatInstall;

  /// Hidden on the shop detail page, where every row is the same shop.
  final bool showShop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final createdAt = login.createdAt;
    final isIos = login.platform.toLowerCase() == 'ios';

    final deviceParts = [
      if (login.deviceName.isNotEmpty) login.deviceName,
      if (login.osVersion.isNotEmpty) login.osVersion,
    ];
    final buildText = [
      if (login.appVersion.isNotEmpty) 'v${login.appVersion}',
      if (login.appBuild != null) '(build ${login.appBuild})',
    ].join(' ');

    final secondary = TextStyle(
      fontSize: AppDimens.fontBody,
      color: colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: AppDimens.paddingH16V12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppDimens.iconBadgeLg,
            height: AppDimens.iconBadgeLg,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            ),
            alignment: Alignment.center,
            child: Icon(
              isIos ? Icons.phone_iphone_rounded : Icons.android_rounded,
              size: AppDimens.iconXl,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppDimens.spacing14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppDimens.spacing8,
                  runSpacing: AppDimens.spacing4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      login.userLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppDimens.fontBodyLg,
                      ),
                    ),
                    if (login.role.isNotEmpty)
                      StatusPill(
                        label: login.role,
                        fg: colorScheme.onSurfaceVariant,
                        bg: colorScheme.surfaceContainerHighest,
                      ),
                    if (oldBuild)
                      StatusPill(
                        label: 'Old build',
                        icon: Icons.system_update_rounded,
                        fg: colorScheme.onErrorContainer,
                        bg: colorScheme.errorContainer,
                      ),
                    if (repeatInstall)
                      StatusPill(
                        label: 'Repeat install',
                        icon: Icons.replay_rounded,
                        fg: colorScheme.onTertiaryContainer,
                        bg: colorScheme.tertiaryContainer.withValues(
                          alpha: 0.6,
                        ),
                      ),
                  ],
                ),
                if (showShop) ...[
                  const SizedBox(height: AppDimens.spacing2),
                  Text(
                    login.shopLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: AppDimens.spacing2),
                Text(
                  [
                    deviceParts.isEmpty
                        ? 'Unknown device'
                        : deviceParts.join(' · '),
                    if (buildText.isNotEmpty) buildText,
                  ].join(' · '),
                  style: secondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spacing12),
          Text(
            createdAt == null ? '—' : formatShortDateTime(createdAt),
            style: TextStyle(
              fontSize: AppDimens.fontLabel,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
