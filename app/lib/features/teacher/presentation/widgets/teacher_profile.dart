import 'package:flutter/material.dart';

import '../../../../domain/entities/class_session.dart';
import '../../../../domain/entities/teacher.dart';

/// The teacher's details, shown above their week.
///
/// Everything here is derived from data the app already holds: the directory
/// entry for who they are, and their own schedule for what they teach. The
/// stats matter more than they look -- "how many classes does SRH have" and
/// "which batches do they take" are the questions people actually open this
/// view to answer, and previously you had to count cards by hand.
class TeacherProfile extends StatelessWidget {
  const TeacherProfile({
    required this.initial,
    required this.teacher,
    required this.schedule,
    super.key,
  });

  /// The initial as it appears in the routine. Always known.
  final String initial;

  /// The directory entry, when one exists for this initial.
  final Teacher? teacher;

  final List<ClassSession> schedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final courses = <String>{for (final s in schedule) s.baseCourseCode};
    final batches = <String>{for (final s in schedule) s.batch};
    final rooms = <String>{for (final s in schedule) s.room};
    final days = <String>{for (final s in schedule) s.day};

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(initial: initial, imageUrl: teacher?.imageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher?.name ?? initial,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      // The initial is what the routine keys on, so show it
                      // plainly even when a full name is available.
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Tag(label: initial, emphasis: true),
                          if (teacher?.department != null) _Tag(label: teacher!.department!),
                        ],
                      ),
                      if (teacher?.designation != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          teacher!.designation!,
                          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      if (teacher?.officeRoom != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.meeting_room_outlined,
                                size: 15, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 5),
                            Text(
                              'Office ${teacher!.officeRoom}',
                              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (teacher == null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Not in the faculty directory — showing schedule only.',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],

            if (schedule.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: scheme.outlineVariant, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(value: '${schedule.length}', label: 'classes'),
                  _Stat(value: '${courses.length}', label: 'courses'),
                  _Stat(value: '${batches.length}', label: 'sections'),
                  _Stat(value: '${days.length}', label: 'days'),
                ],
              ),
              const SizedBox(height: 14),
              _Detail(icon: Icons.menu_book_outlined, label: 'Courses', values: courses),
              const SizedBox(height: 8),
              _Detail(icon: Icons.groups_outlined, label: 'Sections', values: batches),
              const SizedBox(height: 8),
              _Detail(icon: Icons.place_outlined, label: 'Rooms', values: rooms),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.imageUrl});
  final String initial;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Center(
              child: Text(
                initial,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              // A missing photo must not leave a broken box: fall back to the
              // initial, which is always known.
              errorBuilder: (context, _, _) => Center(
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!,
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.values});
  final IconData icon;
  final String label;
  final Set<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final sorted = values.toList()..sort();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            sorted.join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.emphasis = false});
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasis ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: emphasis ? scheme.onPrimary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
