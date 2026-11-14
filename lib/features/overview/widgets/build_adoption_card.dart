import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/info_note.dart';
import 'package:zonixweb/features/app_version/models/app_version_config.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';

/// Which build each device is on, cross-referenced against the published
/// update gate. Empty until the mobile app starts writing its build number
/// onto the user document it already syncs — which is a change in the app
/// repo, not here, so the card says so instead of showing a blank chart.
class BuildAdoptionCard extends StatelessWidget {
  const BuildAdoptionCard({
    super.key,
    required this.builds,
    required this.config,
  });

  final BuildAdoption builds;
  final AppVersionConfig? config;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update adoption',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'Which build each device is on, so raising the floor on the '
              'App Version page stops being a guess.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing14),
            if (!builds.hasData)
              InfoNote(
                icon: Icons.info_outline,
                text:
                    'No device reports a build number yet '
                    '(${builds.usersWithoutBuild} user record'
                    '${builds.usersWithoutBuild == 1 ? '' : 's'} checked). '
                    'This fills in on its own once the mobile app writes its '
                    'build number onto shops/{shopId}/users/{uid} — a change '
                    'in the app repo, not this one.',
              )
            else ...[
              for (final build in builds.buildsDescending) ...[
                _BuildRow(
                  buildNumber: build,
                  devices: builds.devicesByBuild[build]!,
                  totalDevices: builds.reportingDevices,
                  config: config,
                ),
                const SizedBox(height: AppDimens.spacing10),
              ],
              if (config != null && config!.minSupportedBuild > 0) ...[
                const Divider(height: AppDimens.spacing20),
                Text(
                  'The published floor is build ${config!.minSupportedBuild}. '
                  '${builds.blockedBy(config!.minSupportedBuild)} of '
                  '${builds.reportingDevices} reporting devices would be '
                  'blocked right now.',
                  style: TextStyle(
                    fontSize: AppDimens.fontBody,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (builds.usersWithoutBuild > 0) ...[
                const SizedBox(height: AppDimens.spacing8),
                Text(
                  '${builds.usersWithoutBuild} user record'
                  '${builds.usersWithoutBuild == 1 ? '' : 's'} report no '
                  'build — most likely a device that has not signed in since '
                  'build reporting shipped.',
                  style: TextStyle(
                    fontSize: AppDimens.fontCaption,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({
    required this.buildNumber,
    required this.devices,
    required this.totalDevices,
    required this.config,
  });

  final int buildNumber;
  final int devices;
  final int totalDevices;
  final AppVersionConfig? config;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final min = config?.minSupportedBuild ?? 0;
    final latest = config?.latestBuild ?? 0;

    // Reserved status colors, each paired with an icon and words.
    final (IconData icon, Color color, String note) = buildNumber < min
        ? (Icons.block_rounded, colorScheme.error, 'blocked now')
        : (buildNumber < latest
              ? (
                  Icons.arrow_upward_rounded,
                  ZonixColors.onCyanContainer,
                  'update available',
                )
              : (
                  Icons.check_circle_outline,
                  colorScheme.onTertiaryContainer,
                  'current',
                ));

    return Row(
      children: [
        Icon(icon, size: AppDimens.iconSm, color: color),
        const SizedBox(width: AppDimens.spacing8),
        SizedBox(
          width: 96,
          child: Text(
            'Build $buildNumber',
            style: const TextStyle(
              fontSize: AppDimens.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
            child: LinearProgressIndicator(
              value: totalDevices == 0 ? 0 : devices / totalDevices,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacing12),
        SizedBox(
          width: 128,
          child: Text(
            '$devices device${devices == 1 ? '' : 's'} · $note',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: AppDimens.fontCaption,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
