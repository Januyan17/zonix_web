import 'package:flutter/material.dart';

/// Zonix brand palette.
class ZonixColors {
  ZonixColors._();

  static const navy = Color(0xFF0A2540);
  static const emerald = Color(0xFF16A34A);
  static const cyan = Color(0xFF38BDF6);

  static const navyContainer = Color(0xFFDCE6F0);
  static const emeraldContainer = Color(0xFFD6F5E3);
  static const cyanContainer = Color(0xFFDFF4FE);

  static const onEmeraldContainer = Color(0xFF0F5132);
  static const onCyanContainer = Color(0xFF0A2540);

  /// Fill for single-series chart marks (counts, rankings). A mid-tone of
  /// the navy-to-cyan family rather than either end: [navy] is too dark and
  /// too desaturated to read as a data color against the light surface, and
  /// [cyan] falls below 3:1 contrast against it. Verified against the
  /// lightness-band, chroma-floor, and contrast checks, and separable from
  /// [emerald] under deuteranopia.
  static const chartBlue = Color(0xFF1D6FA8);
}
