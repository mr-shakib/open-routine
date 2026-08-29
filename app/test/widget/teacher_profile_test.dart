import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_routine/domain/entities/teacher.dart';
import 'package:open_routine/features/teacher/presentation/widgets/teacher_profile.dart';

import '../fixtures.dart';

const _srh = Teacher(
  initial: 'SRH',
  name: 'Dr. Sheak Rashed Haider Noori',
  designation: 'Professor & Head',
  department: 'CSE',
  officeRoom: 'KT-205',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
  await tester.pumpAndSettle();
}

void main() {
  final schedule = testSessions.where((s) => s.teacher == 'SRH').toList();

  testWidgets('shows the directory details', (tester) async {
    await _pump(tester, TeacherProfile(initial: 'SRH', teacher: _srh, schedule: schedule));

    expect(find.text('Dr. Sheak Rashed Haider Noori'), findsOneWidget);
    expect(find.text('Professor & Head'), findsOneWidget);
    expect(find.text('Office KT-205'), findsOneWidget);
    // The initial is what the routine keys on, so it stays visible even when a
    // full name is known -- twice here, since the avatar falls back to it when
    // there is no photo.
    expect(find.text('SRH'), findsWidgets);
    expect(find.text('CSE'), findsOneWidget);
  });

  testWidgets('summarises the workload from the schedule', (tester) async {
    await _pump(tester, TeacherProfile(initial: 'SRH', teacher: _srh, schedule: schedule));

    expect(find.text('${schedule.length}'), findsWidgets);
    expect(find.text('classes'), findsOneWidget);
    expect(find.text('courses'), findsOneWidget);
    expect(find.text('sections'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
  });

  testWidgets('lists the rooms and sections they appear in', (tester) async {
    await _pump(tester, TeacherProfile(initial: 'SRH', teacher: null, schedule: schedule));

    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Rooms'), findsOneWidget);
  });

  testWidgets('an unknown teacher still gets their schedule, with the gap stated',
      (tester) async {
    await _pump(tester, TeacherProfile(initial: 'ZZZ', teacher: null, schedule: schedule));

    expect(find.text('ZZZ'), findsWidgets);
    expect(
      find.text('Not in the faculty directory — showing schedule only.'),
      findsOneWidget,
    );
  });

  testWidgets('no schedule means no workload block', (tester) async {
    await _pump(tester, const TeacherProfile(initial: 'ZZZ', teacher: null, schedule: []));

    expect(find.text('classes'), findsNothing);
    expect(find.text('Rooms'), findsNothing);
  });
}
