import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';

/// Centers page content and caps its width so it doesn't stretch
/// edge-to-edge on very wide screens.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth = AppDimens.pageMaxWidthWide,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.spacing16,
      AppDimens.spacing16,
      AppDimens.spacing16,
      0,
    ),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
