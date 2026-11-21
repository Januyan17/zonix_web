// Sri Lankan phone numbers as admins type them: 0771234567, 771234567,
// +94 77 123 4567, 0094 77 123 4567 (spaces, dashes, dots and brackets are
// ignored).

/// The 9-digit national number (no leading 0), or null when [input] is not
/// a valid Sri Lankan number.
String? sriLankaNationalNumber(String? input) {
  var digits = (input ?? '').trim();
  if (digits.isEmpty) return null;
  final hasPlus = digits.startsWith('+');
  digits = digits.replaceAll(RegExp(r'[\s\-().]'), '');
  if (hasPlus) digits = digits.substring(1);
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;

  if (digits.startsWith('0094')) {
    digits = digits.substring(4);
  } else if (hasPlus || (digits.startsWith('94') && digits.length == 11)) {
    if (!digits.startsWith('94')) return null;
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return RegExp(r'^[1-9]\d{8}$').hasMatch(digits) ? digits : null;
}

bool isValidSriLankaPhone(String? input) =>
    sriLankaNationalNumber(input) != null;

/// "+94 77 123 4567", or null when [input] is not a valid number.
String? formatSriLankaPhone(String? input) {
  final n = sriLankaNationalNumber(input);
  if (n == null) return null;
  return '+94 ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5)}';
}

/// [formatSriLankaPhone], falling back to the input as typed.
String displaySriLankaPhone(String input) =>
    formatSriLankaPhone(input) ?? input.trim();

/// tel: link in E.164, or null when invalid.
Uri? sriLankaTelUri(String input) {
  final n = sriLankaNationalNumber(input);
  return n == null ? null : Uri(scheme: 'tel', path: '+94$n');
}

/// wa.me link, only for mobile numbers (national part starting with 7).
Uri? sriLankaWhatsAppUri(String input) {
  final n = sriLankaNationalNumber(input);
  if (n == null || !n.startsWith('7')) return null;
  return Uri.parse('https://wa.me/94$n');
}
