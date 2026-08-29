import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// User preferences, persisted locally.
///
/// Deliberately small: anything that belongs to the routine itself lives in the
/// database, not here.
@immutable
class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.hideOptionalCourses = false,
    this.savedBatch,
    this.savedTeacher,
    this.remindersEnabled = false,
    this.recentBatches = const [],
    this.weekView = false,
  });

  final ThemeMode themeMode;

  /// Hide elective (`TCSE`) courses, which many students do not attend.
  final bool hideOptionalCourses;

  /// Remembered so the app opens straight onto the user's own schedule.
  final String? savedBatch;
  final String? savedTeacher;

  final bool remindersEnabled;

  /// Batches looked up before, most recent first.
  ///
  /// Students check a small number of batches repeatedly -- their own, a
  /// friend's, the section they swapped into -- so retyping is the most common
  /// interaction in the app and the easiest to remove.
  final List<String> recentBatches;

  /// Whether the schedule shows the whole week rather than a single day.
  final bool weekView;

  Settings copyWith({
    ThemeMode? themeMode,
    bool? hideOptionalCourses,
    String? savedBatch,
    String? savedTeacher,
    bool? remindersEnabled,
    List<String>? recentBatches,
    bool? weekView,
  }) => Settings(
    themeMode: themeMode ?? this.themeMode,
    hideOptionalCourses: hideOptionalCourses ?? this.hideOptionalCourses,
    savedBatch: savedBatch ?? this.savedBatch,
    savedTeacher: savedTeacher ?? this.savedTeacher,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    recentBatches: recentBatches ?? this.recentBatches,
    weekView: weekView ?? this.weekView,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _kThemeMode = 'theme_mode';
  static const _kHideOptional = 'hide_optional_courses';
  static const _kBatch = 'saved_batch';
  static const _kTeacher = 'saved_teacher';
  static const _kReminders = 'reminders_enabled';
  static const _kRecentBatches = 'recent_batches';
  static const _kWeekView = 'week_view';

  /// Enough to cover the batches someone actually revisits, few enough to stay
  /// glanceable on one line.
  static const maxRecent = 6;

  @override
  Settings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Settings(
      themeMode: ThemeMode.values.byName(
        prefs.getString(_kThemeMode) ?? ThemeMode.system.name,
      ),
      hideOptionalCourses: prefs.getBool(_kHideOptional) ?? false,
      savedBatch: prefs.getString(_kBatch),
      savedTeacher: prefs.getString(_kTeacher),
      remindersEnabled: prefs.getBool(_kReminders) ?? false,
      recentBatches: prefs.getStringList(_kRecentBatches) ?? const [],
      weekView: prefs.getBool(_kWeekView) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_kThemeMode, mode.name);
  }

  Future<void> setHideOptional({required bool value}) async {
    state = state.copyWith(hideOptionalCourses: value);
    await ref.read(sharedPreferencesProvider).setBool(_kHideOptional, value);
  }

  Future<void> setSavedBatch(String batch) async {
    final normalised = batch.trim().toUpperCase();
    // Most recent first, no duplicates, capped.
    final recents = [
      normalised,
      ...state.recentBatches.where((b) => b != normalised),
    ].take(maxRecent).toList();

    state = state.copyWith(savedBatch: normalised, recentBatches: recents);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kBatch, normalised);
    await prefs.setStringList(_kRecentBatches, recents);
  }

  Future<void> removeRecentBatch(String batch) async {
    final recents = state.recentBatches.where((b) => b != batch).toList();
    state = state.copyWith(recentBatches: recents);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_kRecentBatches, recents);
  }

  Future<void> clearRecentBatches() async {
    state = state.copyWith(recentBatches: const []);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_kRecentBatches, const []);
  }

  Future<void> setWeekView({required bool value}) async {
    state = state.copyWith(weekView: value);
    await ref.read(sharedPreferencesProvider).setBool(_kWeekView, value);
  }

  Future<void> setSavedTeacher(String initial) async {
    state = state.copyWith(savedTeacher: initial);
    await ref.read(sharedPreferencesProvider).setString(_kTeacher, initial);
  }

  Future<void> setRemindersEnabled({required bool value}) async {
    state = state.copyWith(remindersEnabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kReminders, value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
