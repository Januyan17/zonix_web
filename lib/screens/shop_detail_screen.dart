import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../models/shop_stats.dart';
import '../models/shop_transaction.dart';
import '../models/shop_user.dart';
import '../services/shop_service.dart';
import '../services/supabase_storage_service.dart';
import '../utils/avatar_color.dart';
import '../utils/error_utils.dart';
import '../widgets/credential_row.dart';
import '../widgets/trend_chart.dart';

class ShopDetailScreen extends StatefulWidget {
  const ShopDetailScreen({
    super.key,
    required this.slug,
    required this.shopService,
  });

  final String slug;
  final ShopService shopService;

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

enum _DateFilter { day, week, month, allTime, custom }

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  final _storageService = SupabaseStorageService();

  Shop? _shop;
  List<ShopUser> _users = [];
  ShopStats? _stats;
  List<DailyStat>? _dailySeries;
  List<Product> _products = [];
  bool _loading = true;
  bool _statsLoading = true;
  bool _seriesLoading = true;
  bool _productsLoading = true;
  bool _togglingActive = false;
  bool _showProducts = false;
  bool _showTransactions = false;
  String? _error;

  _DateFilter _filter = _DateFilter.allTime;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStats();
    _loadSeries();
    _loadProducts();
  }

  /// The chart needs a concrete, bounded window even in "all time" mode
  /// (there's no meaningful daily trend over an unbounded range), so it
  /// falls back to the last 30 days — clearly labeled as such rather than
  /// silently disagreeing with the "all time" totals shown in the tiles.
  (DateTime, DateTime, String) _resolveChartWindow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case _DateFilter.allTime:
        return (today.subtract(const Duration(days: 29)), today, 'last 30 days');
      case _DateFilter.day:
        return (today.subtract(const Duration(days: 6)), today, 'last 7 days');
      case _DateFilter.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (DateTime(monday.year, monday.month, monday.day), today, 'this week');
      case _DateFilter.month:
        return (DateTime(now.year, now.month, 1), today, 'this month');
      case _DateFilter.custom:
        final range = _customRange;
        if (range == null) {
          return (today.subtract(const Duration(days: 29)), today, 'last 30 days');
        }
        return (
          range.start,
          range.end,
          '${range.start.day}/${range.start.month} - ${range.end.day}/${range.end.month}',
        );
    }
  }

  Future<void> _loadSeries() async {
    setState(() => _seriesLoading = true);
    try {
      final (start, end, _) = _resolveChartWindow();
      final series = await widget.shopService.getDailySeries(widget.slug, start: start, end: end);
      if (mounted) setState(() => _dailySeries = series);
    } catch (_) {
      // The chart is supplementary; a failure here shouldn't block the rest
      // of the page from showing.
    } finally {
      if (mounted) setState(() => _seriesLoading = false);
    }
  }

  StatsDateRange? _resolveRange() {
    final now = DateTime.now();
    switch (_filter) {
      case _DateFilter.allTime:
        return null;
      case _DateFilter.day:
        final today = DateTime(now.year, now.month, now.day);
        return StatsDateRange(start: today, end: today);
      case _DateFilter.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return StatsDateRange(
          start: DateTime(monday.year, monday.month, monday.day),
          end: DateTime(now.year, now.month, now.day),
        );
      case _DateFilter.month:
        return StatsDateRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
      case _DateFilter.custom:
        final range = _customRange;
        if (range == null) return null;
        return StatsDateRange(start: range.start, end: range.end);
    }
  }

  Future<void> _selectFilter(_DateFilter filter) async {
    if (filter == _DateFilter.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange: _customRange ??
            DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      );
      if (picked == null) return;
      setState(() {
        _filter = _DateFilter.custom;
        _customRange = picked;
      });
    } else {
      setState(() => _filter = filter);
    }
    _loadStats();
    _loadSeries();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shop = await widget.shopService.getShop(widget.slug);
      final users = await widget.shopService.getShopUsers(widget.slug);
      if (mounted) {
        setState(() {
          _shop = shop;
          _users = users;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load shop: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final stats = await widget.shopService.getShopStats(widget.slug, range: _resolveRange());
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Stats are supplementary; a failure here shouldn't block the rest of
      // the page from showing.
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _productsLoading = true);
    try {
      final products = await widget.shopService.getShopProducts(widget.slug);
      if (mounted) setState(() => _products = products);
    } catch (_) {
      // Products are supplementary; a failure here shouldn't block the rest
      // of the page from showing.
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  Future<void> _toggleActive(bool newValue) async {
    setState(() => _togglingActive = true);
    try {
      await widget.shopService.setShopActive(widget.slug, newValue);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${describeError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingActive = false);
    }
  }

  Future<void> _editStaffLimit() async {
    final result = await showDialog<_StaffLimitResult>(
      context: context,
      builder: (_) => _StaffLimitDialog(currentLimit: _shop!.staffLimit),
    );
    if (result == null) return; // cancelled

    try {
      await widget.shopService.setStaffLimit(widget.slug, result.limit);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update staff limit: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _editProductLimit() async {
    final result = await showDialog<_ProductLimitResult>(
      context: context,
      builder: (_) => _ProductLimitDialog(currentLimit: _shop!.productLimit),
    );
    if (result == null) return; // cancelled

    try {
      await widget.shopService.setProductLimit(widget.slug, result.limit);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product limit: ${describeError(e)}')),
        );
      }
    }
  }

  /// Opens the transactions list in a bottom sheet, which owns its own
  /// filter and data loading — nothing here is fetched until the admin
  /// actually asks to see it. The header switch is just a trigger, not
  /// persisted state, so it resets once the sheet is dismissed.
  Future<void> _openTransactionsModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TransactionsModal(shopService: widget.shopService, slug: widget.slug),
    );
    if (mounted) setState(() => _showTransactions = false);
  }

  Future<void> _addProduct() async {
    final result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (_) => const _ProductFormDialog(),
    );
    if (result == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final id = widget.shopService.newProductId(widget.slug);
      String? imageUrl;
      if (result.newImageBytes != null) {
        imageUrl = await _storageService.uploadProductImage(
          slug: widget.slug,
          productId: id,
          bytes: result.newImageBytes!,
          fileExt: result.newImageExt!,
        );
      }
      await widget.shopService.addProduct(
        slug: widget.slug,
        id: id,
        name: result.name,
        description: result.description,
        category: result.category,
        sku: result.sku,
        price: result.price,
        cost: result.cost,
        stock: result.stock,
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.of(context).pop(); // dismiss progress dialog
      await _loadProducts();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _editProduct(Product product) async {
    final result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (_) => _ProductFormDialog(product: product),
    );
    if (result == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      var imageUrl = product.imageUrl;
      if (result.newImageBytes != null) {
        imageUrl = await _storageService.uploadProductImage(
          slug: widget.slug,
          productId: product.id,
          bytes: result.newImageBytes!,
          fileExt: result.newImageExt!,
        );
      }
      await widget.shopService.updateProduct(
        slug: widget.slug,
        id: product.id,
        name: result.name,
        description: result.description,
        category: result.category,
        sku: result.sku,
        price: result.price,
        cost: result.cost,
        stock: result.stock,
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.of(context).pop(); // dismiss progress dialog
      await _loadProducts();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this product?'),
        content: Text(
          'This removes "${product.name}" from the shop\'s catalog. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await widget.shopService.deleteProduct(slug: widget.slug, id: product.id);
      if (mounted) Navigator.of(context).pop(); // dismiss progress dialog
      await _loadProducts();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete product: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteShopDialog(slug: widget.slug, shopName: _shop!.name),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await widget.shopService.deleteShop(widget.slug);
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        Navigator.of(context).pop(); // back to shop list
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete shop: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _reissueLogin(ShopUser user) async {
    final request = await showDialog<_ReissueRequest>(
      context: context,
      builder: (_) => _ReissueLoginDialog(user: user),
    );
    if (request == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await widget.shopService.reissueLogin(
        slug: widget.slug,
        oldUser: user,
        newUsername: request.username,
        newPassword: request.password,
      );
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        await showDialog(
          context: context,
          builder: (_) => _ReissueSuccessDialog(result: result),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reissue login: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _addUser() async {
    final request = await showDialog<_AddUserRequest>(
      context: context,
      builder: (_) => const _AddUserDialog(),
    );
    if (request == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await widget.shopService.addShopUser(
        slug: widget.slug,
        role: request.role,
        displayName: request.displayName,
        username: request.username,
        password: request.password,
      );
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        await showDialog(
          context: context,
          builder: (_) => _ReissueSuccessDialog(result: result),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add user: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _editUser(ShopUser user) async {
    final request = await showDialog<_EditUserRequest>(
      context: context,
      builder: (_) => _EditUserDialog(user: user),
    );
    if (request == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await widget.shopService.updateShopUser(
        slug: widget.slug,
        uid: user.id,
        displayName: request.displayName,
        role: request.role,
        isEnabled: request.isEnabled,
      );
      if (mounted) Navigator.of(context).pop(); // dismiss progress dialog
      await _load();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: ${describeError(e)}')),
        );
      }
    }
  }

  Future<void> _deleteUser(ShopUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this user?'),
        content: Text(
          'This removes "${user.displayName}" (${user.username}) from the shop. '
          'Their login will stop working immediately. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await widget.shopService.deleteShopUser(slug: widget.slug, uid: user.id);
      if (mounted) Navigator.of(context).pop(); // dismiss progress dialog
      await _load();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove user: ${describeError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_shop?.name ?? widget.slug),
        actions: [
          if (_shop != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              tooltip: 'Delete shop',
              onPressed: _confirmAndDelete,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _shop == null
                  ? const Center(child: Text('Shop not found.'))
                  : RefreshIndicator(
                      onRefresh: () => Future.wait(
                        [_load(), _loadStats(), _loadSeries(), _loadProducts()],
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_shop!.name,
                                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                    )),
                                            const SizedBox(height: 6),
                                            _CodeChip(code: _shop!.slug),
                                          ],
                                        ),
                                      ),
                                      _ActiveBadge(isActive: _shop!.isActive),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  const Divider(height: 1),
                                  const SizedBox(height: 14),
                                  _InfoRow(
                                    icon: Icons.badge_outlined,
                                    label: 'Owner UID',
                                    value: _shop!.ownerUid,
                                  ),
                                  const SizedBox(height: 10),
                                  _InfoRow(
                                    icon: Icons.event_outlined,
                                    label: 'Created',
                                    value: _shop!.createdAt,
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  _StaffLimitRow(
                                    limit: _shop!.staffLimit,
                                    used: _users.where((u) => u.role == 'staff' && !u.isDeleted).length,
                                    onEdit: _editStaffLimit,
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  _ProductLimitRow(
                                    limit: _shop!.productLimit,
                                    used: _stats?.productCount ?? 0,
                                    onEdit: _editProductLimit,
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Active'),
                                    subtitle: const Text(
                                        'Inactive shops are blocked from mobile login'),
                                    value: _shop!.isActive,
                                    onChanged: _togglingActive ? null : (v) => _toggleActive(v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(Icons.insights_outlined, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Statistics',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _DateFilterRow(
                            selected: _filter,
                            customRange: _customRange,
                            onSelect: _selectFilter,
                          ),
                          const SizedBox(height: 10),
                          _StatsSection(loading: _statsLoading, stats: _stats),
                          const SizedBox(height: 16),
                          TrendChart(
                            loading: _seriesLoading,
                            series: _dailySeries,
                            rangeLabel: _resolveChartWindow().$3,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Transactions',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Switch(
                                value: _showTransactions,
                                onChanged: (v) {
                                  setState(() => _showTransactions = v);
                                  if (v) _openTransactionsModal();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'View sales, expenses, and additional income for this shop.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(Icons.group_outlined, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Users (${_users.length})',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _addUser,
                                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                                label: const Text('Add user'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_users.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'No users yet.',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                            )
                          else ...[
                            _ActiveUserCountsRow(users: _users),
                            const SizedBox(height: 14),
                            _UserGroup(
                              label: 'Owners',
                              users: _users.where((u) => u.role == 'owner').toList(),
                              onReissueLogin: _reissueLogin,
                              onEdit: _editUser,
                              onDelete: _deleteUser,
                            ),
                            const SizedBox(height: 16),
                            _UserGroup(
                              label: 'Staff',
                              users: _users.where((u) => u.role != 'owner').toList(),
                              onReissueLogin: _reissueLogin,
                              onEdit: _editUser,
                              onDelete: _deleteUser,
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Products (${_products.length})',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_showProducts)
                                TextButton.icon(
                                  onPressed: _addProduct,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add product'),
                                ),
                              const SizedBox(width: 4),
                              Switch(
                                value: _showProducts,
                                onChanged: (v) => setState(() => _showProducts = v),
                              ),
                            ],
                          ),
                          if (_showProducts) ...[
                            const SizedBox(height: 10),
                            _ProductsSection(
                              loading: _productsLoading,
                              products: _products,
                              onEdit: _editProduct,
                              onDelete: _deleteProduct,
                            ),
                          ],
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        isActive ? Icons.check_circle : Icons.pause_circle_outline,
        size: 16,
        color: isActive ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
      ),
      label: Text(isActive ? 'Active' : 'Inactive'),
      backgroundColor: isActive
          ? colorScheme.tertiaryContainer.withValues(alpha: 0.6)
          : colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isActive ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

class _AddUserRequest {
  const _AddUserRequest({
    required this.role,
    required this.displayName,
    required this.username,
    required this.password,
  });

  final String role;
  final String displayName;
  final String username;
  final String password;
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'staff';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogHeader(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Add owner or staff',
                  subtitle: 'Creates a new login for this shop',
                ),
                const SizedBox(height: 22),
                _RoleSelector(role: _role, onChanged: (v) => setState(() => _role = v)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          _AddUserRequest(
                            role: _role,
                            displayName: _displayNameController.text.trim(),
                            username: _usernameController.text.trim(),
                            password: _passwordController.text,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add user'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'staff',
          label: Text('Staff'),
          icon: Icon(Icons.badge_outlined, size: 17),
        ),
        ButtonSegment(
          value: 'owner',
          label: Text('Owner'),
          icon: Icon(Icons.workspace_premium_outlined, size: 17),
        ),
      ],
      selected: {role},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

class _EditUserRequest {
  const _EditUserRequest({
    required this.displayName,
    required this.role,
    required this.isEnabled,
  });

  final String displayName;
  final String role;
  final bool isEnabled;
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user});

  final ShopUser user;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _displayNameController = TextEditingController(text: widget.user.displayName);
  late String _role = widget.user.role;
  late bool _isEnabled = widget.user.isEnabled;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogHeader(
                  icon: Icons.edit_outlined,
                  title: 'Edit user',
                  subtitle: widget.user.username,
                ),
                const SizedBox(height: 22),
                _RoleSelector(role: _role, onChanged: (v) => setState(() => _role = v)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Material(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  child: SwitchListTile(
                    title: const Text('Enabled'),
                    subtitle: const Text('Disabled users keep their record but can\'t sign in'),
                    value: _isEnabled,
                    onChanged: (v) => setState(() => _isEnabled = v),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          _EditUserRequest(
                            displayName: _displayNameController.text.trim(),
                            role: _role,
                            isEnabled: _isEnabled,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReissueRequest {
  const _ReissueRequest({required this.username, required this.password});

  final String username;
  final String password;
}

class _ReissueLoginDialog extends StatefulWidget {
  const _ReissueLoginDialog({required this.user});

  final ShopUser user;

  @override
  State<_ReissueLoginDialog> createState() => _ReissueLoginDialogState();
}

class _ReissueLoginDialogState extends State<_ReissueLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Reissue login for ${widget.user.displayName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The current login "${widget.user.username}" will stop working '
              'immediately. Give them a new username and password to sign in with.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'New username'),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Required';
                if (value == widget.user.username) return 'Must differ from the current username';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _ReissueRequest(
                username: _usernameController.text.trim(),
                password: _passwordController.text,
              ),
            );
          },
          child: const Text('Reissue login'),
        ),
      ],
    );
  }
}

class _ReissueSuccessDialog extends StatelessWidget {
  const _ReissueSuccessDialog({required this.result});

  final ReissueLoginResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Login reissued'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Relay these new credentials to them — the old login no longer works:'),
          const SizedBox(height: 12),
          CredentialRow(label: 'Username', value: result.username),
          CredentialRow(label: 'Password', value: result.password, isSensitive: true),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _StaffLimitRow extends StatelessWidget {
  const _StaffLimitRow({required this.limit, required this.used, required this.onEdit});

  final int? limit;
  final int used;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final overLimit = limit != null && used > limit!;
    final valueText = limit == null ? 'Unlimited' : '$used / $limit staff';

    return Row(
      children: [
        Icon(Icons.groups_2_outlined, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text('Staff limit', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            valueText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: overLimit ? colorScheme.error : null,
            ),
          ),
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(minimumSize: const Size(40, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

class _StaffLimitResult {
  const _StaffLimitResult(this.limit);

  final int? limit;
}

class _ProductLimitRow extends StatelessWidget {
  const _ProductLimitRow({required this.limit, required this.used, required this.onEdit});

  final int? limit;
  final int used;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final overLimit = limit != null && used > limit!;
    final valueText = limit == null ? 'Unlimited' : '$used / $limit products';

    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text('Product limit', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            valueText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: overLimit ? colorScheme.error : null,
            ),
          ),
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(minimumSize: const Size(40, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

class _ProductLimitResult {
  const _ProductLimitResult(this.limit);

  final int? limit;
}

class _ProductLimitDialog extends StatefulWidget {
  const _ProductLimitDialog({required this.currentLimit});

  final int? currentLimit;

  @override
  State<_ProductLimitDialog> createState() => _ProductLimitDialogState();
}

class _ProductLimitDialogState extends State<_ProductLimitDialog> {
  late bool _unlimited = widget.currentLimit == null;
  late final _controller = TextEditingController(
    text: widget.currentLimit == null ? '' : '${widget.currentLimit}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Product limit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Max number of products the owner can create from the mobile app. '
            'Owners already over the limit keep their existing products.',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unlimited'),
            value: _unlimited,
            onChanged: (v) => setState(() => _unlimited = v),
          ),
          if (!_unlimited)
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max products'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_unlimited) {
              Navigator.of(context).pop(const _ProductLimitResult(null));
              return;
            }
            final value = int.tryParse(_controller.text.trim());
            if (value == null || value < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid number')),
              );
              return;
            }
            Navigator.of(context).pop(_ProductLimitResult(value));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _StaffLimitDialog extends StatefulWidget {
  const _StaffLimitDialog({required this.currentLimit});

  final int? currentLimit;

  @override
  State<_StaffLimitDialog> createState() => _StaffLimitDialogState();
}

class _StaffLimitDialogState extends State<_StaffLimitDialog> {
  late bool _unlimited = widget.currentLimit == null;
  late final _controller = TextEditingController(
    text: widget.currentLimit == null ? '' : '${widget.currentLimit}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Staff limit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Max number of staff the owner can create from the mobile app. '
            'Owners already over the limit keep their existing staff.',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unlimited'),
            value: _unlimited,
            onChanged: (v) => setState(() => _unlimited = v),
          ),
          if (!_unlimited)
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max staff'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_unlimited) {
              Navigator.of(context).pop(const _StaffLimitResult(null));
              return;
            }
            final value = int.tryParse(_controller.text.trim());
            if (value == null || value < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid number')),
              );
              return;
            }
            Navigator.of(context).pop(_StaffLimitResult(value));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeleteShopDialog extends StatefulWidget {
  const _DeleteShopDialog({required this.slug, required this.shopName});

  final String slug;
  final String shopName;

  @override
  State<_DeleteShopDialog> createState() => _DeleteShopDialogState();
}

class _DeleteShopDialogState extends State<_DeleteShopDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          const Expanded(child: Text('Delete this shop?')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes "${widget.shopName}" (${widget.slug}), '
            'its owner and staff records, and all products, sales, expenses, '
            'and income data. Staff will immediately lose access. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          Text(
            'Type the shop code "${widget.slug}" to confirm:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _matches = v == widget.slug),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow({
    required this.selected,
    required this.customRange,
    required this.onSelect,
  });

  final _DateFilter selected;
  final DateTimeRange? customRange;
  final ValueChanged<_DateFilter> onSelect;

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final customLabel = selected == _DateFilter.custom && customRange != null
        ? '${_formatDate(customRange!.start)} - ${_formatDate(customRange!.end)}'
        : 'Custom range';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Daily'),
          selected: selected == _DateFilter.day,
          onSelected: (_) => onSelect(_DateFilter.day),
        ),
        ChoiceChip(
          label: const Text('Weekly'),
          selected: selected == _DateFilter.week,
          onSelected: (_) => onSelect(_DateFilter.week),
        ),
        ChoiceChip(
          label: const Text('Monthly'),
          selected: selected == _DateFilter.month,
          onSelected: (_) => onSelect(_DateFilter.month),
        ),
        ChoiceChip(
          label: const Text('All time'),
          selected: selected == _DateFilter.allTime,
          onSelected: (_) => onSelect(_DateFilter.allTime),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.date_range_outlined, size: 16),
          label: Text(customLabel),
          selected: selected == _DateFilter.custom,
          onSelected: (_) => onSelect(_DateFilter.custom),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.loading, required this.stats});

  final bool loading;
  final ShopStats? stats;


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final s = stats;
    if (s == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Statistics unavailable.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final profitPositive = s.netProfit >= 0;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatTile(
          icon: Icons.trending_up_rounded,
          label: 'Revenue',
          value: _formatMoney(s.totalRevenue),
          color: colorScheme.tertiary,
          containerColor: colorScheme.tertiaryContainer,
        ),
        _StatTile(
          icon: Icons.inventory_outlined,
          label: 'Cost of goods',
          value: _formatMoney(s.totalCogs),
          color: colorScheme.error,
          containerColor: colorScheme.errorContainer,
        ),
        _StatTile(
          icon: Icons.trending_down_rounded,
          label: 'Expenses',
          value: _formatMoney(s.totalExpenses),
          color: colorScheme.error,
          containerColor: colorScheme.errorContainer,
        ),
        _StatTile(
          icon: Icons.add_circle_outline,
          label: 'Other income',
          value: _formatMoney(s.totalAdditionalIncome),
          color: colorScheme.primary,
          containerColor: colorScheme.primaryContainer,
        ),
        _StatTile(
          icon: profitPositive ? Icons.savings_outlined : Icons.warning_amber_rounded,
          label: 'Net profit',
          value: _formatMoney(s.netProfit),
          color: profitPositive ? colorScheme.tertiary : colorScheme.error,
          containerColor: profitPositive ? colorScheme.tertiaryContainer : colorScheme.errorContainer,
        ),
        _StatTile(
          icon: Icons.receipt_long_outlined,
          label: 'Sales',
          value: '${s.salesCount}',
          color: colorScheme.onSurfaceVariant,
          containerColor: colorScheme.surfaceContainerHighest,
        ),
        _StatTile(
          icon: Icons.inventory_2_outlined,
          label: 'Products',
          value: '${s.productCount}',
          color: colorScheme.onSurfaceVariant,
          containerColor: colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: containerColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveUserCountsRow extends StatelessWidget {
  const _ActiveUserCountsRow({required this.users});

  final List<ShopUser> users;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeOwners = users.where((u) => u.role == 'owner' && u.isEnabled && !u.isDeleted).length;
    final activeStaff = users.where((u) => u.role != 'owner' && u.isEnabled && !u.isDeleted).length;

    return Row(
      children: [
        Expanded(
          child: _CountChip(
            icon: Icons.workspace_premium_outlined,
            label: 'Active owners',
            count: activeOwners,
            color: colorScheme.primary,
            containerColor: colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CountChip(
            icon: Icons.badge_outlined,
            label: 'Active staff',
            count: activeStaff,
            color: colorScheme.tertiary,
            containerColor: colorScheme.tertiaryContainer,
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.containerColor,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: containerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(label, style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserGroup extends StatelessWidget {
  const _UserGroup({
    required this.label,
    required this.users,
    required this.onReissueLogin,
    required this.onEdit,
    required this.onDelete,
  });

  final String label;
  final List<ShopUser> users;
  final ValueChanged<ShopUser> onReissueLogin;
  final ValueChanged<ShopUser> onEdit;
  final ValueChanged<ShopUser> onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeCount = users.where((u) => u.isEnabled && !u.isDeleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · $activeCount active of ${users.length}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (users.isEmpty)
          Text('None yet.', style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant))
        else
          for (final u in users) ...[
            _UserCard(
              user: u,
              onReissueLogin: () => onReissueLogin(u),
              onEdit: () => onEdit(u),
              onDelete: () => onDelete(u),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onReissueLogin,
    required this.onEdit,
    required this.onDelete,
  });

  final ShopUser user;
  final VoidCallback onReissueLogin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarColor = avatarColorForName(user.displayName);
    final isOwner = user.role == 'owner';

    final identityRow = Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: avatarColor.withValues(alpha: 0.15),
          foregroundColor: avatarColor,
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: SelectableText(
                      '${user.username} · ${user.email}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    tooltip: 'Copy login email',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: user.email));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Login email copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final actionsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(user.role),
          backgroundColor: isOwner
              ? colorScheme.primaryContainer.withValues(alpha: 0.6)
              : colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: isOwner ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          ),
        ),
        if (!user.isEnabled) ...[
          const SizedBox(width: 6),
          Icon(Icons.block, size: 16, color: colorScheme.error),
        ],
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 20, color: colorScheme.onSurfaceVariant),
          tooltip: 'User actions',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'reissue':
                onReissueLogin();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (menuContext) {
            final menuColors = Theme.of(menuContext).colorScheme;
            return [
              PopupMenuItem(
                value: 'edit',
                height: 40,
                child: _MenuRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: menuColors.onSurface,
                ),
              ),
              PopupMenuItem(
                value: 'reissue',
                height: 40,
                child: _MenuRow(
                  icon: Icons.lock_reset_rounded,
                  label: 'Reissue login',
                  color: menuColors.primary,
                ),
              ),
              const PopupMenuDivider(height: 8),
              PopupMenuItem(
                value: 'delete',
                height: 40,
                child: _MenuRow(
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  color: menuColors.error,
                ),
              ),
            ];
          },
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identityRow,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actionsRow),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identityRow),
                actionsRow,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontSize: 13.5)),
      ],
    );
  }
}

String _formatMoney(double value) => 'Rs ${value.toStringAsFixed(2)}';

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({
    required this.loading,
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  final bool loading;
  final List<Product> products;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No products yet.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final product in products)
          _ProductCard(
            product: product,
            onTap: () => showDialog(
              context: context,
              builder: (_) => _ProductDetailDialog(product: product),
            ),
            onEdit: () => onEdit(product),
            onDelete: () => onDelete(product),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outOfStock = product.stock != null && product.stock! <= 0;

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _ProductImage(url: product.imageUrl),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: colorScheme.surface.withValues(alpha: 0.85),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: colorScheme.onSurface),
                        tooltip: 'Product actions',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              onEdit();
                            case 'delete':
                              onDelete();
                          }
                        },
                        itemBuilder: (menuContext) {
                          final menuColors = Theme.of(menuContext).colorScheme;
                          return [
                            PopupMenuItem(
                              value: 'edit',
                              height: 40,
                              child: _MenuRow(
                                icon: Icons.edit_outlined,
                                label: 'Edit',
                                color: menuColors.onSurface,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              height: 40,
                              child: _MenuRow(
                                icon: Icons.delete_outline,
                                label: 'Delete',
                                color: menuColors.error,
                              ),
                            ),
                          ];
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    if (product.category != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.category!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          product.price != null ? _formatMoney(product.price!) : '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        if (product.stock != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: outOfStock
                                  ? colorScheme.errorContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              outOfStock ? 'Out of stock' : '${product.stock} left',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: outOfStock ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, color: colorScheme.onSurfaceVariant, size: 32),
    );

    final imageUrl = url;
    if (imageUrl == null) return placeholder;

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _ProductDetailDialog extends StatelessWidget {
  const _ProductDetailDialog({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outOfStock = product.stock != null && product.stock! <= 0;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _ProductImage(url: product.imageUrl),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (product.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.category!,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (product.price != null)
                          Expanded(
                            child: _ProductDetailStat(
                              label: 'Price',
                              value: _formatMoney(product.price!),
                            ),
                          ),
                        if (product.cost != null)
                          Expanded(
                            child: _ProductDetailStat(
                              label: 'Cost',
                              value: _formatMoney(product.cost!),
                            ),
                          ),
                        if (product.stock != null)
                          Expanded(
                            child: _ProductDetailStat(
                              label: 'Stock',
                              value: outOfStock ? 'Out of stock' : '${product.stock}',
                              valueColor: outOfStock ? colorScheme.error : null,
                            ),
                          ),
                      ],
                    ),
                    if (product.sku != null) ...[
                      const SizedBox(height: 14),
                      _InfoRow(icon: Icons.qr_code_outlined, label: 'SKU', value: product.sku!),
                    ],
                    if (product.description != null && product.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Text(
                        product.description!,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductDetailStat extends StatelessWidget {
  const _ProductDetailStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: valueColor),
        ),
      ],
    );
  }
}

class _ProductFormResult {
  const _ProductFormResult({
    required this.name,
    this.description,
    this.category,
    this.sku,
    this.price,
    this.cost,
    this.stock,
    this.newImageBytes,
    this.newImageExt,
  });

  final String name;
  final String? description;
  final String? category;
  final String? sku;
  final double? price;
  final double? cost;
  final int? stock;

  /// Null means "no new image picked" — on edit, the product keeps its
  /// existing image; on add, it's created with no image.
  final Uint8List? newImageBytes;
  final String? newImageExt;
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

  /// Null for "add product"; set for "edit product".
  final Product? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.product?.name ?? '');
  late final _descriptionController = TextEditingController(text: widget.product?.description ?? '');
  late final _categoryController = TextEditingController(text: widget.product?.category ?? '');
  late final _skuController = TextEditingController(text: widget.product?.sku ?? '');
  late final _priceController = TextEditingController(
    text: widget.product?.price == null ? '' : '${widget.product!.price}',
  );
  late final _costController = TextEditingController(
    text: widget.product?.cost == null ? '' : '${widget.product!.cost}',
  );
  late final _stockController = TextEditingController(
    text: widget.product?.stock == null ? '' : '${widget.product!.stock}',
  );

  Uint8List? _pickedBytes;
  String? _pickedExt;
  bool _picking = false;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      if (mounted) {
        setState(() {
          _pickedBytes = bytes;
          _pickedExt = ext;
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final existingImageUrl = widget.product?.imageUrl;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogHeader(
                    icon: _isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                    title: _isEdit ? 'Edit product' : 'Add product',
                    subtitle: _isEdit
                        ? 'Updates this product in the shop\'s catalog'
                        : 'Creates a new product in the shop\'s catalog',
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: InkWell(
                      onTap: _picking ? null : _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 120,
                        height: 120,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _picking
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : _pickedBytes != null
                                ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                                : existingImageUrl != null
                                    ? _ProductImage(url: existingImageUrl)
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_outlined,
                                              color: colorScheme.onSurfaceVariant),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Add photo',
                                            style: TextStyle(
                                                color: colorScheme.onSurfaceVariant, fontSize: 11),
                                          ),
                                        ],
                                      ),
                      ),
                    ),
                  ),
                  if (existingImageUrl != null || _pickedBytes != null) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _picking ? null : _pickImage,
                        child: const Text('Change photo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(labelText: 'Category'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(labelText: 'SKU'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Price'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.trim()) == null ? 'Invalid' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(labelText: 'Cost'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.trim()) == null ? 'Invalid' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(labelText: 'Stock'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null ? 'Invalid' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          String? text(TextEditingController c) =>
                              c.text.trim().isEmpty ? null : c.text.trim();
                          Navigator.of(context).pop(
                            _ProductFormResult(
                              name: _nameController.text.trim(),
                              description: text(_descriptionController),
                              category: text(_categoryController),
                              sku: text(_skuController),
                              price: double.tryParse(_priceController.text.trim()),
                              cost: double.tryParse(_costController.text.trim()),
                              stock: int.tryParse(_stockController.text.trim()),
                              newImageBytes: _pickedBytes,
                              newImageExt: _pickedExt,
                            ),
                          );
                        },
                        icon: Icon(_isEdit ? Icons.check : Icons.add, size: 18),
                        label: Text(_isEdit ? 'Save' : 'Add product'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final datePart =
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$datePart · $hour12:$minute $period';
}

enum _TxFilter { today, weekly, monthly, custom }

class _TransactionsModal extends StatefulWidget {
  const _TransactionsModal({required this.shopService, required this.slug});

  final ShopService shopService;
  final String slug;

  @override
  State<_TransactionsModal> createState() => _TransactionsModalState();
}

class _TransactionsModalState extends State<_TransactionsModal> {
  _TxFilter _filter = _TxFilter.today;
  DateTimeRange? _customRange;
  List<ShopTransaction> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  StatsDateRange _resolveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case _TxFilter.today:
        return StatsDateRange(start: today, end: today);
      case _TxFilter.weekly:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return StatsDateRange(start: DateTime(monday.year, monday.month, monday.day), end: today);
      case _TxFilter.monthly:
        return StatsDateRange(start: DateTime(now.year, now.month, 1), end: today);
      case _TxFilter.custom:
        final range = _customRange;
        if (range == null) return StatsDateRange(start: today, end: today);
        return StatsDateRange(start: range.start, end: range.end);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final transactions = await widget.shopService.getShopTransactions(
        widget.slug,
        range: _resolveRange(),
      );
      if (mounted) setState(() => _transactions = transactions);
    } catch (_) {
      if (mounted) setState(() => _transactions = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectFilter(_TxFilter filter) async {
    if (filter == _TxFilter.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange:
            _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      );
      if (picked == null) return;
      setState(() {
        _filter = _TxFilter.custom;
        _customRange = picked;
      });
    } else {
      setState(() => _filter = filter);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Transactions (${_transactions.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TxFilterRow(selected: _filter, customRange: _customRange, onSelect: _selectFilter),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _transactions.isEmpty
                        ? Center(
                            child: Text(
                              'No transactions in this range.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: _transactions.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) => _TransactionRow(transaction: _transactions[i]),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TxFilterRow extends StatelessWidget {
  const _TxFilterRow({required this.selected, required this.customRange, required this.onSelect});

  final _TxFilter selected;
  final DateTimeRange? customRange;
  final ValueChanged<_TxFilter> onSelect;

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final customLabel = selected == _TxFilter.custom && customRange != null
        ? '${_formatDate(customRange!.start)} - ${_formatDate(customRange!.end)}'
        : 'Custom';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: selected == _TxFilter.today,
          onSelected: (_) => onSelect(_TxFilter.today),
        ),
        ChoiceChip(
          label: const Text('Weekly'),
          selected: selected == _TxFilter.weekly,
          onSelected: (_) => onSelect(_TxFilter.weekly),
        ),
        ChoiceChip(
          label: const Text('Monthly'),
          selected: selected == _TxFilter.monthly,
          onSelected: (_) => onSelect(_TxFilter.monthly),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.date_range_outlined, size: 16),
          label: Text(customLabel),
          selected: selected == _TxFilter.custom,
          onSelected: (_) => onSelect(_TxFilter.custom),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final ShopTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, label, iconColor, positive) = switch (transaction.type) {
      ShopTransactionType.sale => (
          Icons.point_of_sale_outlined,
          'Sale',
          colorScheme.primary,
          true,
        ),
      ShopTransactionType.expense => (
          Icons.trending_down_rounded,
          'Expense',
          colorScheme.error,
          false,
        ),
      ShopTransactionType.income => (
          Icons.add_circle_outline,
          'Additional income',
          colorScheme.tertiary,
          true,
        ),
    };

    final subtitleParts = <String>[
      if (transaction.type == ShopTransactionType.sale && transaction.itemCount != null)
        '${transaction.itemCount} item${transaction.itemCount == 1 ? '' : 's'}',
      if (transaction.note != null) transaction.note!,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : '-'}${_formatMoney(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: positive ? colorScheme.tertiary : colorScheme.error,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                transaction.createdAt != null ? _formatDateTime(transaction.createdAt!) : '—',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
