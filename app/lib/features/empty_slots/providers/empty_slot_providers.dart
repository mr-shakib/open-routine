import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/lattice.dart';

/// The slot being inspected. Always one of [kSlots] -- never a free-form time,
/// so an off-lattice time cannot be asked for.
class SelectedSlot extends Notifier<String> {
  @override
  String build() => kSlots.first;

  void set(String slot) => state = slot;
}

final selectedSlotProvider = NotifierProvider<SelectedSlot, String>(
  SelectedSlot.new,
);

/// Free rooms per working day: `all rooms - occupied rooms`.
///
/// Occupancy is equality on the slot label. The lattice makes overlaps
/// impossible, so no interval arithmetic is involved.
final freeRoomsProvider = FutureProvider<Map<String, List<String>>>((ref) {
  final slot = ref.watch(selectedSlotProvider);
  return ref.watch(routineRepositoryProvider).freeRooms(slot);
});
