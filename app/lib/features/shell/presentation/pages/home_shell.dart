import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../domain/repositories/routine_repository.dart';
import '../../../empty_slots/presentation/pages/empty_slots_page.dart';
import '../../../room_search/presentation/pages/room_search_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../student/presentation/pages/student_page.dart';
import '../../../teacher/presentation/pages/teacher_page.dart';
import '../widgets/states.dart';

/// Bottom-navigation shell over the four views plus settings.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = [
    'My Schedule',
    'Teachers',
    'Free Rooms',
    'Rooms',
    'Settings',
  ];
  static const _pages = [
    StudentPage(),
    TeacherPage(),
    EmptySlotsPage(),
    RoomSearchPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncControllerProvider);

    // A first run with no stored routine has nothing to show, so the download
    // takes over the whole screen. Every later sync is a background refresh.
    final hasNoData =
        sync.value?.outcome == SyncOutcome.failed ||
        (sync.isLoading && ref.watch(localRoutineProvider).value == null);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (sync.value?.outcome == SyncOutcome.offline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Offline — showing saved routine',
                child: Icon(Icons.cloud_off),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check for a new routine',
            onPressed: sync.isLoading
                ? null
                : () => ref.read(syncControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: hasNoData ? const _FirstRun() : SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Teacher',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Free',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Shown only when there is no local routine at all.
class _FirstRun extends ConsumerWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    if (sync.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Downloading the routine…'),
          ],
        ),
      );
    }
    return ErrorState(
      message: sync.value?.message ?? 'Could not download the routine.',
      onRetry: () =>
          ref.read(syncControllerProvider.notifier).refresh(force: true),
    );
  }
}
