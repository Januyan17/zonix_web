import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/empty_state.dart';
import 'package:zonixweb/core/widgets/page_container.dart';
import 'package:zonixweb/core/widgets/page_header.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_list_entry.dart';
import 'package:zonixweb/features/shops/screens/create_shop_screen.dart';
import 'package:zonixweb/features/shops/screens/shop_detail_screen.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';
import 'package:zonixweb/features/shops/widgets/shop_list_summary.dart';
import 'package:zonixweb/features/shops/widgets/shop_tile.dart';

class ShopListScreen extends StatefulWidget {
  const ShopListScreen({
    super.key,
    required this.authService,
    required this.shopService,
  });

  final AuthService authService;
  final ShopService shopService;

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  AuthService get authService => widget.authService;
  ShopService get shopService => widget.shopService;

  late final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _indexStream = shopService.watchShopIndex();

  /// Shop documents already fetched, by slug. Each is read once and kept,
  /// so a rebuild (a window resize, say) costs no extra reads.
  final Map<String, Shop?> _shops = {};
  final Set<String> _inFlight = {};

  /// Fetches the shops in [slugs] that aren't loaded or loading yet. Safe
  /// to call from build: it never calls setState synchronously.
  void _ensureLoaded(Iterable<String> slugs) {
    for (final slug in slugs) {
      if (_shops.containsKey(slug) || _inFlight.contains(slug)) continue;
      _fetch(slug);
    }
  }

  Future<void> _fetch(String slug) async {
    _inFlight.add(slug);
    try {
      final shop = await shopService.getShop(slug);
      if (mounted) setState(() => _shops[slug] = shop);
    } catch (_) {
      // Left unloaded; the tile keeps its placeholder.
    } finally {
      _inFlight.remove(slug);
    }
  }

  /// The detail page can toggle a shop's status or delete it, so the one
  /// shop that was just opened is re-read on return — a single read rather
  /// than the whole list.
  Future<void> _openShop(String slug) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(slug: slug, shopService: shopService),
      ),
    );
    if (mounted) _fetch(slug);
  }

  void _createShop() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateShopScreen(shopService: shopService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: authService,
      shopService: shopService,
      current: AdminPage.shops,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create shop'),
        onPressed: _createShop,
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _indexStream,
        builder: (context, indexSnapshot) {
          if (indexSnapshot.hasError) {
            return Center(child: Text('Error: ${indexSnapshot.error}'));
          }
          if (!indexSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = indexSnapshot.data!;
          if (docs.isEmpty) {
            return PageContainer(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'No shops yet',
                message: 'Create your first shop to get started.',
                action: FilledButton.icon(
                  onPressed: _createShop,
                  icon: const Icon(Icons.add),
                  label: const Text('Create shop'),
                ),
              ),
            );
          }

          _ensureLoaded(docs.map((d) => d.id));
          final allLoaded = docs.every((d) => _shops.containsKey(d.id));
          final entries = [
            for (final doc in docs)
              ShopListEntry(
                slug: doc.id,
                indexedName: doc.data()['name'] as String? ?? doc.id,
                shop: _shops[doc.id],
              ),
          ];

          return PageContainer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1300 ? 3 : (width >= 820 ? 2 : 1);
                return CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: AppDimens.spacing8,
                          bottom: AppDimens.spacing16,
                        ),
                        child: PageHeader(
                          title: 'Shops',
                          subtitle:
                              'Every shop on the platform and its status.',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ShopListSummary(
                        entries: entries,
                        loading: !allLoaded,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          0,
                          AppDimens.spacing24,
                          0,
                          AppDimens.spacing12,
                        ),
                        child: Text(
                          '${entries.length} shop${entries.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ShopTile(
                          entry: entries[index],
                          onOpen: () => _openShop(entries[index].slug),
                        ),
                        childCount: entries.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
