import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/notifications/reminder_planner.dart';
import '../../../../domain/repositories/routine_repository.dart';
import '../../../student/providers/student_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final routine = ref.watch(localRoutineProvider).value;
    final sync = ref.watch(syncControllerProvider);

    return ListView(
      children: [
        const _SectionHeader('Routine'),
        ListTile(
          leading: const Icon(Icons.event_note_outlined),
          title: const Text('Version'),
          subtitle: Text(
            routine == null
                ? 'Nothing downloaded yet'
                : 'v${routine.version} · ${routine.sessionCount} classes'
                      '${routine.semester == null ? '' : ' · ${routine.semester}'}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Check for updates'),
          subtitle: Text(switch (sync.value?.outcome) {
            SyncOutcome.updated => 'Updated on last check',
            SyncOutcome.upToDate => 'Up to date',
            SyncOutcome.offline => 'Offline — showing saved routine',
            SyncOutcome.failed => 'Could not reach the server',
            null => 'Tap to check now',
          }),
          trailing: sync.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: sync.isLoading
              ? null
              : () => ref
                    .read(syncControllerProvider.notifier)
                    .refresh(force: true),
        ),

        const _SectionHeader('Display'),
        SwitchListTile(
          secondary: const Icon(Icons.filter_alt_outlined),
          title: const Text('Hide optional courses'),
          subtitle: const Text('Electives with a TCSE course code'),
          value: settings.hideOptionalCourses,
          onChanged: (v) => notifier.setHideOptional(value: v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Class reminders'),
          subtitle: Text(
            settings.savedBatch == null
                ? 'Pick a batch first'
                : 'Alerts 20 minutes before each ${settings.savedBatch} class',
          ),
          value: settings.remindersEnabled,
          onChanged: settings.savedBatch == null
              ? null
              : (value) => _toggleReminders(ref, value: value),
        ),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Theme'),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {settings.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.setThemeMode(s.first),
          ),
        ),

        const _SectionHeader('About'),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Open Routine'),
          subtitle: Text('Open-source class routine for DIU. Works offline.'),
        ),
        const ListTile(
          leading: Icon(Icons.code),
          title: Text('Source'),
          subtitle: Text('github.com/mr-shakib/open-routine'),
        ),
      ],
    );
  }
}

/// Turn reminders on or off, rescheduling the OS alarms to match.
///
/// Reminders are planned from the local database, so they keep working with no
/// network. A denied permission leaves the switch off rather than pretending.
Future<void> _toggleReminders(WidgetRef ref, {required bool value}) async {
  final notifier = ref.read(settingsProvider.notifier);
  final service = ref.read(notificationServiceProvider);

  if (!value) {
    await service.cancelAll();
    await notifier.setRemindersEnabled(value: false);
    return;
  }

  final granted = await service.requestPermissions();
  if (!granted) {
    await notifier.setRemindersEnabled(value: false);
    return;
  }

  final schedule = await ref.read(studentScheduleProvider.future);
  await service.reschedule(
    ReminderPlanner.plan(sessions: schedule, from: DateTime.now()),
  );
  await notifier.setRemindersEnabled(value: true);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
