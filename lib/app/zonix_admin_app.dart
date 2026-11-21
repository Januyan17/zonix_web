import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_theme.dart';
import 'package:zonixweb/features/auth/screens/auth_gate.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/auth/widgets/session_watcher.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

class ZonixAdminApp extends StatefulWidget {
  const ZonixAdminApp({super.key});

  @override
  State<ZonixAdminApp> createState() => _ZonixAdminAppState();
}

class _ZonixAdminAppState extends State<ZonixAdminApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _authService = AuthService();
  final _shopService = ShopService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zonix Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: _navigatorKey,
      builder: (context, child) => SessionWatcher(
        navigatorKey: _navigatorKey,
        authService: _authService,
        shopService: _shopService,
        child: child!,
      ),
      home: AuthGate(authService: _authService, shopService: _shopService),
    );
  }
}
