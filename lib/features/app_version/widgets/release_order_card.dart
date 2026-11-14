import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/section_header.dart';

/// Static help text. The order matters: raising the floor before the build
/// is actually downloadable locks every device out with nothing to install.
class ReleaseOrderCard extends StatelessWidget {
  const ReleaseOrderCard({super.key});

  static const _steps = [
    'Build the app, and note the build number after the "+" in pubspec.',
    'Upload the APK and open the link on a phone to confirm it downloads.',
    'Only then raise "Block versions below" here.',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.checklist_rtl_rounded,
              label: 'Release order',
            ),
            const SizedBox(height: AppDimens.spacing12),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spacing8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: AppDimens.fontCaption,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spacing10),
                    Expanded(
                      child: Text(
                        _steps[i],
                        style: const TextStyle(fontSize: AppDimens.fontBody),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
