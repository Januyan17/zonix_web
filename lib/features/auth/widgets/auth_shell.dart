import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/zonix_badge.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';

/// Shared branded card layout for the signup and login screens.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: ZonixColors.navy,
      body: Stack(
        children: [
          const Positioned.fill(child: ZonixHeaderBackground(hairline: false)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spacing16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 380;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: ZonixColors.cyan.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZonixColors.cyan.withValues(alpha: 0.28),
                            blurRadius: 48,
                            spreadRadius: -6,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 40,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          narrow ? 20 : 32,
                          narrow ? 24 : 36,
                          narrow ? 20 : 32,
                          narrow ? 20 : 32,
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: ZonixBadge(
                                  size: narrow ? 96 : 112,
                                  showLabel: true,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spacing24),
                              Text(
                                title,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spacing4),
                              Text(
                                subtitle,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 28),
                              ...children,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
