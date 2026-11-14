import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/credential_row.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

class ShopCreatedView extends StatelessWidget {
  const ShopCreatedView({super.key, required this.result});

  final ShopCreationResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Shop created')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spacing24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.check_rounded,
                            color: colorScheme.onTertiaryContainer,
                            size: AppDimens.icon2xl,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacing16),
                      Text(
                        'Shop "${result.slug}" created',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimens.spacing8),
                      Text(
                        'The owner account starts disabled — enable it from the '
                        'shop\'s user list before relaying these credentials so '
                        'they can log into the mobile app:',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimens.spacing20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusLarge,
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
