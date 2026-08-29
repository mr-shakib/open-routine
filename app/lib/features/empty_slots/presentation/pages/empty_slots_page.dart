import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/lattice.dart';
import '../../../shell/presentation/widgets/states.dart';
import '../../providers/empty_slot_providers.dart';

/// Empty-slot view: pick a time slot, see which rooms are free each day.
///
/// `free = all rooms - occupied rooms`, decided by equality on the slot label.
/// The slot is always chosen from the lattice, never typed, so an off-grid time
/// cannot be asked for.
class EmptySlotsPage extends ConsumerWidget {
  const EmptySlotsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = ref.watch(selectedSlotProvider);
    final freeRooms = ref.watch(freeRoomsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Time slot',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: kSlots.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ChoiceChip(
              label: Text(kSlots[i]),
              selected: kSlots[i] == slot,
              onSelected: (_) =>
                  ref.read(selectedSlotProvider.notifier).set(kSlots[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: freeRooms.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: '$e'),
            data: (byDay) {
              final total = byDay.values.fold<int>(
                0,
                (sum, rooms) => sum + rooms.length,
              );
              if (total == 0) {
                return const EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'No free rooms',
                  message: 'Every known room is occupied at this time.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  for (final day in kDays)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                day,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${byDay[day]?.length ?? 0} free',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if ((byDay[day] ?? const []).isEmpty)
                            Text(
                              'No free rooms',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final room in byDay[day]!)
                                  Chip(
                                    label: Text(room),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
