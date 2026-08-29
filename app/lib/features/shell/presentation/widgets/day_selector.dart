import 'package:flutter/material.dart';

import '../../../../core/utils/lattice.dart';

/// Horizontal day picker across the six working days.
///
/// Always shows all six, including days with no classes, so the week does not
/// silently change shape as the user switches batches.
class DaySelector extends StatelessWidget {
  const DaySelector({
    required this.selected,
    required this.onSelect,
    this.countFor,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final int Function(String day)? countFor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kDays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = kDays[index];
          final isSelected = day == selected;
          final count = countFor?.call(day);
          return Semantics(
            selected: isSelected,
            button: true,
            label: '$day${count == null ? '' : ', $count classes'}',
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 62,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayAbbreviation(day),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (count != null)
                      Text(
                        count == 0 ? '–' : '$count',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? scheme.onPrimary.withValues(alpha: 0.85)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
