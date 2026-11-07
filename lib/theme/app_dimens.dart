import 'package:flutter/material.dart';

/// Zonix spacing/sizing scale. Mirrors the ad hoc values already in use
/// across the app; this is a naming pass, not a redesign.
class AppDimens {
  AppDimens._();

  // --- Spacing (SizedBox gaps, EdgeInsets) ---
  static const spacing2 = 2.0;
  static const spacing4 = 4.0;
  static const spacing6 = 6.0;
  static const spacing8 = 8.0;
  static const spacing10 = 10.0;
  static const spacing12 = 12.0;
  static const spacing14 = 14.0;
  static const spacing16 = 16.0;
  static const spacing20 = 20.0;
  static const spacing24 = 24.0;

  // --- EdgeInsets presets (covers the most repeated combos) ---
  static const paddingAll20 = EdgeInsets.all(spacing20);
  static const paddingAll24 = EdgeInsets.all(spacing24);
  static const paddingAll14 = EdgeInsets.all(spacing14);
  static const paddingH16V12 = EdgeInsets.symmetric(
    horizontal: spacing16,
    vertical: spacing12,
  );
  static const paddingH10 = EdgeInsets.symmetric(horizontal: spacing10);
  static const dialogHeaderPadding = EdgeInsets.fromLTRB(20, 16, 20, 20);
  static const modalHeaderPadding = EdgeInsets.fromLTRB(20, 12, 20, 20);
  static const cardCompactPadding = EdgeInsets.fromLTRB(12, 10, 12, 12);

  // --- Border radius ---
  static const radiusSmall = 6.0;
  static const radiusMedium =
      10.0; // absorbs the 9/10/13 near-duplicates in use
  static const radiusLarge = 12.0;
  static const radiusSheetTop = 20.0; // bottom-sheet top corners
  static const radiusHandle = 2.0; // drag-handle pill

  // --- Font sizes (named by role) ---
  static const fontLabel = 12.0;
  static const fontLabelLg = 12.5;
  static const fontBody = 13.0;
  static const fontBodyLg = 13.5;
  static const fontCaption = 11.5;
  static const fontTitleSm = 17.0;
  static const fontTitle = 18.0;

  // --- Icon sizes ---
  static const iconXs = 14.0;
  static const iconSm = 16.0;
  static const iconMd = 17.0;
  static const iconLg = 18.0;
  static const iconXl = 20.0;
  static const iconXxl = 22.0;
  static const icon2xl = 32.0;

  // --- Fixed component dimensions ---
  static const labelColumnWidth = 90.0;
  static const avatarBoxLarge = 44.0;
  static const iconBadgeSm = 32.0;
  static const iconBadgeMd = 34.0;
  static const iconBadgeLg = 36.0;
  static const dragHandleHeight = 4.0;
  static const menuRowHeight = 40.0;
  static const spinnerBox = 22.0;
  static const photoPickerBox = 120.0;
  static const statTileWidth = 160.0;
  static const productCardWidth = 200.0;
}
