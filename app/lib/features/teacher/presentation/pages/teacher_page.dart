import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/lattice.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../domain/entities/teacher.dart';
import '../../../shell/presentation/widgets/class_card.dart';
import '../../../shell/presentation/widgets/day_selector.dart';
import '../../../shell/presentation/widgets/search_field.dart';
import '../../../shell/presentation/widgets/states.dart';
import '../../providers/teacher_providers.dart';

/// Teacher view: enter an initial, see that teacher's week.
///
/// Mirrors the student view exactly, with batch shown where the student view
/// shows the teacher -- the same records read along the other axis.
class TeacherPage extends ConsumerStatefulWidget {
  const TeacherPage({super.key});

  @override
  ConsumerState<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends ConsumerState<TeacherPage> {
  String _day = weekdayName(DateTime.now()) ?? kDays.first;

  @override
  Widget build(BuildContext context) {
    final initial = ref.watch(teacherQueryProvider);
    final schedule = ref.watch(teacherScheduleProvider);
    final details = ref.watch(teacherDetailsProvider).value;

    return Column(
      children: [
        const SizedBox(height: 8),
        RoutineSearchField(
          hint: 'Teacher initial, e.g. SRH',
          initialValue: initial,
          suggestions: (q) =>
              ref.read(routineRepositoryProvider).teacherSuggestions(q),
          onSubmit: (value) {
            ref.read(teacherQueryProvider.notifier).set(value);
            ref
                .read(settingsProvider.notifier)
                .setSavedTeacher(value.toUpperCase());
          },
        ),
        if (details != null) _TeacherHeader(teacher: details),
        const SizedBox(height: 12),
        Expanded(
          child: schedule.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: '$e'),
            data: (sessions) {
              if (initial.isEmpty) {
                return const EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Find a teacher',
                  message: 'Enter an initial above, for example SRH.',
                );
              }
              if (sessions.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'No classes for $initial',
                  message:
                      'That initial does not appear in the current routine.',
                );
              }

              final byDay = groupByDay(sessions);
              final today = byDay[_day] ?? const [];
              final now = DateTime.now();

              return Column(
                children: [
                  DaySelector(
                    selected: _day,
                    onSelect: (d) => setState(() => _day = d),
                    countFor: (d) => byDay[d]?.length ?? 0,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: today.isEmpty
                        ? const EmptyState(
                            icon: Icons.free_breakfast_outlined,
                            title: 'No classes',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: today.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => ClassCard(
                              session: today[i],
                              trailingLabel: today[i].section,
                              isLive: today[i].isLiveAt(now),
                            ),
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

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({required this.teacher});
  final Teacher teacher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundImage: teacher.imageUrl == null
                ? null
                : NetworkImage(teacher.imageUrl!),
            child: Text(
              teacher.initial,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (teacher.designation != null)
                  Text(
                    [
                      teacher.designation,
                      if (teacher.officeRoom != null)
                        'Room ${teacher.officeRoom}',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
