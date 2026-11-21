import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/credential_row.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

class ShopCreatedView extends StatelessWidget {
  const ShopCreatedView({super.key, required this.result});

  final ShopCreationResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: zonixAppBar(title: 'Shop created', tag: 'Provisioned'),
      body: ZonixBackdrop(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spacing24),
                child: HoloPanel(
                  accent: ZonixColors.emerald,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: GlowIconTile(
                          icon: Icons.check_rounded,
                          accent: ZonixColors.emerald,
                          size: 68,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacing20),
                      Text(
                        'Shop "${result.slug}" created',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ZonixColors.navy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimens.spacing8),
                      Text(
                        'The owner account is enabled and can sign in right '
                        'away. Relay these credentials so they can log into '
                        'the mobile app:',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimens.spacing20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: ZonixColors.navyContainer.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusLarge,
                          ),
                          border: Border.all(
                            color: ZonixColors.cyan.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          children: [
                            CredentialRow(
                              label: 'Shop code',
                              value: result.slug,
                            ),
                            const Divider(height: 1),
                            CredentialRow(
                              label: 'Username',
                              value: result.ownerUsername,
                            ),
                            const Divider(height: 1),
                            CredentialRow(
                              label: 'Password',
                              value: result.ownerPassword,
                              isSensitive: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacing24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 52),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to shop list'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
