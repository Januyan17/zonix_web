import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';

/// A read-only field that opens a date picker on tap.
class BillingDateField extends StatelessWidget {
  const BillingDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.icon = Icons.event_outlined,
    this.helperText,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final IconData icon;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(value == null ? 'Not set' : formatShortDate(value!)),
      ),
    );
  }
}

Future<DateTime?> pickBillingDate(BuildContext context, DateTime? initial) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 5),
  );
}
