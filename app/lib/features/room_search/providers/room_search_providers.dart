import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/lattice.dart';
import '../../../domain/entities/class_session.dart';

@immutable
class RoomQuery {
  const RoomQuery({this.room = '', required this.day, required this.slot});

  final String room;
  final String day;
  final String slot;

  bool get isComplete => room.trim().isNotEmpty;

  RoomQuery copyWith({String? room, String? day, String? slot}) => RoomQuery(
    room: room ?? this.room,
    day: day ?? this.day,
    slot: slot ?? this.slot,
  );

  @override
  bool operator ==(Object other) =>
      other is RoomQuery &&
      other.room == room &&
      other.day == day &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(room, day, slot);
}

class RoomQueryNotifier extends Notifier<RoomQuery> {
  @override
  RoomQuery build() => RoomQuery(
    day: weekdayName(DateTime.now()) ?? kDays.first,
    slot: kSlots.first,
  );

  void setRoom(String room) =>
      state = state.copyWith(room: room.trim().toUpperCase());
  void setDay(String day) => state = state.copyWith(day: day);
  void setSlot(String slot) => state = state.copyWith(slot: slot);
}

final roomQueryProvider = NotifierProvider<RoomQueryNotifier, RoomQuery>(
  RoomQueryNotifier.new,
);

/// What occupies a room in one lattice cell.
///
/// An empty list means the room is free. More than one entry means the
/// published routine double-books it -- surfaced rather than hidden.
final roomOccupancyProvider = FutureProvider<List<ClassSession>>((ref) {
  final query = ref.watch(roomQueryProvider);
  if (!query.isComplete) return Future.value(const []);
  return ref
      .watch(routineRepositoryProvider)
      .classesInRoom(room: query.room, day: query.day, slot: query.slot);
});

final roomSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) {
  if (query.trim().isEmpty) return Future.value(const []);
  return ref.watch(routineRepositoryProvider).roomSuggestions(query);
});
