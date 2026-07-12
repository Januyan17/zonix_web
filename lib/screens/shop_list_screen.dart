import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../utils/avatar_color.dart';
import '../widgets/admin_shell.dart';
import 'create_shop_screen.dart';
import 'shop_detail_screen.dart';

class _ShopEntry {
  const _ShopEntry({required this.slug, required this.indexedName, required this.shop});

  final String slug;
  final String indexedName;
  final Shop? shop;
}

class ShopListScreen extends StatelessWidget {
  const ShopListScreen({
    super.key,
    required this.authService,
    required this.shopService,
  });

  final AuthService authService;
  final ShopService shopService;

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: authService,
      shopService: shopService,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create shop'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateShopScreen(shopService: shopService),
            ),
          );
        },
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: shopService.watchShopIndex(),
        builder: (context, indexSnapshot) {
          if (indexSnapshot.hasError) {
            return Center(child: Text('Error: ${indexSnapshot.error}'));
          }
          if (!indexSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = indexSnapshot.data!;
          if (docs.isEmpty) {
            return _DashboardScaffold(
              child: _EmptyState(shopService: shopService),
            );
          }

          return FutureBuilder<List<Shop?>>(
            future: Future.wait(docs.map((d) => shopService.getShop(d.id))),
            builder: (context, shopsSnapshot) {
              final shops = shopsSnapshot.data;
              final entries = [
                for (var i = 0; i < docs.length; i++)
                  _ShopEntry(
                    slug: docs[i].id,
                    indexedName: docs[i].data()['name'] as String? ?? docs[i].id,
                    shop: shops?[i],
                  ),
              ];

              return _DashboardScaffold(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1300 ? 3 : (width >= 820 ? 2 : 1);
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _SummaryRow(entries: entries, loading: shops == null),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
                            child: Text(
                              '${entries.length} shop${entries.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            (context, index) => _ShopTile(
                              entry: entries[index],
                              shopService: shopService,
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
          );
        },
      ),
    );
  }
}

/// Consistent page padding + max content width so the dashboard doesn't
/// stretch edge-to-edge on very wide screens.
class _DashboardScaffold extends StatelessWidget {
  const _DashboardScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: child,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.entries, required this.loading});

  final List<_ShopEntry> entries;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = entries.length;
    final active = entries.where((e) => e.shop?.isActive == true).length;
    final inactive = entries.where((e) => e.shop != null && e.shop!.isActive == false).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        final tiles = [
          _SummaryTile(
            icon: Icons.storefront_outlined,
            label: 'Total shops',
            value: loading ? '—' : '$total',
            color: colorScheme.primary,
            containerColor: colorScheme.primaryContainer,
          ),
          _SummaryTile(
            icon: Icons.check_circle_outline,
            label: 'Active',
            value: loading ? '—' : '$active',
            color: colorScheme.tertiary,
            containerColor: colorScheme.tertiaryContainer,
          ),
          _SummaryTile(
            icon: Icons.pause_circle_outline,
            label: 'Inactive',
            value: loading ? '—' : '$inactive',
            color: colorScheme.onSurfaceVariant,
            containerColor: colorScheme.surfaceContainerHighest,
          ),
        ];

        if (narrow) {
          return Column(
            children: [
              for (final t in tiles) ...[t, const SizedBox(height: 10)],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i != tiles.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.containerColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: containerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(label, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.shopService});

  final ShopService shopService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.storefront_outlined, color: colorScheme.onPrimaryContainer, size: 30),
            ),
            const SizedBox(height: 16),
            Text('No shops yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Create your first shop to get started.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateShopScreen(shopService: shopService),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create shop'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.entry, required this.shopService});

  final _ShopEntry entry;
  final ShopService shopService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = entry.indexedName;
    final avatarColor = avatarColorForName(name);
    final shop = entry.shop;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ShopDetailScreen(slug: entry.slug, shopService: shopService),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarColor.withValues(alpha: 0.15),
                foregroundColor: avatarColor,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop?.name ?? name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(shop: shop),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.shop});

  final Shop? shop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (shop == null) {
      return Chip(
        label: const Text('missing'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }
    final active = shop!.isActive;
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle : Icons.pause_circle_outline,
        size: 16,
        color: active ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
      ),
      label: Text(active ? 'Active' : 'Inactive'),
      backgroundColor: active
          ? colorScheme.tertiaryContainer.withValues(alpha: 0.6)
          : colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: active ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant,
      ),
    );
  }
}
