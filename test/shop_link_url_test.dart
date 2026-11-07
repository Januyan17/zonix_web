import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/utils/shop_link_url.dart';

/// These rules are duplicated in the mobile app, which builds the URL each
/// receipt QR code encodes. A change here that isn't mirrored there sends a
/// code set in the portal somewhere different from the same handle set on
/// mobile, so the cases below pin down every branch of the spec.
void main() {
  group('website', () {
    test('keeps an existing scheme', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.website, 'http://zonix.test'),
        'http://zonix.test',
      );
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.website, 'ftp://files.zonix.test'),
        'ftp://files.zonix.test',
      );
    });

    test('prefixes https:// otherwise', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.website, 'zonix.test'),
        'https://zonix.test',
      );
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.website, 'www.zonix.test/shop'),
        'https://www.zonix.test/shop',
      );
    });
  });

  group('socials as handles', () {
    test('bare name goes under the platform profile base', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.facebook, 'zonixpos'),
        'https://facebook.com/zonixpos',
      );
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.instagram, 'my-shop_1'),
        'https://instagram.com/my-shop_1',
      );
    });

    test('leading @ and / are stripped', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.facebook, '@zonixpos'),
        'https://facebook.com/zonixpos',
      );
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.instagram, '/zonixpos'),
        'https://instagram.com/zonixpos',
      );
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.facebook, '//@zonixpos'),
        'https://facebook.com/zonixpos',
      );
    });

    test('tiktok keeps the @ the others drop', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.tiktok, 'zonixpos'),
        'https://tiktok.com/@zonixpos',
      );
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.tiktok, '@zonixpos'),
        'https://tiktok.com/@zonixpos',
      );
    });

    test('a name containing a dot is still a name', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.instagram, 'zonix.pos'),
        'https://instagram.com/zonix.pos',
      );
    });
  });

  group('socials as URLs', () {
    test('a scheme is used as-is', () {
      expect(
        resolveShopLinkUrl(
          ShopLinkPlatform.tiktok,
          'https://tiktok.com/@zonixpos',
        ),
        'https://tiktok.com/@zonixpos',
      );
    });

    test('a leading www. makes it a URL', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.facebook, 'www.fb.me/zonixpos'),
        'https://www.fb.me/zonixpos',
      );
    });

    test('containing ".com/" makes it a URL', () {
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.facebook, 'facebook.com/zonixpos'),
        'https://facebook.com/zonixpos',
      );
      expect(
        resolveShopLinkUrl(ShopLinkPlatform.tiktok, 'tiktok.com/@zonixpos'),
        'https://tiktok.com/@zonixpos',
      );
    });
  });

  group('normalizeShopLink', () {
    test('trims, and stores nothing-but-whitespace as null', () {
      expect(normalizeShopLink('  zonixpos  '), 'zonixpos');
      expect(normalizeShopLink('   '), isNull);
      expect(normalizeShopLink(''), isNull);
      expect(normalizeShopLink(null), isNull);
    });
  });

  group('shopLinkError', () {
    test('empty is allowed — every link is optional', () {
      expect(shopLinkError(''), isNull);
      expect(shopLinkError('   '), isNull);
      expect(shopLinkError(null), isNull);
    });

    test('accepts handles, bare domains, and full URLs', () {
      for (final value in [
        '@zonixpos',
        'zonixpos',
        'my-shop_1',
        'zonix.test',
        'https://zonix.test/shop?utm=qr',
      ]) {
        expect(shopLinkError(value), isNull, reason: value);
      }
    });

    test('rejects interior whitespace', () {
      expect(shopLinkError('zonix pos'), isNotNull);
      expect(shopLinkError('zonix\tpos'), isNotNull);
      expect(shopLinkError('zonix\npos'), isNotNull);
    });

    test('ignores whitespace that only pads the value', () {
      expect(shopLinkError('  zonixpos  '), isNull);
    });
  });
}
