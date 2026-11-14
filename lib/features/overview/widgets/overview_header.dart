import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/widgets/page_header.dart';

class OverviewHeader extends StatelessWidget {
  const OverviewHeader({
    super.key,
    required this.loadedAt,
    required this.onRefresh,
  });

  final DateTime loadedAt;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PageHeader(
      title: 'Platform overview',
      subtitle: 'Loaded ${formatRelativeDate(loadedAt).toLowerCase()}',
      trailing: OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, size: AppDimens.iconLg),
        label: const Text('Refresh'),
      ),
    );
  }
}
