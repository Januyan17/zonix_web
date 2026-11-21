import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/snackbar.dart';

/// Shown on the Contact Zonix pages when `is_platform_admin()` returns false
/// or fails: Row Level Security then returns no rows and updates nothing,
/// silently, so the reason has to be spelled out.
class SupabaseSetupBanner extends StatelessWidget {
  const SupabaseSetupBanner({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '(not signed in)';
    final fg = colorScheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_maybe_outlined, color: fg, size: AppDimens.iconXl),
          const SizedBox(width: AppDimens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supabase does not recognise this admin. Check Third-Party '
                  'Auth (Firebase, project zonix-93c4a), the '
                  'role:authenticated claim, and that your uid is in '
                  'public.platform_admins.',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppDimens.spacing8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppDimens.spacing8,
                  runSpacing: AppDimens.spacing4,
                  children: [
                    Text('Your uid:', style: TextStyle(color: fg)),
                    SelectableText(
                      uid,
                      style: TextStyle(
                        color: fg,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy uid',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.copy_rounded, size: 18, color: fg),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: uid));
                        if (context.mounted) {
                          showSnackBarMessage(context, 'uid copied');
                        }
                      },
                    ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Check again'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
