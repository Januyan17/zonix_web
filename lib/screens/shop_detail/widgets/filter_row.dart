import 'package:flutter/material.dart';

/// One chip option for [FilterRow].
class FilterOption<T> {
  const FilterOption({required this.value, required this.label, this.avatar});

  final T value;
  final String label;
  final Widget Function(bool isSelected)? avatar;
}

/// Shared "Wrap of ChoiceChips driven by an enum" pattern used by the date
/// filter and transactions filter — identical shape, only the chip set,
/// labels, and (for the transactions filter) forced high-contrast colors
/// differ.
class FilterRow<T> extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.styled = false,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;

  /// When true, forces the same dark/high-contrast chip colors the
  /// transactions filter uses instead of the default ChoiceChip theme.
  final bool styled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Builder(
            builder: (context) {
              final isSelected = option.value == selected;
              return ChoiceChip(
                avatar: option.avatar?.call(isSelected),
                label: Text(option.label),
                selected: isSelected,
                onSelected: (_) => onSelect(option.value),
                backgroundColor: styled
                    ? colorScheme.surfaceContainerHighest
                    : null,
                selectedColor: styled ? colorScheme.primary : null,
                checkmarkColor: styled ? colorScheme.onPrimary : null,
                labelStyle: styled
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }
}
