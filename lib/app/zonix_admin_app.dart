import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_theme.dart';
import 'package:zonixweb/features/auth/screens/auth_gate.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

class ZonixAdminApp extends StatelessWidget {
  const ZonixAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zonix Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AuthGate(authService: AuthService(), shopService: ShopService()),
    );
  }
}
