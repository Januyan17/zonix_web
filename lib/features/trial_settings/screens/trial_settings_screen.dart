import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/page_header.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';
import 'package:zonixweb/features/shops/widgets/settings/trial_defaults_card.dart';

/// Platform-wide free-trial settings: the lock message and payment contact
/// every shop's trial-ended popup uses, set once instead of per shop.
class TrialSettingsScreen extends StatelessWidget {
  const TrialSettingsScreen({
    super.key,
    required this.authService,
    required this.shopService,
  });

  final AuthService authService;
  final ShopService shopService;

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: authService,
      shopService: shopService,
      current: AdminPage.trialSettings,
      body: SingleChildScrollView(
        padding: AppDimens.paddingAll24,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  icon: Icons.hourglass_top_rounded,
                  tag: 'Lifecycle',
                  title: 'Trial settings',
                  subtitle:
                      'Contact and message shown on the trial-ended popup '
                      'for all shops.',
                ),
                SizedBox(height: AppDimens.spacing20),
                TrialDefaultsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
