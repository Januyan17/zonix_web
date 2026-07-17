import 'package:flutter/material.dart';

import '../theme/app_assets.dart';

/// Brand mark: the Zonix logo (assets/zonix_logo.png), a pre-cropped
/// transparent-background square so it drops onto any surface color.
class ZonixBadge extends StatelessWidget {
  const ZonixBadge({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.zonixLogo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // A stale/failed asset load shouldn't take a whole Row's layout down
      // with it — a fixed-size blank box is a safe, silent fallback.
      errorBuilder: (context, error, stackTrace) =>
          SizedBox(width: size, height: size),
    );
  }
}
