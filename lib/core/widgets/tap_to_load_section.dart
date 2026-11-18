import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/section_header.dart';

/// A section that costs nothing until the admin asks for it.
///
/// Shows only a header with a "Show" button; the [builder] — and with it
/// whatever Firestore reads the section does in its initState — runs on
/// the first tap. Once shown it stays shown (the section's own refresh
/// button takes over from there).
class TapToLoadSection extends StatefulWidget {
  const TapToLoadSection({
    super.key,
    required this.icon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final WidgetBuilder builder;

  @override
  State<TapToLoadSection> createState() => _TapToLoadSectionState();
}

class _TapToLoadSectionState extends State<TapToLoadSection> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    if (_shown) return widget.builder(context);
    return SectionHeader(
      icon: widget.icon,
      label: widget.label,
      trailing: TextButton.icon(
        onPressed: () => setState(() => _shown = true),
        icon: const Icon(Icons.expand_more_rounded, size: AppDimens.iconLg),
        label: const Text('Show'),
      ),
    );
  }
}
