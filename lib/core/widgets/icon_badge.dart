import 'package:flutter/material.dart';

/// Shared "icon centered in a colored box" pattern used by the stat tiles,
/// count chips, and transaction rows — square/rounded or circular.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.color,
    required this.background,
    this.borderRadius,
    this.circular = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color background;
  final BorderRadius? borderRadius;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : borderRadius,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
