import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../../../models/shop_insights.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/zonix_colors.dart';
import '../../../utils/money_format.dart';
import '../../../utils/percent_format.dart';

/// What actually sold, and what didn't.
///
/// The stat tiles say how much the shop took; this says what it took it on
/// — the question behind restocking, shelf space, and which lines to push.
/// Both halves come from the documents already fetched for the tiles, so
/// showing it costs no extra read.
class ProductPerformanceCard extends StatefulWidget {
  const ProductPerformanceCard({
    super.key,
    required this.loading,
    required this.performance,
    required this.deadStock,
    required this.rangeLabel,
  });

  final bool loading;

  /// Best-selling first, as returned by `productPerformanceFrom`.
  final List<ProductPerformance> performance;

  /// Catalog products with no sales in the same range.
  final List<Product> deadStock;

  final String rangeLabel;

  @override
  State<ProductPerformanceCard> createState() => _ProductPerformanceCardState();
}

class _ProductPerformanceCardState extends State<ProductPerformanceCard> {
  /// Ranking by revenue answers "what earns", by units "what moves". They
  /// disagree often enough — a cheap staple outsells a premium line ten to
  /// one while earning less — that both are worth a click.
  bool _byUnits = false;
  bool _showDeadStock = false;

  static const _visibleRows = 8;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top products · ${widget.rangeLabel}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Revenue')),
                    ButtonSegment(value: true, label: Text('Units')),
                  ],
                  selected: {_byUnits},
                  onSelectionChanged: (selection) =>
                      setState(() => _byUnits = selection.first),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacing14),
            if (widget.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.spacing24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (widget.performance.isEmpty)
              Text(
                'No itemized sales in this period. Products appear here once '
                'sales carry line items.',
                style: TextStyle(
                  fontSize: AppDimens.fontBody,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              ..._rows(context),
            if (widget.deadStock.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spacing16),
              const Divider(height: 1),
              const SizedBox(height: AppDimens.spacing12),
              _DeadStockSection(
                products: widget.deadStock,
                expanded: _showDeadStock,
                onToggle: () =>
                    setState(() => _showDeadStock = !_showDeadStock),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final ranked = [...widget.performance];
    if (_byUnits) {
      ranked.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
    }

    double metric(ProductPerformance p) => _byUnits ? p.unitsSold : p.revenue;
    // The leader sets the bar scale, so every other bar reads as a share of
    // the best seller rather than of an arbitrary axis.
    final peak = ranked.isEmpty ? 0.0 : metric(ranked.first);
    final shown = ranked.take(_visibleRows).toList();
    final hidden = ranked.length - shown.length;

    return [
      for (final product in shown) ...[
        _ProductRow(
          product: product,
          fraction: peak <= 0 ? 0 : metric(product) / peak,
          showUnits: _byUnits,
        ),
        const SizedBox(height: AppDimens.spacing10),
      ],
      if (hidden > 0)
        Text(
          'and $hidden more product${hidden == 1 ? '' : 's'} sold',
          style: TextStyle(
            fontSize: AppDimens.fontCaption,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
    ];
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.fraction,
    required this.showUnits,
  });

  final ProductPerformance product;
  final double fraction;
  final bool showUnits;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final margin = product.margin;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppDimens.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacing10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(ZonixColors.chartBlue),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacing12),
        // The bar is a second encoding; these are the numbers themselves,
        // so the row is still readable without reading lengths.
        SizedBox(
          width: 120,
          child: Text(
            showUnits
                ? '${formatQuantity(product.unitsSold)} sold'
                : formatMoney(product.revenue),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: AppDimens.fontBody,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 74,
          child: Text(
            margin == null ? '—' : '${formatPercent(margin)} margin',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: AppDimens.fontCaption,
              color: (margin ?? 0) < 0
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Catalog lines that sold nothing over the range — stock money sitting
/// still. Collapsed by default: for a wide catalog over a single day this
/// is most of the shelf, and it only becomes interesting over a longer
/// window.
class _DeadStockSection extends StatelessWidget {
  const _DeadStockSection({
    required this.products,
    required this.expanded,
    required this.onToggle,
  });

  final List<Product> products;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = products.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: AppDimens.iconSm,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimens.spacing8),
              Expanded(
                child: Text(
                  '$count product${count == 1 ? '' : 's'} sold nothing in '
                  'this period',
                  style: TextStyle(
                    fontSize: AppDimens.fontBody,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: AppDimens.iconLg,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppDimens.spacing10),
          Wrap(
            spacing: AppDimens.spacing6,
            runSpacing: AppDimens.spacing6,
            children: [
              for (final product in products)
                Chip(
                  label: Text(
                    product.name,
                    style: const TextStyle(fontSize: AppDimens.fontCaption),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
