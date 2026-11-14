import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/widgets/info_row.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/app_version/models/app_version_config.dart';

/// What is live right now, so a second admin can see the state before
/// touching it.
class CurrentStateCard extends StatelessWidget {
  const CurrentStateCard({super.key, required this.saved});

  final AppVersionConfig? saved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = saved;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.fact_check_outlined,
              label: 'Currently live',
            ),
            const SizedBox(height: AppDimens.spacing16),
            if (config == null)
              Text(
                'No settings have been published yet — the '
                'platform_config/appVersion document does not exist. Until '
                'it does, the app blocks nobody, which is the correct '
                'default. Saving below creates it.',
                style: TextStyle(
                  fontSize: AppDimens.fontBody,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              InfoRow(
                icon: Icons.block_rounded,
                label: 'Blocking',
                value: config.minSupportedBuild == 0
                    ? 'Nobody (floor is 0)'
                    : 'Builds below ${config.minSupportedBuild}',
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.upgrade_rounded,
                label: 'Nudging',
                value: 'Builds below ${config.latestBuild}',
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.android_rounded,
                label: 'Android',
                value: config.androidDownloadUrl.isEmpty
                    ? 'Not set'
                    : config.androidDownloadUrl,
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.apple_rounded,
                label: 'iOS',
                value: config.iosDownloadUrl.isEmpty
                    ? 'Not set'
                    : config.iosDownloadUrl,
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.history_rounded,
                label: 'Last change',
                value: config.updatedAt == null
                    ? 'Unknown'
                    : '${formatRelativeDate(config.updatedAt!)} '
                          '(${formatShortDate(config.updatedAt!)})',
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.person_outline,
                label: 'Changed by',
                value: config.updatedBy ?? 'Unknown',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
