import 'package:flutter/material.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';
import 'package:zonixweb/features/billing/services/billing_service.dart';
import 'package:zonixweb/features/billing/widgets/record_payment_dialog.dart';

/// Saves a payment through [service] with snackbar feedback. Returns true
/// on success.
Future<bool> recordPaymentFlow(
  BuildContext context, {
  required BillingService service,
  required String slug,
  required String shopName,
  required ShopBilling billing,
  DateTime? period,
}) async {
  final input = await showRecordPaymentDialog(
    context,
    shopName: shopName,
    billing: billing,
    period: period,
  );
  if (input == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await service.recordPayment(slug, input);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Payment for ${_inputCoverage(input)} saved. '
          'Next due ${formatShortDate(input.nextDueAt!)}.',
        ),
      ),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to save payment: ${describeError(e)}')),
    );
    return false;
  }
}

String _inputCoverage(PaymentInput input) {
  final label = describePeriods(input.periods);
  return input.months <= 1 ? label : '$label (${input.months} months)';
}
