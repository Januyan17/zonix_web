import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/widgets/status_pill.dart';
import 'package:zonixweb/features/device_logins/models/device_login.dart';
import 'package:zonixweb/features/device_logins/models/device_session.dart';
import 'package:zonixweb/features/device_logins/utils/device_grouping.dart';
import 'package:zonixweb/features/device_logins/utils/device_login_badges.dart';

/// One physical device: who, which shop, what model/build, whether it's
/// signed in right now and when it last logged in. Expands to the list of
/// app installs on it. Shared by the Device logins screen and the shop
/// detail page's recent-logins section.
class DeviceGroupTile extends StatefulWidget {
  const DeviceGroupTile({
    super.key,
    required this.group,
    this.sessions,
    this.sessionsLoading = false,
    this.minSupportedBuild,
    this.showShop = true,
    this.onDelete,
  });

  /// Called with the install records to delete: the whole device from the
  /// row's delete button, or one install from the history. Hidden when null.
  final ValueChanged<List<DeviceLogin>>? onDelete;

  final DeviceGroup group;

  /// The user's live sessions in this shop. Null while loading or when the
  /// lookup failed — the status is then shown as unknown, never "signed out".
  final List<DeviceSession>? sessions;
  final bool sessionsLoading;

  /// The forced-update floor; the latest install below it is "Old build".
  final int? minSupportedBuild;

  /// Hidden on the shop detail page, where every row is the same shop.
  final bool showShop;

  @override
  State<DeviceGroupTile> createState() => _DeviceGroupTileState();
}

class _DeviceGroupTileState extends State<DeviceGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final group = widget.group;
    final latest = group.latest;
    final session = group.activeSessionIn(widget.sessions);
    final signedIn = session != null;
    final statusKnown = widget.sessions != null;
    final isIos = latest.platform.toLowerCase() == 'ios';
    final canExpand = group.installCount > 1;
    final oldBuild = isOldBuild(
      appBuild: latest.appBuild,
      minSupportedBuild: widget.minSupportedBuild,
    );

    final secondary = TextStyle(
      fontSize: AppDimens.fontBody,
      color: colorScheme.onSurfaceVariant,
    );
    final success = Colors.green.shade700;

    final deviceParts = [
      if (latest.deviceName.isNotEmpty) latest.deviceName,
      if (latest.osVersion.isNotEmpty) latest.osVersion,
    ];

    // Right-hand timestamp: the latest login when signed in (sessions are
    // rewritten on every login), otherwise the latest install.
    final DateTime? when = session?.loggedInAt ?? latest.createdAt;
    final whenLabel = signedIn ? 'Last login' : 'Last install';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: canExpand
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: AppDimens.paddingH16V12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DeviceIcon(isIos: isIos, signedIn: signedIn),
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
                            latest.userLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: AppDimens.fontBodyLg,
                            ),
                          ),
                          if (latest.role.isNotEmpty)
                            _RolePill(role: latest.role),
                          if (signedIn)
                            StatusPill(
                              label: 'Signed in',
                              icon: Icons.circle,
                              fg: success,
                              bg: success.withValues(alpha: 0.12),
                            )
                          else if (statusKnown)
                            StatusPill(
                              label: 'Signed out',
                              icon: Icons.circle_outlined,
                              fg: colorScheme.onSurfaceVariant,
                              bg: colorScheme.surfaceContainerHighest,
                            ),
                          if (group.installCount > 1)
                            StatusPill(
                              label: '${group.installCount} installs',
                              icon: Icons.replay_rounded,
                              fg: colorScheme.onTertiaryContainer,
                              bg: colorScheme.tertiaryContainer.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          if (oldBuild)
                            StatusPill(
                              label: 'Old build',
                              icon: Icons.system_update_rounded,
                              fg: colorScheme.onErrorContainer,
                              bg: colorScheme.errorContainer,
                            ),
                        ],
                      ),
                      if (widget.showShop) ...[
                        const SizedBox(height: AppDimens.spacing2),
                        Text(
                          latest.shopLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: secondary.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimens.spacing2),
                      Text(
                        [
                          deviceParts.isEmpty
                              ? 'Unknown device'
                              : deviceParts.join(' · '),
                          if (_buildText(latest).isNotEmpty) _buildText(latest),
                        ].join(' · '),
                        style: secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spacing12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      whenLabel,
                      style: TextStyle(
                        fontSize: AppDimens.fontCaption,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Tooltip(
                      message: when == null ? '' : formatShortDateTime(when),
                      child: Text(
                        when == null ? '—' : formatRelativeDate(when),
                        style: TextStyle(
                          fontSize: AppDimens.fontLabel,
                          fontWeight: FontWeight.w600,
                          color: signedIn ? success : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (widget.sessionsLoading && !statusKnown)
                      const Padding(
                        padding: EdgeInsets.only(top: AppDimens.spacing4),
                        child: SizedBox(
                          width: AppDimens.iconXs,
                          height: AppDimens.iconXs,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ),
                    if (widget.onDelete != null)
                      IconButton(
                        tooltip: 'Delete this device\'s history',
                        visualDensity: VisualDensity.compact,
                        iconSize: AppDimens.iconLg,
                        color: colorScheme.error,
                        onPressed: () => widget.onDelete!(group.records),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    if (canExpand)
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (canExpand && _expanded)
          _InstallHistory(
            installs: group.installs,
            activeDeviceId: session?.deviceId,
            onDelete: widget.onDelete == null
                ? null
                : (install) => widget.onDelete!(group.recordsOf(install)),
          ),
      ],
    );
  }
}

/// "Owner" (the shop's admin) or "Staff", coloured so the two read apart
/// at a glance. Any other value is shown as-is in neutral colours.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (role.toLowerCase()) {
      'owner' => StatusPill(
        label: 'Owner',
        icon: Icons.admin_panel_settings_rounded,
        fg: colorScheme.onPrimaryContainer,
        bg: colorScheme.primaryContainer,
      ),
      'staff' => StatusPill(
        label: 'Staff',
        icon: Icons.badge_outlined,
        fg: colorScheme.onSecondaryContainer,
        bg: colorScheme.secondaryContainer,
      ),
      _ => StatusPill(
        label: role,
        fg: colorScheme.onSurfaceVariant,
        bg: colorScheme.surfaceContainerHighest,
      ),
    };
  }
}

String _buildText(DeviceLogin login) => [
  if (login.appVersion.isNotEmpty) 'v${login.appVersion}',
  if (login.appBuild != null) '(build ${login.appBuild})',
].join(' ');

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.isIos, required this.signedIn});

  final bool isIos;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: AppDimens.iconBadgeLg,
      height: AppDimens.iconBadgeLg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
          if (signedIn)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The installs on one device, newest first, marking the one currently
/// signed in.
class _InstallHistory extends StatelessWidget {
  const _InstallHistory({
    required this.installs,
    this.activeDeviceId,
    this.onDelete,
  });

  final List<DeviceLogin> installs;
  final String? activeDeviceId;
  final ValueChanged<DeviceLogin>? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: AppDimens.fontBody,
      color: colorScheme.onSurfaceVariant,
    );
    return Container(
      color: colorScheme.surfaceContainerLow,
      // Indented to line up with the text column above.
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacing16 + AppDimens.iconBadgeLg + AppDimens.spacing14,
        AppDimens.spacing8,
        AppDimens.spacing16,
        AppDimens.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Install history',
            style: style.copyWith(
              fontSize: AppDimens.fontLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spacing6),
          for (final install in installs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2),
              child: Row(
                children: [
                  Icon(
                    install.deviceId.isNotEmpty &&
                            install.deviceId == activeDeviceId
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 8,
                    color:
                        install.deviceId.isNotEmpty &&
                            install.deviceId == activeDeviceId
                        ? Colors.green.shade600
                        : colorScheme.outline,
                  ),
                  const SizedBox(width: AppDimens.spacing8),
                  Expanded(
                    child: Text(
                      [
                        install.createdAt == null
                            ? '—'
                            : formatShortDateTime(install.createdAt!),
                        if (_buildText(install).isNotEmpty) _buildText(install),
                        if (install.osVersion.isNotEmpty) install.osVersion,
                        if (install.deviceId.isNotEmpty &&
                            install.deviceId == activeDeviceId)
                          'current',
                      ].join(' · '),
                      style: style,
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete this install record',
                      visualDensity: VisualDensity.compact,
                      iconSize: AppDimens.iconSm,
                      color: colorScheme.onSurfaceVariant,
                      onPressed: () => onDelete!(install),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
