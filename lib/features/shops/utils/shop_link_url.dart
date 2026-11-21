/// The link platforms a shop can configure. Each is a flat field on the
/// `shops/{shopId}` document, holding the raw value the admin typed.
enum ShopLinkPlatform { website, facebook, instagram, tiktok }

/// Matches a value that already carries a URL scheme ("https://", "ftp://").
final _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

/// Matches a social value that should be treated as a URL rather than as a
/// profile name — either a scheme or a leading "www.".
final _urlLikePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*://|www\.)');

/// Leading "@"/"/" noise on a pasted handle ("@zonix", "/zonix").
final _handlePrefixPattern = RegExp(r'^[@/]+');

/// Whitespace, which a link can never contain in the middle.
final _whitespacePattern = RegExp(r'\s');

/// Profile URL bases a bare handle is appended to. TikTok's keeps the "@"
/// that the other two drop.
const _profileUrlBase = {
  ShopLinkPlatform.facebook: 'https://facebook.com/',
  ShopLinkPlatform.instagram: 'https://instagram.com/',
  ShopLinkPlatform.tiktok: 'https://tiktok.com/@',
};

/// The URL a stored link value resolves to — exactly what the QR code
/// printed on a receipt encodes. The mobile app derives this with the same
/// rules, so the two must stay in sync or a code set here would point
/// somewhere different from the same handle set on mobile. Only the raw
/// value is ever stored; this result never is.
String resolveShopLinkUrl(ShopLinkPlatform platform, String rawValue) {
  final value = rawValue.trim();
  if (platform == ShopLinkPlatform.website) return _withScheme(value);

  // A social value that looks like a URL is used as one; anything else is a
  // profile name, appended to that platform's profile base.
  if (_urlLikePattern.hasMatch(value) || value.contains('.com/')) {
    return _withScheme(value);
  }
  final handle = value.replaceFirst(_handlePrefixPattern, '');
  return '${_profileUrlBase[platform]!}$handle';
}

String _withScheme(String value) =>
    _schemePattern.hasMatch(value) ? value : 'https://$value';

/// The value to store for [rawValue]: trimmed, or null when it is empty or
/// whitespace only. Null — rather than an omitted field or an empty string —
/// is what stops a cleared link from printing on receipts.
String? normalizeShopLink(String? rawValue) {
  final value = rawValue?.trim() ?? '';
  return value.isEmpty ? null : value;
}

/// Validation message for a link input, or null when it's acceptable. Every
/// link is optional; the only rejected shape is a value with whitespace
/// inside it, since neither a URL nor a handle can contain one.
String? shopLinkError(String? rawValue) {
  final value = rawValue?.trim() ?? '';
  if (value.isEmpty) return null;
  if (_whitespacePattern.hasMatch(value)) return 'No spaces allowed';
  return null;
}
