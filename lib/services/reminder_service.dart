import 'dart:convert';

import '../models/reminder_config.dart';
import '../models/task.dart';
import 'persistence_service.dart';

/// Representation of an actively scheduled local notification.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    this.taskId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.type,
    this.frequency,
    this.weekday,
    this.dayOfMonth,
  });

  /// Stable, unique identifier for the notification occurrence.
  final String id;

  /// Associated task ID, or `null` for system/settings reminders.
  final String? taskId;

  /// Notification title.
  final String title;

  /// Notification message body.
  final String body;

  /// Exact date and time when the notification is set to fire.
  final DateTime scheduledAt;

  /// Custom or Recurring.
  final ReminderType type;

  /// Recurrence frequency if recurring.
  final ReminderFrequency? frequency;

  /// Specific ISO weekday (1..7) if weekly occurrence.
  final int? weekday;

  /// Specific day of month (1..31) if monthly occurrence.
  final int? dayOfMonth;

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'title': title,
        'body': body,
        'scheduledAt': scheduledAt.toIso8601String(),
        'type': type.name,
        'frequency': frequency?.name,
        'weekday': weekday,
        'dayOfMonth': dayOfMonth,
      };

  factory ScheduledNotification.fromJson(Map<String, dynamic> json) {
    return ScheduledNotification(
      id: json['id'] as String,
      taskId: json['taskId'] as String?,
      title: json['title'] as String? ?? 'Quest Reminder',
      body: json['body'] as String? ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      type: json['type'] == 'recurring'
          ? ReminderType.recurring
          : ReminderType.custom,
      frequency: _parseFrequency(json['frequency']),
      weekday: (json['weekday'] as num?)?.toInt(),
      dayOfMonth: (json['dayOfMonth'] as num?)?.toInt(),
    );
  }

  static ReminderFrequency? _parseFrequency(Object? raw) {
    if (raw is String) {
      for (final f in ReminderFrequency.values) {
        if (f.name == raw) return f;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledNotification &&
          id == other.id &&
          taskId == other.taskId &&
          scheduledAt == other.scheduledAt;

  @override
  int get hashCode => Object.hash(id, taskId, scheduledAt);
}

/// Service managing scheduling, rescheduling, cancellation, and persistence
/// of local quest and settings reminders.
class ReminderService {
  ReminderService({
    this._persistenceService,
    DateTime Function()? clock,
    this._storageKey = defaultStorageKey,
  }) : _clock = clock ?? DateTime.now;

  static const String defaultStorageKey = 'pro_rpg_scheduled_reminders';
  static const String settingsReminderId = 'settings_daily_reminder';

  final PersistenceService? _persistenceService;
  final DateTime Function() _clock;
  final String _storageKey;

  final Map<String, ScheduledNotification> _scheduled = {};

  /// Returns an unmodifiable list of all active scheduled notifications.
  List<ScheduledNotification> get scheduledNotifications =>
      List.unmodifiable(_scheduled.values);

  /// Returns scheduled notifications for a specific task.
  List<ScheduledNotification> getScheduledNotificationsForTask(String taskId) {
    return _scheduled.values
        .where((item) => item.taskId == taskId)
        .toList(growable: false);
  }

  /// Returns the active Settings daily reminder, if scheduled.
  ScheduledNotification? getSettingsReminder() => _scheduled[settingsReminderId];

  /// Loads persisted scheduled notifications from storage.
  Future<void> loadFromPersistence() async {
    if (_persistenceService == null) return;
    final raw = await _persistenceService.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _scheduled.clear();
        for (final item in decoded) {
          if (item is Map) {
            final notification = ScheduledNotification.fromJson(
              Map<String, dynamic>.from(item),
            );
            _scheduled[notification.id] = notification;
          }
        }
      }
    } catch (_) {
      // Gracefully handle any corrupt cache
    }
  }

  /// Schedules notification(s) for a given task based on its [ReminderConfig].
  ///
  /// Automatically cancels any prior notifications for this task before scheduling.
  Future<void> scheduleTaskReminder(Task task) async {
    // 1. Always cancel existing notifications for this task to avoid duplicates.
    await cancelTaskReminders(task.id);

    final reminder = task.reminder;
    if (reminder == null || !reminder.enabled) {
      return;
    }

    final now = _clock();

    if (reminder.type == ReminderType.custom) {
      final target = reminder.customDateTime;
      if (target != null && target.isAfter(now)) {
        final id = 'task_${task.id}_custom';
        _scheduled[id] = ScheduledNotification(
          id: id,
          taskId: task.id,
          title: 'Quest Reminder: ${task.title}',
          body: task.description?.isNotEmpty == true
              ? task.description!
              : 'Time to forge your progress in QuestForge!',
          scheduledAt: target,
          type: ReminderType.custom,
        );
      }
    } else if (reminder.type == ReminderType.recurring && reminder.time != null) {
      final time = reminder.time!;
      switch (reminder.frequency) {
        case ReminderFrequency.daily:
          final next = calculateNextDailyOccurrence(time, now: now);
          final id = 'task_${task.id}_daily';
          _scheduled[id] = ScheduledNotification(
            id: id,
            taskId: task.id,
            title: 'Daily Quest: ${task.title}',
            body: task.description?.isNotEmpty == true
                ? task.description!
                : 'Your daily quest awaits completion.',
            scheduledAt: next,
            type: ReminderType.recurring,
            frequency: ReminderFrequency.daily,
          );
          break;

        case ReminderFrequency.weekly:
          for (final weekday in reminder.selectedWeekdays) {
            final next = calculateNextWeeklyOccurrence(weekday, time, now: now);
            final id = 'task_${task.id}_weekly_$weekday';
            _scheduled[id] = ScheduledNotification(
              id: id,
              taskId: task.id,
              title: 'Weekly Quest: ${task.title}',
              body: task.description?.isNotEmpty == true
                  ? task.description!
                  : 'Weekly reminder for ${task.title}.',
              scheduledAt: next,
              type: ReminderType.recurring,
              frequency: ReminderFrequency.weekly,
              weekday: weekday,
            );
          }
          break;

        case ReminderFrequency.monthly:
          final day = reminder.dayOfMonth ?? 1;
          final next = calculateNextMonthlyOccurrence(day, time, now: now);
          final id = 'task_${task.id}_monthly';
          _scheduled[id] = ScheduledNotification(
            id: id,
            taskId: task.id,
            title: 'Monthly Quest: ${task.title}',
            body: task.description?.isNotEmpty == true
                ? task.description!
                : 'Monthly reminder for ${task.title}.',
            scheduledAt: next,
            type: ReminderType.recurring,
            frequency: ReminderFrequency.monthly,
            dayOfMonth: day,
          );
          break;

        case null:
          break;
      }
    }

    await _saveToPersistence();
  }

  /// Cancels all scheduled notifications associated with [taskId].
  ///
  /// Does not affect reminders belonging to any other task or Settings.
  Future<void> cancelTaskReminders(String taskId) async {
    final prefix = 'task_${taskId}_';
    final toRemove = _scheduled.keys
        .where((key) => key.startsWith(prefix) || _scheduled[key]?.taskId == taskId)
        .toList();

    if (toRemove.isEmpty) return;

    for (final id in toRemove) {
      _scheduled.remove(id);
    }
    await _saveToPersistence();
  }

  /// Reschedules notifications when a task is edited.
  Future<void> rescheduleTaskReminder(Task oldTask, Task newTask) async {
    await cancelTaskReminders(oldTask.id);
    if (newTask.reminder != null && newTask.reminder!.enabled) {
      await scheduleTaskReminder(newTask);
    }
  }

  /// Schedules or updates the recurring daily Settings reminder.
  ///
  /// Uses a dedicated identifier to ensure it never interferes with task reminders.
  Future<void> scheduleSettingsReminder(ReminderTime time) async {
    final now = _clock();
    final next = calculateNextDailyOccurrence(time, now: now);

    _scheduled[settingsReminderId] = ScheduledNotification(
      id: settingsReminderId,
      taskId: null,
      title: 'QuestForge Daily Check-In',
      body: 'Review your quests and forge your daily progress!',
      scheduledAt: next,
      type: ReminderType.recurring,
      frequency: ReminderFrequency.daily,
    );

    await _saveToPersistence();
  }

  /// Cancels the Settings daily reminder.
  Future<void> cancelSettingsReminder() async {
    if (_scheduled.remove(settingsReminderId) != null) {
      await _saveToPersistence();
    }
  }

  /// Synchronizes reminders for a full list of tasks (e.g. after backup restore).
  Future<void> syncAllTaskReminders(List<Task> tasks) async {
    // Retain settings reminder if present, clear task reminders.
    final settingsNotification = _scheduled[settingsReminderId];
    _scheduled.clear();
    if (settingsNotification != null) {
      _scheduled[settingsReminderId] = settingsNotification;
    }

    for (final task in tasks) {
      if (task.reminder != null && task.reminder!.enabled) {
        await scheduleTaskReminder(task);
      }
    }
    await _saveToPersistence();
  }

  // ── Occurrence Calculations ────────────────────────────────────────────────

  /// Calculates the next daily occurrence at [time].
  static DateTime calculateNextDailyOccurrence(
    ReminderTime time, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final candidate = DateTime(
      current.year,
      current.month,
      current.day,
      time.hour,
      time.minute,
    );
    if (candidate.isAfter(current)) {
      return candidate;
    }
    return DateTime(
      current.year,
      current.month,
      current.day + 1,
      time.hour,
      time.minute,
    );
  }

  /// Calculates the next occurrence for a given [weekday] (`1 = Monday` … `7 = Sunday`) at [time].
  static DateTime calculateNextWeeklyOccurrence(
    int weekday,
    ReminderTime time, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final candidateToday = DateTime(
      current.year,
      current.month,
      current.day,
      time.hour,
      time.minute,
    );

    var daysUntil = (weekday - current.weekday) % 7;
    if (daysUntil < 0) {
      daysUntil += 7;
    }

    if (daysUntil == 0) {
      if (candidateToday.isAfter(current)) {
        return candidateToday;
      }
      daysUntil = 7;
    }

    return DateTime(
      current.year,
      current.month,
      current.day + daysUntil,
      time.hour,
      time.minute,
    );
  }

  /// Calculates the next monthly occurrence for [dayOfMonth] at [time].
  ///
  /// Clamps to the last day of the month if [dayOfMonth] exceeds the month length.
  static DateTime calculateNextMonthlyOccurrence(
    int dayOfMonth,
    ReminderTime time, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final thisMonthDay = _resolveMonthDay(current.year, current.month, dayOfMonth);
    final candidateThisMonth = DateTime(
      current.year,
      current.month,
      thisMonthDay,
      time.hour,
      time.minute,
    );

    if (candidateThisMonth.isAfter(current)) {
      return candidateThisMonth;
    }

    // Advance to next month
    var nextYear = current.year;
    var nextMonth = current.month + 1;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear += 1;
    }
    final nextMonthDay = _resolveMonthDay(nextYear, nextMonth, dayOfMonth);
    return DateTime(
      nextYear,
      nextMonth,
      nextMonthDay,
      time.hour,
      time.minute,
    );
  }

  static int _resolveMonthDay(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay > lastDay ? lastDay : (requestedDay < 1 ? 1 : requestedDay);
  }

  Future<void> _saveToPersistence() async {
    if (_persistenceService == null) return;
    final list = _scheduled.values.map((item) => item.toJson()).toList();
    await _persistenceService.setString(_storageKey, jsonEncode(list));
  }
}
