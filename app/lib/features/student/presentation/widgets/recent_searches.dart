import 'package:flutter/material.dart';

/// Batches looked up before, offered as chips.
///
/// Students check the same few batches over and over -- their own, a friend's,
/// the section they are thinking of swapping into. Retyping `66_B` on a phone
/// keyboard is the most repeated action in the app, so it is worth removing.
class RecentSearches extends StatelessWidget {
  const RecentSearches({
    required this.batches,
    required this.onSelect,
    required this.onRemove,
    this.current,
    super.key,
  });

  final List<String> batches;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;

  /// Marked so it is obvious which one is on screen.
  final String? current;

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'RECENT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: batches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final batch = batches[i];
              final selected = batch == current;
              // Stagger so the row assembles rather than snapping in.
              return TweenAnimationBuilder<double>(
                key: ValueKey(batch),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 220 + i * 45),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(12 * (1 - t), 0),
                    child: child,
                  ),
                ),
                child: _Chip(
                  label: batch,
                  selected: selected,
                  onTap: () => onSelect(batch),
                  onRemove: () => onRemove(batch),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        // Long-press to forget: discoverable enough for a secondary action,
        // and it keeps a delete affordance off every chip.
        onLongPress: onRemove,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
