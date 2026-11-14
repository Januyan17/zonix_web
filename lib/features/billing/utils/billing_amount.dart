/// Parses an amount typed by the admin ("1,500", "1500.00"). Null if blank
/// or invalid.
double? parseAmount(String text) {
  final cleaned = text.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String? amountError(String? text, {bool required = true}) {
  final v = text?.trim() ?? '';
  if (v.isEmpty) return required ? 'Enter the amount' : null;
  final amount = parseAmount(v);
  if (amount == null) return 'Enter a valid number';
  if (amount <= 0) return 'Amount must be more than 0';
  return null;
}

String formatAmountInput(double? amount) {
  if (amount == null) return '';
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}
