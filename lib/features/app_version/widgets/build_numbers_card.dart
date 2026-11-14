import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/app_version/utils/app_version_validation.dart';

/// The two build-number settings of the update gate, each explained in
/// plain words, with a live preview of what every build will see.
class BuildNumbersCard extends StatelessWidget {
  const BuildNumbersCard({
    super.key,
    required this.minController,
    required this.latestController,
    required this.onLatestChanged,
  });

  final TextEditingController minController;
  final TextEditingController latestController;

  /// The order error belongs to the pair, so editing the latest build has
  /// to revalidate the floor too.
  final VoidCallback onLatestChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.numbers_rounded,
              label: 'Build numbers',
            ),
            const SizedBox(height: AppDimens.spacing8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text:
                        'A build number is the whole number after the "+" '
                        'in the app version. For version ',
                  ),
                  TextSpan(
                    text: '1.0.3+7',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(text: ' the build number is '),
                  TextSpan(
                    text: '7',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '. Enter that number here, never the dotted '
                        '"1.0.3" part. The same numbers apply to Android '
                        'and iOS.',
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing20),
            _BuildField(
              icon: Icons.block_rounded,
              color: colorScheme.error,
              tint: colorScheme.errorContainer,
              title: 'Minimum allowed build',
              tag: 'Forced update',
              description:
                  'Anyone on a build lower than this is locked out with a '
                  'full-screen "Update required" until they update. Enter 0 '
                  'to lock out nobody.',
              field: TextFormField(
                controller: minController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Minimum build number',
                  errorMaxLines: 3,
                ),
                validator: (v) {
                  final error = buildNumberError(v, min: 0);
                  if (error != null) return error;
                  final latest = int.tryParse(latestController.text.trim());
                  if (latest == null) return null;
                  return buildOrderError(
                    minSupportedBuild: int.parse(v!.trim()),
                    latestBuild: latest,
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.spacing16),
              child: Divider(height: 1),
            ),
            _BuildField(
              icon: Icons.upgrade_rounded,
              color: ZonixColors.chartBlue,
              tint: ZonixColors.cyanContainer,
              title: 'Latest released build',
              tag: 'Update prompt',
              description:
                  'The newest build people can download. Anyone on a lower '
                  'build gets an "Update available" prompt when they open '
                  'the app. It cannot be closed: they update, or tap "Check '
                  'again" once they have.',
              field: TextFormField(
                controller: latestController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Latest build number',
                  errorMaxLines: 3,
                ),
                onChanged: (_) => onLatestChanged(),
                validator: (v) => buildNumberError(v, min: 1),
              ),
            ),
            const SizedBox(height: AppDimens.spacing20),
            ListenableBuilder(
              listenable: Listenable.merge([minController, latestController]),
              builder: (context, _) => _ImpactPreview(
                min: int.tryParse(minController.text.trim()),
                latest: int.tryParse(latestController.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildField extends StatelessWidget {
  const _BuildField({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.tag,
    required this.description,
    required this.field,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String tag;
  final String description;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppDimens.iconBadgeLg,
          height: AppDimens.iconBadgeLg,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: AppDimens.iconXl, color: color),
        ),
        const SizedBox(width: AppDimens.spacing12),
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
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacing8,
                      vertical: AppDimens.spacing2,
                    ),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusSmall,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: AppDimens.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spacing4),
              Text(
                description,
                style: TextStyle(
                  fontSize: AppDimens.fontBody,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.spacing12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: field,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "With these numbers, who sees what" — recomputed as the admin types.
class _ImpactPreview extends StatelessWidget {
  const _ImpactPreview({required this.min, required this.latest});

  final int? min;
  final int? latest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final min = this.min;
    final latest = this.latest;
    final valid = min != null && latest != null && latest >= 1 && min <= latest;

    return Container(
      padding: AppDimens.paddingAll14,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'With these numbers',
            style: TextStyle(
              fontSize: AppDimens.fontLabel,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.spacing10),
          if (!valid)
            Text(
              'Enter both build numbers to see who will be affected.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            _ImpactRow(
              icon: Icons.block_rounded,
              color: colorScheme.error,
              builds: min <= 0 ? 'No builds' : 'Builds below $min',
              outcome: min <= 0
                  ? 'Nobody is locked out'
                  : 'Locked out until they update',
            ),
            const SizedBox(height: AppDimens.spacing8),
            _ImpactRow(
              icon: Icons.upgrade_rounded,
              color: ZonixColors.chartBlue,
              builds: _promptedBuilds(min, latest),
              outcome: latest > min && latest > 1
                  ? 'Asked to update when they open the app'
                  : 'Nobody is asked to update',
            ),
            const SizedBox(height: AppDimens.spacing8),
            _ImpactRow(
              icon: Icons.check_circle_rounded,
              color: ZonixColors.emerald,
              builds: 'Build $latest and above',
              outcome: 'Up to date, see nothing',
            ),
          ],
        ],
      ),
    );
  }

  static String _promptedBuilds(int min, int latest) {
    if (latest <= min || latest <= 1) return 'No builds';
    if (min <= 0) return 'Builds below $latest';
    if (latest - 1 == min) return 'Build $min';
    return 'Builds $min to ${latest - 1}';
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.color,
    required this.builds,
    required this.outcome,
  });

  final IconData icon;
  final Color color;
  final String builds;
  final String outcome;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimens.iconLg, color: color),
        const SizedBox(width: AppDimens.spacing10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: builds,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(text: '  ·  $outcome'),
              ],
            ),
            style: TextStyle(
              fontSize: AppDimens.fontBody,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
