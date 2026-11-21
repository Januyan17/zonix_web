import 'package:flutter/material.dart';

import 'package:zonixweb/core/services/supabase_storage_service.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/utils/snackbar.dart';
import 'package:zonixweb/core/widgets/delete_confirm_dialog.dart';
import 'package:zonixweb/core/widgets/keep_alive_wrapper.dart';
import 'package:zonixweb/core/widgets/tap_to_load_section.dart';
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
import 'package:zonixweb/features/shops/widgets/detail/shop_detail_chrome.dart';
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

  /// The raw catalog, null until the admin opens the Products section.
  /// Downloading it is one read per product, so it's never done on entry;
  /// [_productCount] (a server-side count, ~2 reads) fills the tiles until
  /// then.
  List<ActivityDoc>? _productDocs;
  int? _productCount;
  bool _loading = true;
  bool _statsLoading = true;
  bool _seriesLoading = true;
  bool _productsLoading = true;
  bool _togglingActive = false;
  bool _togglingStaffDelete = false;
  bool _showProducts = false;

  /// Statistics are opt-in: the activity read behind them is only made the
  /// first time the admin switches the section on.
  bool _showStats = false;
  bool _showShopLinks = false;
  bool _showTransactions = false;
  String? _error;

  ShopDateFilterSelection _selection = const ShopDateFilterSelection();

  @override
  void initState() {
    super.initState();
    _load();
    _loadProductCount();
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

  /// [includeUsers] false re-reads only the shop document — enough after a
  /// settings change, which never touches the users subcollection.
  Future<void> _load({bool includeUsers = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shop = await _service.getShop(_slug);
      final users = includeUsers ? await _service.getShopUsers(_slug) : _users;
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
    });
    try {
      final window = _selection.activityWindow();
      // The catalog is left out: it's fetched only when the Products
      // section is opened, and carried over from then on.
      final fetched = await _service.getShopActivity(
        _slug,
        from: window.from,
        to: window.to,
        includeProducts: false,
      );
      final productDocs = _productDocs;
      final activity = productDocs == null
          ? fetched
          : fetched.withProducts(productDocs);
      if (mounted) {
        setState(() => _activity = activity);
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
      _stats = statsFrom(
        activity,
        range: range,
        productCount: _productDocs == null ? _productCount : null,
      );
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
          _productDocs = docs;
          _products = productsFrom(docs);
          _productCount = _products.length;
          _activity = _activity?.withProducts(docs);
        });
        // Re-derive the tiles and the unsold-products list now that the
        // catalog is in hand.
        _applyFilter();
      }
    } catch (_) {
      // Products are supplementary; a failure here shouldn't block the rest
      // of the page from showing.
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  /// The product-count tile's figure without downloading the catalog.
  Future<void> _loadProductCount() async {
    try {
      final count = await _service.countLiveProducts(_slug);
      if (!mounted || _productDocs != null) return;
      setState(() => _productCount = count);
      _applyFilter();
    } catch (_) {
      // Supplementary; the tile just reads 0 until the catalog is opened.
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
      await _load(includeUsers: false);
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

  /// Starts a trial of an exact length (minutes), mainly for testing.
  Future<void> _startTrialFor(Duration length) {
    return _saveAndReload(
      () => _service.startTrialFor(_slug, length),
      failure: 'Failed to start trial',
      success: (end) => 'Free trial started, ends ${formatShortDateTime(end)}',
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
      () async {
        // Read image URLs first: they live on the product docs being deleted.
        final imageUrls = await _service.productImageUrls(_slug);
        await _service.deleteShop(_slug);
        return _storageService.deleteShopImages(
          slug: _slug,
          imageUrls: imageUrls,
        );
      },
      failure: 'Failed to delete shop',
      onSuccess: (imagesLeft) async {
        if (imagesLeft > 0) {
          showSnackBarMessage(
            context,
            'Shop deleted, but $imagesLeft product image(s) could not be '
            'removed from storage',
          );
        }
        Navigator.of(context).pop();
      },
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

  /// Quick role change from the user card. Keeps name + sign-in as-is.
  Future<void> _changeUserRole(ShopUser user, String role) async {
    final label = role == 'owner' ? 'Owner' : 'Staff';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Make ${user.displayName} $label?'),
        content: Text(
          role == 'owner'
              ? 'Owners get full access to this shop.'
              : 'This user will lose owner access and become staff.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Make $label'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runBlocking(
      () => _service.updateShopUser(
        slug: _slug,
        uid: user.id,
        displayName: user.displayName,
        role: role,
        isEnabled: user.isEnabled,
      ),
      failure: 'Failed to change role',
      onSuccess: (_) async {
        await _load();
        if (mounted) {
          showSnackBarMessage(context, '${user.displayName} is now $label');
        }
      },
    );
  }

  /// Quick sign-in enable/disable from the user card.
  Future<void> _setUserEnabled(ShopUser user, bool isEnabled) async {
    await _runBlocking(
      () => _service.updateShopUser(
        slug: _slug,
        uid: user.id,
        displayName: user.displayName,
        role: user.role,
        isEnabled: isEnabled,
      ),
      failure: 'Failed to update sign-in',
      onSuccess: (_) async {
        await _load();
        if (mounted) {
          showSnackBarMessage(
            context,
            isEnabled
                ? '${user.displayName} can sign in'
                : '${user.displayName} can no longer sign in',
          );
        }
      },
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
    final shop = _shop;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F7FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 76,
          titleSpacing: 4,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: const ZonixHeaderBackground(),
          title: ShopHeaderTitle(
            title: shop?.name ?? _slug,
            slug: _slug,
            isActive: shop?.isActive,
          ),
          bottom: const ShopHeaderTabBar(
            tabs: [
              (icon: Icons.storefront_outlined, label: 'Details'),
              (icon: Icons.payments_outlined, label: 'Payments'),
            ],
          ),
          actions: [
            if (shop != null)
              HeaderGlassButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete shop',
                accent: const Color(0xFFFF8A8A),
                onPressed: _confirmAndDelete,
              ),
            const SizedBox(width: AppDimens.spacing16),
          ],
        ),
        body: TabBarView(
          children: [
            KeepAliveWrapper(child: ZonixBackdrop(child: _buildDetailsTab())),
            ShopPaymentsTab(slug: _slug, shopName: _shop?.name ?? _slug),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppDimens.paddingAll24,
          child: HoloPanel(
            icon: Icons.error_outline_rounded,
            tag: 'Signal lost',
            title: 'Could not load shop',
            subtitle: _error!,
            accent: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    }
    final shop = _shop;
    if (shop == null) return const Center(child: Text('Shop not found.'));

    final staffCount = _users
        .where((u) => u.role == 'staff' && !u.isDeleted)
        .length;
    final productCount = _stats?.productCount ?? _productCount ?? 0;

    final summary = HoloPanel(
      icon: Icons.tune_rounded,
      tag: 'Control core',
      title: 'Profile & limits',
      subtitle: 'Identity, capacity and shop-wide switches',
      flatten: true,
      child: ShopSummaryCard(
        shop: shop,
        staffCount: staffCount,
        productCount: productCount,
        onEditStaffLimit: _editStaffLimit,
        onEditProductLimit: _editProductLimit,
        onEditMaxActiveDevices: _editMaxActiveDevices,
        onToggleActive: _togglingActive ? null : _toggleActive,
        onToggleStaffDelete: _togglingStaffDelete ? null : _toggleStaffDelete,
      ),
    );

    final users = _buildUsersPanel();

    final trial = HoloPanel(
      icon: Icons.hourglass_top_rounded,
      tag: 'Lifecycle',
      title: 'Free trial',
      accent: ZonixColors.emerald,
      flatten: true,
      child: TrialSection(
        shop: shop,
        onToggle: _toggleTrial,
        onStartFor: _startTrialFor,
        onExtend: _extendTrial,
      ),
    );

    final links = HoloPanel(
      icon: Icons.qr_code_2_outlined,
      tag: 'Receipt QR',
      title: 'Shop Links',
      subtitle: 'Website and social codes on receipts',
      flatten: true,
      trailing: NeonSwitch(
        value: _showShopLinks,
        onChanged: (v) => setState(() => _showShopLinks = v),
      ),
      child: _showShopLinks
          ? ShopLinksSection(shop: shop, onSave: _saveShopLinks)
          : null,
    );

    final statistics = HoloPanel(
      icon: Icons.insights_outlined,
      tag: 'Analytics',
      title: 'Statistics',
      subtitle: _showStats
          ? null
          : 'Switch on to load sales, trends and product insights',
      accent: ZonixColors.chartBlue,
      trailing: NeonSwitch(
        value: _showStats,
        onChanged: (v) {
          setState(() => _showStats = v);
          // First switch-on fetches; after that the data already in hand is
          // shown again (pull-to-refresh or a wider filter re-reads it).
          if (v && _activity == null) _loadActivity();
        },
      ),
      child: !_showStats
          ? null
          : ShopStatisticsSection(
              showHeader: false,
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
    );

    final transactions = HoloPanel(
      icon: Icons.receipt_long_outlined,
      tag: 'Ledger',
      title: 'Transactions',
      subtitle: 'View sales, expenses, and additional income for this shop.',
      accent: ZonixColors.emerald,
      trailing: NeonSwitch(
        value: _showTransactions,
        onChanged: (v) {
          setState(() => _showTransactions = v);
          if (v) _openTransactionsModal();
        },
      ),
    );

    final deviceLogins = HoloPanel(
      child: TapToLoadSection(
        icon: Icons.phonelink_lock_rounded,
        label: 'Recent device logins',
        builder: (_) =>
            RecentDeviceLoginsSection(shopId: _slug, shopService: _service),
      ),
    );

    final historyRequests = HoloPanel(
      accent: ZonixColors.chartBlue,
      child: TapToLoadSection(
        icon: Icons.manage_history_rounded,
        label: 'History requests',
        builder: (_) => HistoryRequestsSection(shopId: _slug),
      ),
    );

    final products = HoloPanel(
      icon: Icons.inventory_2_outlined,
      tag: 'Catalog',
      title: _productDocs != null
          ? 'Products (${_products.length})'
          : 'Products (${_productCount ?? '…'})',
      subtitle: _showProducts ? null : 'Switch on to load the catalog',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showProducts)
            FilledButton.tonalIcon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add, size: AppDimens.iconLg),
              label: const Text('Add product'),
            ),
          const SizedBox(width: AppDimens.spacing8),
          NeonSwitch(
            value: _showProducts,
            onChanged: (v) {
              setState(() => _showProducts = v);
              if (v && _productDocs == null) _loadProducts();
            },
          ),
        ],
      ),
      child: _showProducts
          ? ProductsSection(
              loading: _productsLoading,
              products: _products,
              onEdit: _editProduct,
              onDelete: _deleteProduct,
            )
          : null,
    );

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        _load(),
        if (_showStats) _loadActivity(),
        _productDocs == null ? _loadProductCount() : _loadProducts(),
      ]),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final pulse = ShopPulseStrip(
            shop: shop,
            users: _users,
            staffCount: staffCount,
            productCount: productCount,
          );

          final List<Widget> children;
          if (wide) {
            children = [
              pulse,
              _sectionGap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        summary,
                        _sectionGap,
                        trial,
                        _sectionGap,
                        links,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacing24),
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        users,
                        _sectionGap,
                        transactions,
                        _sectionGap,
                        deviceLogins,
                        _sectionGap,
                        historyRequests,
                      ],
                    ),
                  ),
                ],
              ),
              _sectionGap,
              statistics,
              _sectionGap,
              products,
            ];
          } else {
            children = [
              pulse,
              _sectionGap,
              summary,
              // Users sit right under the summary so role and sign-in
              // changes are reachable without scrolling.
              _sectionGap,
              users,
              _sectionGap,
              trial,
              _sectionGap,
              links,
              _sectionGap,
              statistics,
              _sectionGap,
              transactions,
              _sectionGap,
              deviceLogins,
              _sectionGap,
              historyRequests,
              _sectionGap,
              products,
            ];
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.pageMaxWidthWide,
              ),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 32 : AppDimens.spacing16,
                  vertical: AppDimens.spacing24,
                ),
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsersPanel() {
    return HoloPanel(
      icon: Icons.group_outlined,
      tag: 'Access',
      title: 'Users (${_users.length})',
      subtitle: 'Owners and staff who can sign in to this shop',
      trailing: FilledButton.icon(
        onPressed: _addUser,
        icon: const Icon(
          Icons.person_add_alt_1_outlined,
          size: AppDimens.iconLg,
        ),
        label: const Text('Add user'),
      ),
      child: _users.isEmpty
          ? Text(
              'No users yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActiveUserCountsRow(users: _users),
                const SizedBox(height: AppDimens.spacing14),
                UserGroup(
                  label: 'Owners',
                  users: _users.where((u) => u.role == 'owner').toList(),
                  onReissueLogin: _reissueLogin,
                  onEdit: _editUser,
                  onDelete: _deleteUser,
                  onViewDevices: _viewDevices,
                  onRoleChanged: _changeUserRole,
                  onEnabledChanged: _setUserEnabled,
                ),
                const SizedBox(height: AppDimens.spacing16),
                UserGroup(
                  label: 'Staff',
                  users: _users.where((u) => u.role != 'owner').toList(),
                  onReissueLogin: _reissueLogin,
                  onEdit: _editUser,
                  onDelete: _deleteUser,
                  onViewDevices: _viewDevices,
                  onRoleChanged: _changeUserRole,
                  onEnabledChanged: _setUserEnabled,
                ),
              ],
            ),
    );
  }
}
