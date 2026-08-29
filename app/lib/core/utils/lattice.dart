/// The routine lattice: the fixed grid every class snaps to.
///
/// The DIU routine is a 6 x 6 lattice -- six working days by six fixed
/// 90-minute slots -- and every class occupies exactly one cell.
///
/// Two consequences drive the whole app:
///
/// 1. A schedule is a grid, so grouping is a bucket-by-day, never a search.
/// 2. Occupancy is decided by equality on the slot *label*. Because slots are
///    atomic, two classes cannot partially overlap, so no interval arithmetic
///    is needed anywhere. Keep it that way.
///
/// These values mirror `backend/src/open_routine/ingestion/lattice.py`. The
/// backend is the source of truth and serves them at `/api/v1/meta/lattice`;
/// these constants exist so the UI can render a full week before any sync has
/// happened.
library;

/// Working days, in display order. Friday is the weekend in Bangladesh.
const List<String> kDays = <String>[
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
];

/// Canonical slot labels, in grid-column order, exactly as published.
const List<String> kSlots = <String>[
  '08:30-10:00',
  '10:00-11:30',
  '11:30-01:00',
  '01:00-02:30',
  '02:30-04:00',
  '04:00-05:30',
];

/// Position of a day in the academic week, for sorting.
///
/// Never sort day names lexically: the week starts on Saturday here.
int dayIndex(String day) {
  final index = kDays.indexOf(day);
  return index == -1 ? kDays.length : index;
}

/// Short label for a day, e.g. `Saturday` -> `Sat`.
String dayAbbreviation(String day) =>
    day.length >= 3 ? day.substring(0, 3) : day;

/// Minutes past midnight for a `HH:mm` fragment of a slot label.
///
/// Published slots carry no AM/PM marker -- `11:30-01:00` crosses midday. The
/// campus convention resolves it: an hour of 8 or more is morning, anything
/// less is afternoon.
///
/// For display and sorting only. Occupancy is decided by comparing slot labels,
/// never by comparing these numbers.
int minutesFromLabel(String hhmm) {
  final parts = hhmm.trim().split(':');
  if (parts.length != 2) return 0;
  var hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  if (hours < 8) hours += 12; // 01:00 means 13:00 on this campus
  return hours * 60 + minutes;
}

/// `(startMinutes, endMinutes)` for a slot label.
(int, int) slotBounds(String slot) {
  final parts = slot.split('-');
  if (parts.length != 2) return (0, 0);
  return (minutesFromLabel(parts[0]), minutesFromLabel(parts[1]));
}

/// The slot containing [minutes], or `null` outside teaching hours.
String? slotAtMinutes(int minutes) {
  for (final slot in kSlots) {
    final (start, end) = slotBounds(slot);
    if (minutes >= start && minutes < end) return slot;
  }
  return null;
}

/// Today's weekday name as the routine spells it, or `null` on Friday.
String? weekdayName(DateTime date) => switch (date.weekday) {
  DateTime.saturday => 'Saturday',
  DateTime.sunday => 'Sunday',
  DateTime.monday => 'Monday',
  DateTime.tuesday => 'Tuesday',
  DateTime.wednesday => 'Wednesday',
  DateTime.thursday => 'Thursday',
  _ => null, // Friday: no classes
};

/// Renders `08:30-10:00` as `8:30 – 10:00 AM`-style text for display.
String prettySlot(String slot) {
  final parts = slot.split('-');
  if (parts.length != 2) return slot;
  String fmt(String hhmm) {
    final minutes = minutesFromLabel(hhmm);
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  return '${fmt(parts[0])} – ${fmt(parts[1])}';
}
