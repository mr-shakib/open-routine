import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/lattice.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../domain/entities/class_session.dart';
import '../../../shell/presentation/widgets/class_card.dart';
import '../../../shell/presentation/widgets/day_selector.dart';
import '../../../shell/presentation/widgets/search_field.dart';
import '../../../shell/presentation/widgets/states.dart';
import '../../providers/student_providers.dart';

/// Student view: enter a batch, see that week's classes.
class StudentPage extends ConsumerStatefulWidget {
  const StudentPage({super.key});

  @override
  ConsumerState<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends ConsumerState<StudentPage> {
  String _day = weekdayName(DateTime.now()) ?? kDays.first;

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(studentQueryProvider);
    final schedule = ref.watch(studentScheduleProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        RoutineSearchField(
          hint: 'Batch, e.g. 60_C',
          initialValue: batch,
          suggestions: (q) =>
              ref.read(routineRepositoryProvider).batchSuggestions(q),
          onSubmit: (value) {
            ref.read(studentQueryProvider.notifier).set(value);
            ref
                .read(settingsProvider.notifier)
                .setSavedBatch(value.toUpperCase());
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: schedule.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: '$e'),
            data: (sessions) {
              if (batch.isEmpty) {
                return const EmptyState(
                  icon: Icons.school_outlined,
                  title: 'Find your schedule',
                  message: 'Enter your batch above, for example 60_C.',
                );
              }
              if (sessions.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'No classes for $batch',
                  message:
                      'Check the batch, or sync if the routine was just published.',
                );
              }
              return _ScheduleBody(
                sessions: sessions,
                day: _day,
                onDaySelected: (d) => setState(() => _day = d),
                trailing: (s) => s.hasTeacher ? s.teacher : 'TBA',
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shared day-selector + list body used by the student and teacher views.
class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.sessions,
    required this.day,
    required this.onDaySelected,
    required this.trailing,
  });

  final List<ClassSession> sessions;
  final String day;
  final ValueChanged<String> onDaySelected;
  final String Function(ClassSession) trailing;

  @override
  Widget build(BuildContext context) {
    final byDay = groupByDay(sessions);
    final today = byDay[day] ?? const [];
    final now = DateTime.now();

    return Column(
      children: [
        DaySelector(
          selected: day,
          onSelect: onDaySelected,
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
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => ClassCard(
                    session: today[i],
                    trailingLabel: trailing(today[i]),
                    isLive: today[i].isLiveAt(now),
                  ),
                ),
        ),
      ],
    );
  }
}
