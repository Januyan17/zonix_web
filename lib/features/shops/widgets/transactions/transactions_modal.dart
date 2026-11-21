import 'package:flutter/material.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/widgets/filter_row.dart';
import 'package:zonixweb/features/shops/models/shop_activity.dart';
import 'package:zonixweb/features/shops/models/shop_stats.dart';
import 'package:zonixweb/features/shops/models/shop_transaction.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';
import 'package:zonixweb/features/shops/utils/shop_activity_aggregate.dart';
import 'package:zonixweb/features/shops/widgets/transactions/transaction_row.dart';

enum _TxFilter { today, weekly, monthly, custom }

class TransactionsModal extends StatefulWidget {
  const TransactionsModal({
    super.key,
    required this.shopService,
    required this.slug,
  });

  final ShopService shopService;
  final String slug;

  @override
  State<TransactionsModal> createState() => _TransactionsModalState();
}

class _TransactionsModalState extends State<TransactionsModal> {
  _TxFilter _filter = _TxFilter.today;
  DateTimeRange? _customRange;
  ShopActivity? _activity;
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
        return StatsDateRange(
          start: DateTime(monday.year, monday.month, monday.day),
          end: today,
        );
      case _TxFilter.monthly:
        return StatsDateRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );
      case _TxFilter.custom:
        final range = _customRange;
        if (range == null) return StatsDateRange(start: today, end: today);
        return StatsDateRange(start: range.start, end: range.end);
    }
  }

  /// Fetches only the selected range; the filter chips then re-slice those
  /// documents locally, and only a chip reaching further back than the last
  /// fetch goes to the network again. The catalog is skipped — nothing here
  /// shows a product count.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final window = _resolveRange();
      final activity = await widget.shopService.getShopActivity(
        widget.slug,
        from: window.start,
        to: window.end,
        includeProducts: false,
      );
      if (mounted) {
        setState(() {
          _activity = activity;
          _transactions = transactionsFrom(activity, range: _resolveRange());
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activity = null;
          _transactions = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final activity = _activity;
    if (activity == null) return;
    setState(() {
      _transactions = transactionsFrom(activity, range: _resolveRange());
    });
  }

  Future<void> _selectFilter(_TxFilter filter) async {
    if (filter == _TxFilter.custom) {
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
        _filter = _TxFilter.custom;
        _customRange = picked;
      });
    } else {
      setState(() => _filter = filter);
    }
    final window = _resolveRange();
    final activity = _activity;
    if (activity != null &&
        activity.covers(from: window.start, to: window.end)) {
      _applyFilter();
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      // Without snap, a drag that starts on the transaction list (e.g.
      // scrolling past the top/bottom of the list) gets picked up by the
      // sheet itself instead of just bouncing the list, and the sheet
      // drifts down to an arbitrary size instead of settling back — snap
      // pins it to one of these three sizes so it always resolves cleanly
      // instead of getting stuck part-way down the screen.
      snap: true,
      snapSizes: const [0.5, 0.85, 0.95],
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
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transactions (${_transactions.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
              FilterRow<_TxFilter>(
                selected: _filter,
                onSelect: _selectFilter,
                styled: true,
                options: [
                  const FilterOption(value: _TxFilter.today, label: 'Today'),
                  const FilterOption(value: _TxFilter.weekly, label: 'Weekly'),
                  const FilterOption(
                    value: _TxFilter.monthly,
                    label: 'Monthly',
                  ),
                  FilterOption(
                    value: _TxFilter.custom,
                    label: _filter == _TxFilter.custom && _customRange != null
                        ? '${formatShortDate(_customRange!.start)} - ${formatShortDate(_customRange!.end)}'
                        : 'Custom',
                    avatar: (isSelected) => Icon(
                      Icons.date_range_outlined,
                      size: 16,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
                        itemBuilder: (context, i) =>
                            TransactionRow(transaction: _transactions[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
