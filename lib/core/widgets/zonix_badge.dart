import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_assets.dart';

/// Brand mark: the Zonix Admin app icon (Zonix logo on a frosted-glass
/// tile). Set [showLabel] to include the "ADMIN" label; only do that at
/// large sizes (~80px+), since the label is unreadable when small.
class ZonixBadge extends StatelessWidget {
  const ZonixBadge({super.key, this.size = 52, this.showLabel = false});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      showLabel ? AppAssets.zonixAdminIcon : AppAssets.zonixAdminMark,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // A stale/failed asset load shouldn't take a whole Row's layout down
      // with it — a fixed-size blank box is a safe, silent fallback.
      errorBuilder: (context, error, stackTrace) =>
          SizedBox(width: size, height: size),
    );
  }
}
