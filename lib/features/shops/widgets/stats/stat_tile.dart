import 'package:flutter/material.dart';

import 'package:zonixweb/core/utils/percent_format.dart';
import 'package:zonixweb/core/widgets/icon_badge.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.containerColor,
    this.delta,
    this.sublabel,
    this.higherIsBetter = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color containerColor;

  /// Change against the previous period, as a fraction (0.2 = up 20%).
  /// Null hides the chip entirely — both when there is no previous period
  /// and when the previous period was zero, where a percentage would be
  /// undefined.
  final double? delta;

  /// A second line under the label, for the qualifier a figure needs to be
  /// read correctly ("after cost of goods").
  final String? sublabel;

  /// Whether an increase is the good direction. False for costs, where the
  /// same green arrow would say the opposite of what it means.
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: icon,
                size: 32,
                iconSize: 17,
                color: color,
                background: containerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(9),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 6),
                    DeltaChip(change: delta!, higherIsBetter: higherIsBetter),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "vs. previous period" chip on a stat tile: an arrow and a signed
/// percentage, colored by whether the movement is the good one for that
/// figure rather than by its sign.
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.change,
    this.higherIsBetter = true,
  });

  final double change;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rising = change >= 0;
    final good = rising == higherIsBetter;
    // Flat is neither good nor bad; coloring a 0% move green would invent
    // a trend out of nothing.
    final neutral = change == 0;
    final color = neutral
        ? colorScheme.onSurfaceVariant
        : good
        ? colorScheme.tertiary
        : colorScheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          neutral
              ? Icons.remove_rounded
              : rising
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          size: 12,
          color: color,
        ),
        Text(
          formatSignedPercent(change),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
