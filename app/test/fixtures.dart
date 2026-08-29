import 'package:drift/native.dart';
import 'package:open_routine/data/datasources/local/database.dart';
import 'package:open_routine/domain/entities/class_session.dart';
import 'package:open_routine/domain/entities/routine_info.dart';

/// An in-memory database, so tests never touch the device filesystem.
AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());

const testRoutine = RoutineInfo(
  id: 1,
  department: 'cse',
  version: '5.1',
  semester: 'Fall 2026',
  sessionCount: 12,
);

ClassSession session({
  required String day,
  required String timeSlot,
  required String room,
  required String courseCode,
  required String teacher,
  required String batch,
  required String section,
  bool isLab = false,
  bool isOptional = false,
  String roomType = 'Theory',
}) {
  final parts = timeSlot.split('-');
  int minutes(String hhmm) {
    final bits = hhmm.split(':');
    var h = int.parse(bits[0]);
    if (h < 8) h += 12;
    return h * 60 + int.parse(bits[1]);
  }

  return ClassSession(
    day: day,
    timeSlot: timeSlot,
    room: room,
    roomType: roomType,
    courseCode: courseCode,
    teacher: teacher,
    batch: batch,
    section: section,
    isLab: isLab,
    isOptional: isOptional,
    startMin: minutes(parts[0]),
    endMin: minutes(parts[1]),
  );
}

/// The same shape as the backend's test fixture, so both sides are exercised
/// against equivalent data: split lab subsections, a TBA teacher, an elective.
final testSessions = <ClassSession>[
  session(
    day: 'Saturday',
    timeSlot: '08:30-10:00',
    room: 'KT-503',
    roomType: 'Computer Lab',
    courseCode: 'CSE414(62_E1)',
    teacher: 'SRH',
    batch: '62_E',
    section: '62_E1',
    isLab: true,
  ),
  session(
    day: 'Saturday',
    timeSlot: '10:00-11:30',
    room: 'KT-503',
    roomType: 'Computer Lab',
    courseCode: 'CSE332(60_C)',
    teacher: 'MAH',
    batch: '60_C',
    section: '60_C',
  ),
  session(
    day: 'Saturday',
    timeSlot: '08:30-10:00',
    room: 'KT-515',
    courseCode: 'CSE311(60_C)',
    teacher: 'NRC',
    batch: '60_C',
    section: '60_C',
  ),
  session(
    day: 'Saturday',
    timeSlot: '01:00-02:30',
    room: 'KT-515',
    courseCode: 'TCSE412(61_A)',
    teacher: 'SAH',
    batch: '61_A',
    section: '61_A',
    isOptional: true,
  ),
  session(
    day: 'Saturday',
    timeSlot: '11:30-01:00',
    room: 'G1-007',
    roomType: 'Computer Lab',
    courseCode: 'CSE414(62_E2)',
    teacher: 'SRH',
    batch: '62_E',
    section: '62_E2',
    isLab: true,
  ),
  session(
    day: 'Sunday',
    timeSlot: '10:00-11:30',
    room: 'KT-503',
    roomType: 'Computer Lab',
    courseCode: 'CSE414(62_E1)',
    teacher: 'SRH',
    batch: '62_E',
    section: '62_E1',
    isLab: true,
  ),
  session(
    day: 'Sunday',
    timeSlot: '08:30-10:00',
    room: 'KT-515',
    courseCode: 'CSE311(60_C)',
    teacher: 'NRC',
    batch: '60_C',
    section: '60_C',
  ),
  session(
    day: 'Sunday',
    timeSlot: '10:00-11:30',
    room: 'KT-515',
    courseCode: 'CSE322(60_C)',
    teacher: 'TBA',
    batch: '60_C',
    section: '60_C',
  ),
  session(
    day: 'Monday',
    timeSlot: '02:30-04:00',
    room: 'KT-801(A)',
    courseCode: 'CSE311(60_C)',
    teacher: 'MAH',
    batch: '60_C',
    section: '60_C',
  ),
  session(
    day: 'Tuesday',
    timeSlot: '04:00-05:30',
    room: 'KT-515',
    courseCode: 'CSE332(60_C)',
    teacher: 'MAH',
    batch: '60_C',
    section: '60_C',
  ),
  session(
    day: 'Wednesday',
    timeSlot: '08:30-10:00',
    room: 'G1-007',
    roomType: 'Computer Lab',
    courseCode: 'CSE414(62_E2)',
    teacher: 'SRH',
    batch: '62_E',
    section: '62_E2',
    isLab: true,
  ),
  session(
    day: 'Thursday',
    timeSlot: '11:30-01:00',
    room: 'KT-503',
    roomType: 'Computer Lab',
    courseCode: 'CSE322(60_C)',
    teacher: 'NRC',
    batch: '60_C',
    section: '60_C',
  ),
];
