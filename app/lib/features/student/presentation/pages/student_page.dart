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
import '../widgets/free_gap.dart';
import '../widgets/recent_searches.dart';
import '../widgets/up_next.dart';
import '../widgets/view_toggle.dart';
import '../widgets/week_grid.dart';

/// Student view: enter a batch, see the week.
class StudentPage extends ConsumerStatefulWidget {
  const StudentPage({super.key});

  @override
  ConsumerState<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends ConsumerState<StudentPage> {
  String _day = weekdayName(DateTime.now()) ?? kDays.first;

  void _search(String value) {
    ref.read(studentQueryProvider.notifier).set(value);
    ref.read(settingsProvider.notifier).setSavedBatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(studentQueryProvider);
    final schedule = ref.watch(studentScheduleProvider);
    final weekView = ref.watch(weekViewProvider);
    final recents = ref.watch(settingsProvider.select((s) => s.recentBatches));

    return Column(
      children: [
        const SizedBox(height: 8),
        RoutineSearchField(
          hint: 'Batch, e.g. 66_B',
          initialValue: batch,
          suggestions: (q) => ref.read(routineRepositoryProvider).batchSuggestions(q),
          onSubmit: _search,
        ),

        RecentSearches(
          batches: recents,
          current: batch,
          onSelect: _search,
          onRemove: (b) => ref.read(settingsProvider.notifier).removeRecentBatch(b),
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
                  message: 'Enter your batch above, for example 66_B.',
                );
              }
              if (sessions.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'No classes for $batch',
                  message: 'Check the batch, or sync if the routine was just published.',
                );
              }
              return _Body(
                sessions: sessions,
                day: _day,
                weekView: weekView,
                onDaySelected: (d) => setState(() => _day = d),
                onViewChanged: (w) =>
                    ref.read(weekViewProvider.notifier).set(weekView: w),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.sessions,
    required this.day,
    required this.weekView,
    required this.onDaySelected,
    required this.onViewChanged,
  });

  final List<ClassSession> sessions;
  final String day;
  final bool weekView;
  final ValueChanged<String> onDaySelected;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final byDay = groupByDay(sessions);
    final today = byDay[day] ?? const [];

    return Column(
      children: [
        UpNext(sessions: sessions, now: now),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ViewToggle(weekView: weekView, onChanged: onViewChanged),
        ),

        Expanded(
          // Cross-fade rather than cut: the two views show the same data at
          // different zoom levels, and the transition should say so.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: weekView
                ? WeekGrid(
                    key: const ValueKey('week'),
                    sessions: sessions,
                    today: weekdayName(now),
                    onTapDay: (d) {
                      onDaySelected(d);
                      onViewChanged(false);
                    },
                  )
                : _DayList(
                    key: ValueKey('day-$day'),
                    day: day,
                    today: today,
                    byDay: byDay,
                    now: now,
                    onDaySelected: onDaySelected,
                  ),
          ),
        ),
      ],
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({
    required this.day,
    required this.today,
    required this.byDay,
    required this.now,
    required this.onDaySelected,
    super.key,
  });

  final String day;
  final List<ClassSession> today;
  final Map<String, List<ClassSession>> byDay;
  final DateTime now;
  final ValueChanged<String> onDaySelected;

  @override
  Widget build(BuildContext context) {
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
                  message: 'Nothing scheduled for this day.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: today.length,
                  itemBuilder: (context, i) {
                    final session = today[i];
                    final gap = i == 0
                        ? 0
                        : gapBetween(today[i - 1].timeSlot, session.timeSlot);

                    return _Entrance(
                      index: i,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (FreeGap.worthShowing(gap)) FreeGap(minutes: gap),
                          if (i > 0 && !FreeGap.worthShowing(gap))
                            const SizedBox(height: 10),
                          ClassCard(
                            session: session,
                            trailingLabel: session.hasTeacher
                                ? session.teacher
                                : 'TBA',
                            isLive: session.isLiveAt(now),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A short staggered rise as the day's cards arrive.
///
/// Capped after a handful of items: past that the delay stops reading as
/// polish and starts reading as lag.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delayed = index.clamp(0, 5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delayed * 55),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
