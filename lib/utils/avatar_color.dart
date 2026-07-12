import 'package:flutter/material.dart';

const List<Color> _avatarPalette = [
  Color(0xFF4F46E5),
  Color(0xFF0EA5E9),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFFDB2777),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFDC2626),
];

Color avatarColorForName(String name) {
  if (name.isEmpty) return _avatarPalette.first;
  return _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
}
