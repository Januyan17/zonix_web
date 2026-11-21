import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/contact_zonix/screens/contact_requests_screen.dart';
import 'package:zonixweb/features/contact_zonix/screens/contact_zonix_settings_screen.dart';
import 'package:zonixweb/features/contact_zonix/services/contact_request_service.dart';
import 'package:zonixweb/features/contact_zonix/services/supabase_admin_check.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

/// "Contact Zonix": the button on the mobile app's shop code screen, for
/// shops that want to join. Two tabs, both backed by Supabase (never
/// Firestore): Settings (`join_contact_config`) and Requests
/// (`contact_requests`).
class ContactZonixScreen extends StatefulWidget {
  const ContactZonixScreen({
    super.key,
    required this.authService,
    required this.shopService,
    this.initialTab = 0,
  });

  final AuthService authService;
  final ShopService shopService;

  /// 0 = Settings, 1 = Requests.
  final int initialTab;

  @override
  State<ContactZonixScreen> createState() => _ContactZonixScreenState();
}

class _ContactZonixScreenState extends State<ContactZonixScreen> {
  /// `is_platform_admin()` for this page load; null while checking.
  bool? _adminRecognised;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    if (_adminRecognised != null) setState(() => _adminRecognised = null);
    final ok = await supabaseRecognisesAdmin();
    if (mounted) setState(() => _adminRecognised = ok);
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: widget.authService,
      shopService: widget.shopService,
      current: AdminPage.contactZonix,
      body: DefaultTabController(
        length: 2,
        initialIndex: widget.initialTab,
        child: Builder(
          builder: (context) => Column(
            children: [
              Stack(
                children: [
                  const Positioned.fill(child: ZonixHeaderBackground()),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
                        child: _Heading(),
                      ),
                      ZonixPillTabBar(
                        maxWidth: 420,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        tabs: [
                          const ZonixTabLabel(
                            icon: Icon(Icons.tune_rounded),
                            label: 'Settings',
                          ),
                          ListenableBuilder(
                            listenable: contactRequestsFeed,
                            builder: (context, _) {
                              final count = newContactRequestCount();
                              return ZonixTabLabel(
                                icon: Badge(
                                  isLabelVisible: count > 0,
                                  label: Text('$count'),
                                  child: const Icon(Icons.inbox_outlined),
                                ),
                                label: 'Requests',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ContactZonixSettingsScreen(
                      adminRecognised: _adminRecognised,
                      onRecheckAdmin: _checkAdmin,
                      onOpenRequests: () =>
                          DefaultTabController.of(context).animateTo(1),
                    ),
                    ContactRequestsScreen(
                      adminRecognised: _adminRecognised,
                      onRecheckAdmin: _checkAdmin,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const GlowIconTile(icon: Icons.support_agent_rounded),
        const SizedBox(width: AppDimens.spacing14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ONBOARDING',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: Color(0xF238BDF6),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Contact Zonix',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'The join button on the app\'s shop code screen, and the '
                'requests it sends',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
