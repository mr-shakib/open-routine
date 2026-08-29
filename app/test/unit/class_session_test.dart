import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  group('ClassSession', () {
    test('splits the base course code without destroying the source token', () {
      final s = session(
        day: 'Saturday',
        timeSlot: '08:30-10:00',
        room: 'KT-503',
        courseCode: 'CSE414(62_E1)',
        teacher: 'SRH',
        batch: '62_E',
        section: '62_E1',
      );
      expect(s.baseCourseCode, 'CSE414');
      expect(s.courseCode, 'CSE414(62_E1)'); // still fused
    });

    test('reads the lab subsection', () {
      expect(
        session(
          day: 'Saturday',
          timeSlot: '08:30-10:00',
          room: 'KT-503',
          courseCode: 'CSE414(62_E1)',
          teacher: 'SRH',
          batch: '62_E',
          section: '62_E1',
        ).subsection,
        '1',
      );
      expect(
        session(
          day: 'Saturday',
          timeSlot: '08:30-10:00',
          room: 'KT-515',
          courseCode: 'CSE311(60_C)',
          teacher: 'NRC',
          batch: '60_C',
          section: '60_C',
        ).subsection,
        isNull,
      );
    });

    test('TBA is not a teacher', () {
      final s = session(
        day: 'Sunday',
        timeSlot: '10:00-11:30',
        room: 'KT-515',
        courseCode: 'CSE322(60_C)',
        teacher: 'TBA',
        batch: '60_C',
        section: '60_C',
      );
      expect(s.hasTeacher, isFalse);
    });

    test('isLiveAt only fires on the matching day and slot', () {
      final s = session(
        day: 'Saturday',
        timeSlot: '08:30-10:00',
        room: 'KT-515',
        courseCode: 'CSE311(60_C)',
        teacher: 'NRC',
        batch: '60_C',
        section: '60_C',
      );
      expect(s.isLiveAt(DateTime(2026, 8, 29, 9)), isTrue); // Saturday 09:00
      expect(s.isLiveAt(DateTime(2026, 8, 29, 11)), isFalse); // wrong slot
      expect(s.isLiveAt(DateTime(2026, 8, 30, 9)), isFalse); // Sunday
    });
  });
}
