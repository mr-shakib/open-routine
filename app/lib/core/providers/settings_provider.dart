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
  });

  final ThemeMode themeMode;

  /// Hide elective (`TCSE`) courses, which many students do not attend.
  final bool hideOptionalCourses;

  /// Remembered so the app opens straight onto the user's own schedule.
  final String? savedBatch;
  final String? savedTeacher;

  final bool remindersEnabled;

  Settings copyWith({
    ThemeMode? themeMode,
    bool? hideOptionalCourses,
    String? savedBatch,
    String? savedTeacher,
    bool? remindersEnabled,
  }) => Settings(
    themeMode: themeMode ?? this.themeMode,
    hideOptionalCourses: hideOptionalCourses ?? this.hideOptionalCourses,
    savedBatch: savedBatch ?? this.savedBatch,
    savedTeacher: savedTeacher ?? this.savedTeacher,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _kThemeMode = 'theme_mode';
  static const _kHideOptional = 'hide_optional_courses';
  static const _kBatch = 'saved_batch';
  static const _kTeacher = 'saved_teacher';
  static const _kReminders = 'reminders_enabled';

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
    state = state.copyWith(savedBatch: batch);
    await ref.read(sharedPreferencesProvider).setString(_kBatch, batch);
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
