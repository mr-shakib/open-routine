import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/lattice.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../shell/presentation/widgets/class_card.dart';
import '../../../shell/presentation/widgets/day_selector.dart';
import '../../../shell/presentation/widgets/search_field.dart';
import '../../../shell/presentation/widgets/states.dart';
import '../../providers/teacher_providers.dart';
import '../widgets/teacher_profile.dart';

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
              if (sessions.isEmpty && details == null) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'No classes for $initial',
                  message: 'That initial does not appear in the current routine.',
                );
              }

              final byDay = groupByDay(sessions);
              final today = byDay[_day] ?? const [];
              final now = DateTime.now();

              // One scroll view: the profile scrolls away as you read down into
              // the week, rather than eating a fixed slice of a small screen.
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: TeacherProfile(
                        initial: initial,
                        teacher: details,
                        schedule: sessions,
                      ),
                    ),
                  ),
                  if (sessions.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: DaySelector(
                        selected: _day,
                        onSelect: (d) => setState(() => _day = d),
                        countFor: (d) => byDay[d]?.length ?? 0,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (today.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: EmptyState(
                            icon: Icons.free_breakfast_outlined,
                            title: 'No classes',
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: today.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => ClassCard(
                            session: today[i],
                            trailingLabel: today[i].section,
                            isLive: today[i].isLiveAt(now),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
