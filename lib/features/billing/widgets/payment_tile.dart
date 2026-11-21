import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/money_format.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';

class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, required this.onDelete});

  final ShopPayment payment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final note = payment.note;
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: ZonixColors.emeraldContainer,
        child: Icon(Icons.check_rounded, color: ZonixColors.onEmeraldContainer),
      ),
      title: Text(
        payment.months > 1
            ? '${payment.coverageLabel} · ${payment.months} months · '
                  '${formatMoney(payment.amount)}'
            : '${payment.coverageLabel} · ${formatMoney(payment.amount)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          'Paid on ${formatShortDate(payment.paidAt)}',
          if (note != null && note.isNotEmpty) note,
        ].join('\n'),
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      isThreeLine: note != null && note.isNotEmpty,
      trailing: IconButton(
        tooltip: 'Delete payment',
        icon: Icon(Icons.delete_outline, color: colorScheme.error),
        onPressed: onDelete,
      ),
    );
  }
}
