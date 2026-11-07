/// A fraction (0.42) as a percentage string ("42%").
String formatPercent(double fraction, {int decimals = 0}) =>
    '${(fraction * 100).toStringAsFixed(decimals)}%';

/// A change as a percentage carrying its direction ("+12%", "-4%").
/// Always signed: an unsigned "12%" next to last period reads as a level,
/// not a movement.
String formatSignedPercent(double fraction, {int decimals = 0}) {
  final value = fraction * 100;
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(decimals)}%';
}

/// A quantity that is usually whole but can be fractional (a weight):
/// prints 3 rather than 3.0, and 1.5 rather than 2.
String formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}
