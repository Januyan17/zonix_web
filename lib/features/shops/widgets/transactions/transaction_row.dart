import 'package:flutter/material.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/core/widgets/icon_badge.dart';
import 'package:zonixweb/features/shops/models/shop_transaction.dart';

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

class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.transaction});

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
      if (transaction.type == ShopTransactionType.sale &&
          transaction.itemCount != null)
        '${transaction.itemCount} item${transaction.itemCount == 1 ? '' : 's'}',
      if (transaction.note != null) transaction.note!,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            size: 36,
            iconSize: 18,
            color: iconColor,
            background: iconColor.withValues(alpha: 0.12),
            circular: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
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
                '${positive ? '+' : '-'}${formatMoney(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: positive ? colorScheme.tertiary : colorScheme.error,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                transaction.createdAt != null
                    ? _formatDateTime(transaction.createdAt!)
                    : '—',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
