import 'package:flutter/material.dart';

import '../../../../core/utils/lattice.dart';

/// The empty run between two classes.
///
/// A gap is information: it is the difference between waiting twenty minutes in
/// the corridor and having time to leave campus. Rendering it explicitly means
/// the list shows the shape of the day, not just its contents.
class FreeGap extends StatelessWidget {
  const FreeGap({required this.minutes, super.key});

  final int minutes;

  /// Consecutive slots leave no gap worth drawing.
  static bool worthShowing(int minutes) => minutes >= 30;

  String get _label {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final length = h == 0 ? '$m min' : (m == 0 ? '${h}h' : '${h}h ${m}m');
    return '$length free';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 14),
          SizedBox(
            height: 30,
            child: VerticalDivider(color: scheme.outlineVariant, width: 12, thickness: 1),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minutes between the end of one slot and the start of the next.
int gapBetween(String earlierSlot, String laterSlot) {
  final (_, end) = slotBounds(earlierSlot);
  final (start, _) = slotBounds(laterSlot);
  return start - end;
}
