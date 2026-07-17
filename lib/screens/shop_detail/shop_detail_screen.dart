import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/shop.dart';
import '../../models/shop_stats.dart';
import '../../models/shop_user.dart';
import '../../services/shop_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/date_format.dart';
import '../../utils/error_utils.dart';
import '../../widgets/trend_chart.dart';
import 'widgets/delete_dialogs.dart';
import 'widgets/filter_row.dart';
import 'widgets/info_rows.dart';
import 'widgets/limit_row_and_dialog.dart';
import 'widgets/product_dialogs.dart';
import 'widgets/product_widgets.dart';
import 'widgets/stat_widgets.dart';
import 'widgets/transactions_modal.dart';
import 'widgets/user_dialogs.dart';
import 'widgets/user_widgets.dart';

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
  bool _togglingStaffDelete = false;
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
        return (
          today.subtract(const Duration(days: 29)),
          today,
          'last 30 days',
        );
      case _DateFilter.day:
        return (today.subtract(const Duration(days: 6)), today, 'last 7 days');
      case _DateFilter.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (
          DateTime(monday.year, monday.month, monday.day),
          today,
          'this week',
        );
      case _DateFilter.month:
        return (DateTime(now.year, now.month, 1), today, 'this month');
      case _DateFilter.custom:
        final range = _customRange;
        if (range == null) {
          return (
            today.subtract(const Duration(days: 29)),
            today,
            'last 30 days',
          );
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
      final series = await widget.shopService.getDailySeries(
        widget.slug,
        start: start,
        end: end,
      );
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
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
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
      if (mounted) {
        setState(() => _error = 'Failed to load shop: ${describeError(e)}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final stats = await widget.shopService.getShopStats(
        widget.slug,
        range: _resolveRange(),
      );
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

  Future<void> _toggleStaffDelete(bool newValue) async {
    setState(() => _togglingStaffDelete = true);
    try {
      await widget.shopService.setStaffDeleteEnabled(widget.slug, newValue);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${describeError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingStaffDelete = false);
    }
  }

  Future<void> _editMaxActiveDevices() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => MinOneValueDialog(
        title: 'Max active devices per user',
        description:
            'Max number of devices a user can be signed in on at once. '
            'Signing in on a new device beyond this limit signs out the '
            'oldest session(s).',
        fieldLabel: 'Max devices',
        currentValue: _shop!.maxActiveDevices,
      ),
    );
    if (result == null) return; // cancelled

    try {
      await widget.shopService.setMaxActiveDevices(widget.slug, result);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update max active devices: ${describeError(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editStaffLimit() async {
    final result = await showDialog<LimitResult>(
      context: context,
      builder: (_) => LimitDialog(
        title: 'Staff limit',
        description:
            'Max number of staff the owner can create from the mobile app. '
            'Owners already over the limit keep their existing staff.',
        fieldLabel: 'Max staff',
        currentLimit: _shop!.staffLimit,
      ),
    );
    if (result == null) return; // cancelled

    try {
      await widget.shopService.setStaffLimit(widget.slug, result.limit);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update staff limit: ${describeError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _editProductLimit() async {
    final result = await showDialog<LimitResult>(
      context: context,
      builder: (_) => LimitDialog(
        title: 'Product limit',
        description:
            'Max number of products the owner can create from the mobile app. '
            'Owners already over the limit keep their existing products.',
        fieldLabel: 'Max products',
        currentLimit: _shop!.productLimit,
      ),
    );
    if (result == null) return; // cancelled

    try {
      await widget.shopService.setProductLimit(widget.slug, result.limit);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update product limit: ${describeError(e)}',
            ),
          ),
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
      builder: (_) =>
          TransactionsModal(shopService: widget.shopService, slug: widget.slug),
    );
    if (mounted) setState(() => _showTransactions = false);
  }

  Future<void> _addProduct() async {
    final result = await showDialog<ProductFormResult>(
      context: context,
      builder: (_) => const ProductFormDialog(),
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
    final result = await showDialog<ProductFormResult>(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
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
          SnackBar(
            content: Text('Failed to update product: ${describeError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Delete this product?',
        message:
            'This removes "${product.name}" from the shop\'s catalog. This cannot be undone.',
        confirmLabel: 'Delete',
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
          SnackBar(
            content: Text('Failed to delete product: ${describeError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          DeleteShopDialog(slug: widget.slug, shopName: _shop!.name),
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
    final request = await showDialog<ReissueRequest>(
      context: context,
      builder: (_) => ReissueLoginDialog(user: user),
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
          builder: (_) => ReissueSuccessDialog(result: result),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reissue login: ${describeError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _addUser() async {
    final request = await showDialog<AddUserRequest>(
      context: context,
      builder: (_) => const AddUserDialog(),
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
          builder: (_) => ReissueSuccessDialog(result: result),
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
    final request = await showDialog<EditUserRequest>(
      context: context,
      builder: (_) => EditUserDialog(user: user),
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

  void _viewDevices(ShopUser user) {
    showDialog(
      context: context,
      builder: (_) => ActiveDevicesDialog(
        shopService: widget.shopService,
        slug: widget.slug,
        user: user,
      ),
    );
  }

  Future<void> _deleteUser(ShopUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Remove this user?',
        message:
            'This removes "${user.displayName}" (${user.username}) from the shop. '
            'Their login will stop working immediately. This cannot be undone.',
        confirmLabel: 'Remove',
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
              onRefresh: () => Future.wait([
                _load(),
                _loadStats(),
                _loadSeries(),
                _loadProducts(),
              ]),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _shop!.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        CodeChip(code: _shop!.slug),
                                      ],
                                    ),
                                  ),
                                  ActiveBadge(isActive: _shop!.isActive),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              InfoRow(
                                icon: Icons.badge_outlined,
                                label: 'Owner UID',
                                value: _shop!.ownerUid,
                              ),
                              const SizedBox(height: 10),
                              InfoRow(
                                icon: Icons.event_outlined,
                                label: 'Created',
                                value: _shop!.createdAt,
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              LimitRow(
                                icon: Icons.groups_2_outlined,
                                label: 'Staff limit',
                                unit: 'staff',
                                limit: _shop!.staffLimit,
                                used: _users
                                    .where(
                                      (u) => u.role == 'staff' && !u.isDeleted,
                                    )
                                    .length,
                                onEdit: _editStaffLimit,
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              LimitRow(
                                icon: Icons.inventory_2_outlined,
                                label: 'Product limit',
                                unit: 'products',
                                limit: _shop!.productLimit,
                                used: _stats?.productCount ?? 0,
                                onEdit: _editProductLimit,
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              SettingValueRow(
                                icon: Icons.devices_outlined,
                                label: 'Max devices',
                                value:
                                    '${_shop!.maxActiveDevices} per user',
                                onEdit: _editMaxActiveDevices,
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Active'),
                                subtitle: const Text(
                                  'Inactive shops are blocked from mobile login',
                                ),
                                value: _shop!.isActive,
                                onChanged: _togglingActive
                                    ? null
                                    : (v) => _toggleActive(v),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Allow staff deletion'),
                                subtitle: const Text(
                                  'Shows a Delete option for staff members '
                                  'in the mobile app',
                                ),
                                value: _shop!.staffDeleteEnabled,
                                onChanged: _togglingStaffDelete
                                    ? null
                                    : (v) => _toggleStaffDelete(v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.insights_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Statistics',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilterRow<_DateFilter>(
                        selected: _filter,
                        onSelect: _selectFilter,
                        options: [
                          const FilterOption(
                            value: _DateFilter.day,
                            label: 'Daily',
                          ),
                          const FilterOption(
                            value: _DateFilter.week,
                            label: 'Weekly',
                          ),
                          const FilterOption(
                            value: _DateFilter.month,
                            label: 'Monthly',
                          ),
                          const FilterOption(
                            value: _DateFilter.allTime,
                            label: 'All time',
                          ),
                          FilterOption(
                            value: _DateFilter.custom,
                            label:
                                _filter == _DateFilter.custom &&
                                    _customRange != null
                                ? '${formatShortDate(_customRange!.start)} - ${formatShortDate(_customRange!.end)}'
                                : 'Custom range',
                            avatar: (_) =>
                                const Icon(Icons.date_range_outlined, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StatsSection(loading: _statsLoading, stats: _stats),
                      const SizedBox(height: 16),
                      TrendChart(
                        loading: _seriesLoading,
                        series: _dailySeries,
                        rangeLabel: _resolveChartWindow().$3,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Transactions',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
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
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Users (${_users.length})',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addUser,
                            icon: const Icon(
                              Icons.person_add_alt_1_outlined,
                              size: 18,
                            ),
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
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        ActiveUserCountsRow(users: _users),
                        const SizedBox(height: 14),
                        UserGroup(
                          label: 'Owners',
                          users: _users
                              .where((u) => u.role == 'owner')
                              .toList(),
                          onReissueLogin: _reissueLogin,
                          onEdit: _editUser,
                          onDelete: _deleteUser,
                          onViewDevices: _viewDevices,
                        ),
                        const SizedBox(height: 16),
                        UserGroup(
                          label: 'Staff',
                          users: _users
                              .where((u) => u.role != 'owner')
                              .toList(),
                          onReissueLogin: _reissueLogin,
                          onEdit: _editUser,
                          onDelete: _deleteUser,
                          onViewDevices: _viewDevices,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Products (${_products.length})',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
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
                        ProductsSection(
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
