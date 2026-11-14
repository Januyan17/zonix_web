import 'package:flutter/material.dart';

import 'package:zonixweb/core/services/supabase_storage_service.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/utils/snackbar.dart';
import 'package:zonixweb/core/widgets/delete_confirm_dialog.dart';
import 'package:zonixweb/core/widgets/keep_alive_wrapper.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/billing/widgets/shop_payments_tab.dart';
import 'package:zonixweb/features/device_logins/widgets/recent_device_logins_section.dart';
import 'package:zonixweb/features/history_requests/widgets/history_requests_section.dart';
import 'package:zonixweb/features/shops/models/product.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_activity.dart';
import 'package:zonixweb/features/shops/models/shop_insights.dart';
import 'package:zonixweb/features/shops/models/shop_stats.dart';
import 'package:zonixweb/features/shops/models/shop_user.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';
import 'package:zonixweb/features/shops/utils/shop_activity_aggregate.dart';
import 'package:zonixweb/features/shops/utils/shop_date_filter.dart';
import 'package:zonixweb/features/shops/widgets/products/product_form_dialog.dart';
import 'package:zonixweb/features/shops/widgets/products/products_section.dart';
import 'package:zonixweb/features/shops/widgets/settings/delete_shop_dialog.dart';
import 'package:zonixweb/features/shops/widgets/settings/limit_dialog.dart';
import 'package:zonixweb/features/shops/widgets/settings/max_devices_dialog.dart';
import 'package:zonixweb/features/shops/widgets/settings/shop_links_section.dart';
import 'package:zonixweb/features/shops/widgets/settings/trial_section.dart';
import 'package:zonixweb/features/shops/widgets/shop_summary_card.dart';
import 'package:zonixweb/features/shops/widgets/stats/shop_statistics_section.dart';
import 'package:zonixweb/features/shops/widgets/transactions/transactions_modal.dart';
import 'package:zonixweb/features/shops/widgets/users/active_devices_dialog.dart';
import 'package:zonixweb/features/shops/widgets/users/active_user_counts_row.dart';
import 'package:zonixweb/features/shops/widgets/users/add_user_dialog.dart';
import 'package:zonixweb/features/shops/widgets/users/edit_user_dialog.dart';
import 'package:zonixweb/features/shops/widgets/users/reissue_login_dialog.dart';
import 'package:zonixweb/features/shops/widgets/users/user_group.dart';

class ShopDetailScreen extends StatefulWidget {
  const ShopDetailScreen({
    super.key,
    required this.slug,
    required this.shopService,
    this.initialTab = 0,
  });

  final String slug;
  final ShopService shopService;

  /// 0 = Details, 1 = Payments.
  final int initialTab;

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  static const _sectionGap = SizedBox(height: AppDimens.spacing24);
  static const _headerGap = SizedBox(height: AppDimens.spacing10);

  final _storageService = SupabaseStorageService();

  ShopService get _service => widget.shopService;
  String get _slug => widget.slug;

  Shop? _shop;
  List<ShopUser> _users = [];
  ShopActivity? _activity;
  ShopStats? _stats;
  StatsComparison? _comparison;
  List<ProductPerformance> _performance = const [];
  List<Product> _deadStock = const [];
  List<HourBucket> _hours = const [];
  List<WeekdayBucket> _weekdays = const [];
  VoidStats? _voids;
  List<DailyStat>? _dailySeries;
  List<Product> _products = [];
  bool _loading = true;
  bool _statsLoading = true;
  bool _seriesLoading = true;
  bool _productsLoading = true;
  bool _togglingActive = false;
  bool _togglingStaffDelete = false;
  bool _showProducts = false;
  bool _showShopLinks = false;
  bool _showTransactions = false;
  String? _error;

  ShopDateFilterSelection _selection = const ShopDateFilterSelection();

  @override
  void initState() {
    super.initState();
    _load();
    _loadActivity();
  }

  Future<void> _selectFilter(ShopDateFilter filter) async {
    if (filter == ShopDateFilter.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange:
            _selection.customRange ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      );
      if (picked == null) return;
      setState(() {
        _selection = ShopDateFilterSelection(
          filter: ShopDateFilter.custom,
          customRange: picked,
        );
      });
    } else {
      setState(() {
        _selection = ShopDateFilterSelection(
          filter: filter,
          customRange: _selection.customRange,
        );
      });
    }
    // A narrower filter is answered from the documents already in hand;
    // only one reaching further back than the last fetch goes to the
    // network. Day -> Month costs one read, Month -> Day costs nothing.
    final window = _selection.activityWindow();
    final activity = _activity;
    if (activity != null && activity.covers(from: window.from, to: window.to)) {
      _applyFilter();
    } else {
      _loadActivity();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shop = await _service.getShop(_slug);
      final users = await _service.getShopUsers(_slug);
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

  /// The one read behind the stat tiles, the trend chart and the product
  /// grid alike. All three are derived from the same documents, so they're
  /// fetched together once, for the selected filter's window only, and
  /// re-derived locally afterwards.
  Future<void> _loadActivity() async {
    setState(() {
      _statsLoading = true;
      _seriesLoading = true;
      _productsLoading = true;
    });
    try {
      final window = _selection.activityWindow();
      final activity = await _service.getShopActivity(
        _slug,
        from: window.from,
        to: window.to,
      );
      if (mounted) {
        setState(() {
          _activity = activity;
          _products = productsFrom(activity.products);
        });
        _applyFilter();
      }
    } catch (_) {
      // Stats, chart and products are supplementary; a failure here
      // shouldn't block the rest of the page from showing.
    } finally {
      if (mounted) {
        setState(() {
          _statsLoading = false;
          _seriesLoading = false;
          _productsLoading = false;
        });
      }
    }
  }

  /// Re-derives the tiles and the chart for the selected date filter from
  /// the activity already fetched. No network read.
  void _applyFilter() {
    final activity = _activity;
    if (activity == null) return;
    final (start, end, _) = _selection.chartWindow();
    final range = _selection.range();
    setState(() {
      _stats = statsFrom(activity, range: range);
      _comparison = comparisonFrom(activity, range: range);
      _dailySeries = dailySeriesFrom(activity, start: start, end: end);
      _performance = productPerformanceFrom(activity, range: range);
      _deadStock = deadStockFrom(activity, range: range);
      _hours = hourlySalesFrom(activity, range: range);
      _weekdays = weekdaySalesFrom(activity, range: range);
      _voids = voidedSalesFrom(activity, range: range);
    });
  }

  /// Re-reads just the catalog, after the admin adds, edits or deletes a
  /// product. Those edits leave the transaction documents untouched, so the
  /// rest of the activity is kept as-is rather than re-fetched.
  Future<void> _loadProducts() async {
    setState(() => _productsLoading = true);
    try {
      final docs = await _service.getProductDocs(_slug);
      if (mounted) {
        setState(() {
          _products = productsFrom(docs);
          _activity = _activity?.withProducts(docs);
        });
      }
    } catch (_) {
      // Products are supplementary; a failure here shouldn't block the rest
      // of the page from showing.
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  /// Runs a quick settings write, reloads the shop, then reports the
  /// outcome in a snackbar ([success] is skipped when null).
  Future<void> _saveAndReload<T>(
    Future<T> Function() action, {
    required String failure,
    String Function(T result)? success,
  }) async {
    try {
      final result = await action();
      await _load();
      if (mounted && success != null) {
        showSnackBarMessage(context, success(result));
      }
    } catch (e) {
      if (mounted) {
        showSnackBarMessage(context, '$failure: ${describeError(e)}');
      }
    }
  }

  /// Runs [task] behind a blocking progress dialog. The dialog is dismissed
  /// before [onSuccess] runs, or before the [failure] snackbar is shown.
  Future<void> _runBlocking<T>(
    Future<T> Function() task, {
    required String failure,
    required Future<void> Function(T result) onSuccess,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await task();
      if (!mounted) return;
      Navigator.of(context).pop();
      await onSuccess(result);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnackBarMessage(context, '$failure: ${describeError(e)}');
    }
  }

  Future<void> _toggleActive(bool newValue) async {
    setState(() => _togglingActive = true);
    await _saveAndReload(
      () => _service.setShopActive(_slug, newValue),
      failure: 'Failed to update',
    );
    if (mounted) setState(() => _togglingActive = false);
  }

  Future<void> _toggleStaffDelete(bool newValue) async {
    setState(() => _togglingStaffDelete = true);
    await _saveAndReload(
      () => _service.setStaffDeleteEnabled(_slug, newValue),
      failure: 'Failed to update',
    );
    if (mounted) setState(() => _togglingStaffDelete = false);
  }

  Future<void> _editMaxActiveDevices() async {
    final result = await showDialog<MaxDevicesResult>(
      context: context,
      builder: (_) => MaxDevicesDialog(
        currentStaff: _shop!.maxActiveDevicesStaff,
        currentOwner: _shop!.maxActiveDevicesOwner,
      ),
    );
    if (result == null) return;

    await _saveAndReload(
      () => _service.setMaxActiveDevices(
        _slug,
        staff: result.staff,
        owner: result.owner,
      ),
      failure: 'Failed to update max active devices',
    );
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
    if (result == null) return;

    await _saveAndReload(
      () => _service.setStaffLimit(_slug, result.limit),
      failure: 'Failed to update staff limit',
    );
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
    if (result == null) return;

    await _saveAndReload(
      () => _service.setProductLimit(_slug, result.limit),
      failure: 'Failed to update product limit',
    );
  }

  /// Writes the four link values and the owner-editable switch in one go.
  /// The mobile app watches this document live, so the receipt QR codes
  /// change over on every device within seconds of this returning.
  Future<void> _saveShopLinks(ShopLinksResult links) {
    return _saveAndReload(
      () => _service.setShopLinks(
        _slug,
        website: links.website,
        facebook: links.facebook,
        instagram: links.instagram,
        tiktok: links.tiktok,
        linksEnabled: links.linksEnabled,
      ),
      failure: 'Failed to save links',
      success: (_) => 'Shop links saved',
    );
  }

  /// Starts or ends the shop's free trial. The mobile app watches this
  /// document live: ending the trial unlocks a locked app within seconds.
  Future<void> _toggleTrial(bool enable) {
    return _saveAndReload(
      () => enable ? _service.startTrial(_slug) : _service.endTrial(_slug),
      failure: 'Failed to update trial',
      success: (_) =>
          enable ? 'Free trial started' : 'Trial turned off, app unlocked',
    );
  }

  Future<void> _saveTrialDetails(TrialDetailsResult details) {
    return _saveAndReload(
      () => _service.setTrialDetails(
        _slug,
        message: details.message,
        contact: details.contact,
      ),
      failure: 'Failed to save trial details',
      success: (_) => 'Trial details saved',
    );
  }

  Future<void> _extendTrial(int days) {
    return _saveAndReload(
      () => _service.extendTrial(_slug, days),
      failure: 'Failed to extend trial',
      success: (newEnd) => 'Trial extended to ${formatShortDateTime(newEnd)}',
    );
  }

  /// Opens the transactions list in a bottom sheet, which owns its own
  /// filter and data loading. The header switch is just a trigger, not
  /// persisted state, so it resets once the sheet is dismissed.
  Future<void> _openTransactionsModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusSheetTop),
        ),
      ),
      builder: (_) => TransactionsModal(shopService: _service, slug: _slug),
    );
    if (mounted) setState(() => _showTransactions = false);
  }

  Future<void> _addProduct() async {
    final result = await showDialog<ProductFormResult>(
      context: context,
      builder: (_) => const ProductFormDialog(),
    );
    if (result == null || !mounted) return;

    await _runBlocking(
      () async {
        final id = _service.newProductId(_slug);
        String? imageUrl;
        if (result.newImageBytes != null) {
          imageUrl = await _storageService.uploadProductImage(
            slug: _slug,
            productId: id,
            bytes: result.newImageBytes!,
            fileExt: result.newImageExt!,
          );
        }
        await _service.addProduct(
          slug: _slug,
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
      },
      failure: 'Failed to add product',
      onSuccess: (_) => _loadProducts(),
    );
  }

  Future<void> _editProduct(Product product) async {
    final result = await showDialog<ProductFormResult>(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
    );
    if (result == null || !mounted) return;

    await _runBlocking(
      () async {
        var imageUrl = product.imageUrl;
        if (result.newImageBytes != null) {
          imageUrl = await _storageService.uploadProductImage(
            slug: _slug,
            productId: product.id,
            bytes: result.newImageBytes!,
            fileExt: result.newImageExt!,
          );
        }
        await _service.updateProduct(
          slug: _slug,
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
      },
      failure: 'Failed to update product',
      onSuccess: (_) => _loadProducts(),
    );
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

    await _runBlocking(
      () => _service.deleteProduct(slug: _slug, id: product.id),
      failure: 'Failed to delete product',
      onSuccess: (_) => _loadProducts(),
    );
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteShopDialog(slug: _slug, shopName: _shop!.name),
    );
    if (confirmed != true || !mounted) return;

    await _runBlocking(
      () => _service.deleteShop(_slug),
      failure: 'Failed to delete shop',
      onSuccess: (_) async => Navigator.of(context).pop(),
    );
  }

  Future<void> _showCredentialsThenReload(ReissueLoginResult result) async {
    await showDialog(
      context: context,
      builder: (_) => ReissueSuccessDialog(result: result),
    );
    await _load();
  }

  Future<void> _reissueLogin(ShopUser user) async {
    final request = await showDialog<ReissueRequest>(
      context: context,
      builder: (_) => ReissueLoginDialog(user: user),
    );
    if (request == null || !mounted) return;

    await _runBlocking(
      () => _service.reissueLogin(
        slug: _slug,
        oldUser: user,
        newUsername: request.username,
        newPassword: request.password,
      ),
      failure: 'Failed to reissue login',
      onSuccess: _showCredentialsThenReload,
    );
  }

  Future<void> _addUser() async {
    final request = await showDialog<AddUserRequest>(
      context: context,
      builder: (_) => const AddUserDialog(),
    );
    if (request == null || !mounted) return;

    await _runBlocking(
      () => _service.addShopUser(
        slug: _slug,
        role: request.role,
        displayName: request.displayName,
        username: request.username,
        password: request.password,
      ),
      failure: 'Failed to add user',
      onSuccess: _showCredentialsThenReload,
    );
  }

  Future<void> _editUser(ShopUser user) async {
    final request = await showDialog<EditUserRequest>(
      context: context,
      builder: (_) => EditUserDialog(user: user),
    );
    if (request == null || !mounted) return;

    await _runBlocking(
      () => _service.updateShopUser(
        slug: _slug,
        uid: user.id,
        displayName: request.displayName,
        role: request.role,
        isEnabled: request.isEnabled,
      ),
      failure: 'Failed to update user',
      onSuccess: (_) => _load(),
    );
  }

  void _viewDevices(ShopUser user) {
    showDialog(
      context: context,
      builder: (_) => ActiveDevicesDialog(
        shopService: _service,
        slug: _slug,
        user: user,
        maxActiveDevices: user.role == 'owner'
            ? _shop!.maxActiveDevicesOwner
            : _shop!.maxActiveDevicesStaff,
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

    await _runBlocking(
      () => _service.deleteShopUser(slug: _slug, uid: user.id),
      failure: 'Failed to remove user',
      onSuccess: (_) => _load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_shop?.name ?? _slug),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Details'),
              Tab(icon: Icon(Icons.payments_outlined), text: 'Payments'),
            ],
          ),
          actions: [
            if (_shop != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                tooltip: 'Delete shop',
                onPressed: _confirmAndDelete,
              ),
            const SizedBox(width: AppDimens.spacing8),
          ],
        ),
        body: TabBarView(
          children: [
            KeepAliveWrapper(child: _buildDetailsTab()),
            ShopPaymentsTab(slug: _slug, shopName: _shop?.name ?? _slug),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final shop = _shop;
    if (shop == null) return const Center(child: Text('Shop not found.'));

    return RefreshIndicator(
      onRefresh: () => Future.wait([_load(), _loadActivity()]),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.pageMaxWidth),
          child: ListView(
            padding: AppDimens.paddingAll20,
            children: [
              ShopSummaryCard(
                shop: shop,
                staffCount: _users
                    .where((u) => u.role == 'staff' && !u.isDeleted)
                    .length,
                productCount: _stats?.productCount ?? 0,
                onEditStaffLimit: _editStaffLimit,
                onEditProductLimit: _editProductLimit,
                onEditMaxActiveDevices: _editMaxActiveDevices,
                onToggleActive: _togglingActive ? null : _toggleActive,
                onToggleStaffDelete: _togglingStaffDelete
                    ? null
                    : _toggleStaffDelete,
              ),
              _sectionGap,
              const SectionHeader(
                icon: Icons.hourglass_top_rounded,
                label: 'Free trial',
              ),
              _headerGap,
              TrialSection(
                shop: shop,
                onToggle: _toggleTrial,
                onSaveDetails: _saveTrialDetails,
                onExtend: _extendTrial,
              ),
              _sectionGap,
              SectionHeader(
                icon: Icons.qr_code_2_outlined,
                label: 'Shop Links',
                trailing: Switch(
                  value: _showShopLinks,
                  onChanged: (v) => setState(() => _showShopLinks = v),
                ),
              ),
              if (_showShopLinks) ...[
                _headerGap,
                ShopLinksSection(shop: shop, onSave: _saveShopLinks),
              ],
              _sectionGap,
              ShopStatisticsSection(
                selection: _selection,
                onSelectFilter: _selectFilter,
                statsLoading: _statsLoading,
                seriesLoading: _seriesLoading,
                stats: _stats,
                comparison: _comparison,
                voids: _voids,
                dailySeries: _dailySeries,
                hours: _hours,
                weekdays: _weekdays,
                performance: _performance,
                deadStock: _deadStock,
              ),
              _sectionGap,
              SectionHeader(
                icon: Icons.receipt_long_outlined,
                label: 'Transactions',
                trailing: Switch(
                  value: _showTransactions,
                  onChanged: (v) {
                    setState(() => _showTransactions = v);
                    if (v) _openTransactionsModal();
                  },
                ),
              ),
              const SizedBox(height: AppDimens.spacing2),
              Text(
                'View sales, expenses, and additional income for this shop.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: AppDimens.fontLabel,
                ),
              ),
              _sectionGap,
              ..._buildUsers(),
              _sectionGap,
              RecentDeviceLoginsSection(shopId: _slug, shopService: _service),
              _sectionGap,
              HistoryRequestsSection(shopId: _slug),
              _sectionGap,
              SectionHeader(
                icon: Icons.inventory_2_outlined,
                label: 'Products (${_products.length})',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showProducts)
                      TextButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add, size: AppDimens.iconLg),
                        label: const Text('Add product'),
                      ),
                    const SizedBox(width: AppDimens.spacing4),
                    Switch(
                      value: _showProducts,
                      onChanged: (v) => setState(() => _showProducts = v),
                    ),
                  ],
                ),
              ),
              if (_showProducts) ...[
                _headerGap,
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
    );
  }

  List<Widget> _buildUsers() {
    return [
      SectionHeader(
        icon: Icons.group_outlined,
        label: 'Users (${_users.length})',
        trailing: TextButton.icon(
          onPressed: _addUser,
          icon: const Icon(
            Icons.person_add_alt_1_outlined,
            size: AppDimens.iconLg,
          ),
          label: const Text('Add user'),
        ),
      ),
      _headerGap,
      if (_users.isEmpty)
        Card(
          child: Padding(
            padding: AppDimens.paddingAll20,
            child: Text(
              'No users yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        )
      else ...[
        ActiveUserCountsRow(users: _users),
        const SizedBox(height: AppDimens.spacing14),
        UserGroup(
          label: 'Owners',
          users: _users.where((u) => u.role == 'owner').toList(),
          onReissueLogin: _reissueLogin,
          onEdit: _editUser,
          onDelete: _deleteUser,
          onViewDevices: _viewDevices,
        ),
        const SizedBox(height: AppDimens.spacing16),
        UserGroup(
          label: 'Staff',
          users: _users.where((u) => u.role != 'owner').toList(),
          onReissueLogin: _reissueLogin,
          onEdit: _editUser,
          onDelete: _deleteUser,
          onViewDevices: _viewDevices,
        ),
      ],
    ];
  }
}
