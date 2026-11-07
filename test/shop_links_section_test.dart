import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zonixweb/models/shop.dart';
import 'package:zonixweb/screens/shop_detail/widgets/shop_links_section.dart';

Shop shopWith({
  String? website,
  String? facebook,
  String? instagram,
  String? tiktok,
  bool shopLinksEnabled = false,
}) {
  return Shop(
    id: 'zonix',
    name: 'Zonix',
    slug: 'zonix',
    isActive: true,
    ownerUid: 'uid',
    createdAt: '2026-01-01T00:00:00.000Z',
    website: website,
    facebook: facebook,
    instagram: instagram,
    tiktok: tiktok,
    shopLinksEnabled: shopLinksEnabled,
  );
}

void main() {
  late List<ShopLinksResult> saved;

  Future<void> pumpSection(WidgetTester tester, Shop shop) {
    saved = [];
    // Tall enough that the whole section — Save button included — is on
    // screen, rather than scrolled out of reach of a tap.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShopLinksSection(
              shop: shop,
              onSave: (result) async => saved.add(result),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('previews a QR code as the admin types', (tester) async {
    await pumpSection(tester, shopWith());
    expect(find.byType(QrImageView), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Facebook'),
      '@z',
    );
    await tester.pump();
    expect(find.text('https://facebook.com/z'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Facebook'),
      '@zonixpos',
    );
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('https://facebook.com/zonixpos'), findsOneWidget);
  });

  testWidgets('saves trimmed raw values, not the resolved URLs', (
    tester,
  ) async {
    await pumpSection(tester, shopWith());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website'),
      '  zonix.test  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'TikTok'),
      '@zonixpos',
    );
    await tester.tap(find.text('Let this shop edit their own links'));
    await tester.pump();

    await tester.tap(find.text('Save links'));
    await tester.pump();

    expect(saved, hasLength(1));
    expect(saved.single.website, 'zonix.test');
    expect(saved.single.tiktok, '@zonixpos');
    expect(saved.single.facebook, isNull);
    expect(saved.single.instagram, isNull);
    expect(saved.single.linksEnabled, isTrue);
  });

  testWidgets('a cleared input saves as null, not an empty string', (
    tester,
  ) async {
    await pumpSection(tester, shopWith(facebook: 'zonixpos'));
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Facebook'),
      '  ',
    );
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('Save links'));
    await tester.pump();

    expect(saved.single.facebook, isNull);
  });

  testWidgets('a value with a space blocks the save', (tester) async {
    await pumpSection(tester, shopWith());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instagram'),
      'zonix pos',
    );
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('Save links'));
    await tester.pump();

    expect(saved, isEmpty);
    expect(find.text('No spaces allowed'), findsOneWidget);
  });

  testWidgets('re-seeds when the shop reloads with different values', (
    tester,
  ) async {
    await pumpSection(tester, shopWith(instagram: 'old_handle'));
    expect(find.text('https://instagram.com/old_handle'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShopLinksSection(
              shop: shopWith(instagram: 'new_handle'),
              onSave: (result) async => saved.add(result),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('https://instagram.com/new_handle'), findsOneWidget);
  });
}
