import 'package:flutter_test/flutter_test.dart';
import 'package:open_routine/core/utils/lattice.dart';

void main() {
  group('lattice', () {
    test('is six by six', () {
      expect(kDays, hasLength(6));
      expect(kSlots, hasLength(6));
      expect(kDays, isNot(contains('Friday'))); // weekend in Bangladesh
    });

    test('day order is academic, not lexical', () {
      expect(dayIndex('Saturday'), 0);
      expect(dayIndex('Thursday'), 5);
      expect(dayIndex('Friday'), kDays.length); // sorts last
    });

    test('resolves the midday crossing', () {
      // `11:30-01:00` carries no AM/PM marker; hours under 8 are afternoon.
      expect(slotBounds('08:30-10:00'), (8 * 60 + 30, 10 * 60));
      expect(slotBounds('11:30-01:00'), (11 * 60 + 30, 13 * 60));
      expect(slotBounds('04:00-05:30'), (16 * 60, 17 * 60 + 30));
    });

    test('every slot runs forwards', () {
      for (final slot in kSlots) {
        final (start, end) = slotBounds(slot);
        expect(start, lessThan(end), reason: slot);
      }
    });

    test('slots tile the teaching day without gaps', () {
      for (var i = 0; i < kSlots.length - 1; i++) {
        final (_, end) = slotBounds(kSlots[i]);
        final (nextStart, _) = slotBounds(kSlots[i + 1]);
        expect(end, nextStart, reason: '${kSlots[i]} -> ${kSlots[i + 1]}');
      }
    });

    test('slotAtMinutes finds the containing cell', () {
      expect(slotAtMinutes(9 * 60), '08:30-10:00');
      expect(slotAtMinutes(12 * 60), '11:30-01:00');
      expect(slotAtMinutes(7 * 60), isNull); // before teaching hours
      expect(slotAtMinutes(20 * 60), isNull); // after
    });

    test('weekdayName returns null on Friday', () {
      expect(weekdayName(DateTime(2026, 8, 29)), 'Saturday');
      expect(weekdayName(DateTime(2026, 8, 28)), isNull); // Friday
    });

    test('prettySlot renders 12-hour text', () {
      expect(prettySlot('08:30-10:00'), '8:30 AM – 10:00 AM');
      expect(prettySlot('11:30-01:00'), '11:30 AM – 1:00 PM');
    });
  });
}
