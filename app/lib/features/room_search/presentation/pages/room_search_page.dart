import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/lattice.dart';
import '../../../shell/presentation/widgets/class_card.dart';
import '../../../shell/presentation/widgets/search_field.dart';
import '../../../shell/presentation/widgets/states.dart';
import '../../providers/room_search_providers.dart';

/// Room view: room + day + slot, in; whichever class occupies it, out.
class RoomSearchPage extends ConsumerWidget {
  const RoomSearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(roomQueryProvider);
    final occupancy = ref.watch(roomOccupancyProvider);
    final notifier = ref.read(roomQueryProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        RoutineSearchField(
          hint: 'Room, e.g. KT-503',
          initialValue: query.room,
          suggestions: (q) =>
              ref.read(routineRepositoryProvider).roomSuggestions(q),
          onSubmit: notifier.setRoom,
        ),
        const SizedBox(height: 16),
        _ChipRow(
          label: 'Day',
          values: kDays,
          selected: query.day,
          display: dayAbbreviation,
          onSelect: notifier.setDay,
        ),
        const SizedBox(height: 12),
        _ChipRow(
          label: 'Time',
          values: kSlots,
          selected: query.slot,
          display: (s) => s,
          onSelect: notifier.setSlot,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: occupancy.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: '$e'),
            data: (sessions) {
              if (!query.isComplete) {
                return const EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'Check a room',
                  message: 'Enter a room number, then pick a day and time.',
                );
              }
              if (sessions.isEmpty) {
                return EmptyState(
                  icon: Icons.check_circle_outline,
                  title: '${query.room} is free',
                  message: '${query.day}, ${prettySlot(query.slot)}',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => ClassCard(
                  session: sessions[i],
                  // The room and time are the query, so show the answer: who.
                  trailingLabel:
                      '${sessions[i].section} · ${sessions[i].teacher}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.display,
    required this.onSelect,
  });

  final String label;
  final List<String> values;
  final String selected;
  final String Function(String) display;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => ChoiceChip(
            label: Text(display(values[i])),
            selected: values[i] == selected,
            onSelected: (_) => onSelect(values[i]),
          ),
        ),
      ),
    ],
  );
}
