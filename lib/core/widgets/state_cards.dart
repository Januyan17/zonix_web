import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';

class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: AppDimens.icon2xl,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimens.spacing12),
            Text(
              message,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimens.spacing8),
            // Selectable so a "requires an index" link can be copied.
            SelectableText(
              message,
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
