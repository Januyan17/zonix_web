import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/empty_state.dart';
import 'package:zonixweb/core/widgets/page_container.dart';
import 'package:zonixweb/core/widgets/page_header.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/models/shop_list_entry.dart';
import 'package:zonixweb/features/shops/screens/create_shop_screen.dart';
import 'package:zonixweb/features/shops/screens/shop_detail_screen.dart';
import 'package:zonixweb/features/shops/services/shop_directory.dart';
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

  /// The shared live shop data. The nav is already listening to it for
  /// its badges, so this page adds no reads of its own; shop documents are
  /// live, so a status change or delete made on the detail page shows up
  /// here without a re-read.
  final ShopDirectory _directory = ShopDirectory.instance;

  void _openShop(String slug) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(slug: slug, shopService: shopService),
      ),
    );
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
      body: ListenableBuilder(
        listenable: _directory,
        builder: (context, _) {
          if (_directory.error != null) {
            return Center(child: Text('Error: ${_directory.error}'));
          }
          final docs = _directory.indexDocs;
          if (docs == null) {
            return const Center(child: CircularProgressIndicator());
          }
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

          final allLoaded = docs.every((d) => _directory.isShopLoaded(d.id));
          final entries = [
            for (final doc in docs)
              ShopListEntry(
                slug: doc.id,
                indexedName: doc.data()['name'] as String? ?? doc.id,
                shop: _directory.shop(doc.id),
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
                          bottom: AppDimens.spacing20,
                        ),
                        child: PageHeader(
                          icon: Icons.storefront_rounded,
                          tag: 'Directory',
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
