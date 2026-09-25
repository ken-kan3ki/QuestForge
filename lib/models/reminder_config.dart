import 'package:flutter/material.dart';

/// The two primary types of reminders supported by QuestForge.
enum ReminderType {
  custom,
  recurring,
}

/// Recurring frequency options.
enum ReminderFrequency {
  daily,
  weekly,
  monthly,
}

/// Simple, immutable time-of-day representation for reminders.
@immutable
class ReminderTime {
  const ReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  /// Formats the time as "8:30 PM" or "8:00 AM".
  String format() {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  /// Converts to Flutter's [TimeOfDay].
  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  /// Creates a [ReminderTime] from Flutter's [TimeOfDay].
  factory ReminderTime.fromTimeOfDay(TimeOfDay time) {
    return ReminderTime(hour: time.hour, minute: time.minute);
  }

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'minute': minute,
      };

  factory ReminderTime.fromJson(dynamic json) {
    if (json is Map) {
      final hour = (json['hour'] as num?)?.toInt() ?? 0;
      final minute = (json['minute'] as num?)?.toInt() ?? 0;
      return ReminderTime(hour: hour, minute: minute);
    }
    if (json is String && json.contains(':')) {
      final parts = json.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return ReminderTime(hour: hour, minute: minute);
    }
    return const ReminderTime(hour: 20, minute: 0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}

/// Domain model representing a task or system reminder configuration.
@immutable
class ReminderConfig {
  const ReminderConfig({
    this.enabled = true,
    required this.type,
    this.customDateTime,
    this.frequency,
    this.time,
    this.selectedWeekdays = const [],
    this.dayOfMonth,
  });

  /// Whether the reminder is active.
  final bool enabled;

  /// Custom (one-time) vs Recurring.
  final ReminderType type;

  /// Exact date and time for a Custom reminder.
  final DateTime? customDateTime;

  /// Recurrence frequency (Daily, Weekly, Monthly) if [type] is recurring.
  final ReminderFrequency? frequency;

  /// Time of day for the recurring reminder.
  final ReminderTime? time;

  /// Selected ISO weekdays (`1 = Monday` … `7 = Sunday`) for weekly recurrence.
  final List<int> selectedWeekdays;

  /// Day of month (`1..31`) for monthly recurrence.
  final int? dayOfMonth;

  /// Helper factory for a Custom (one-time) reminder.
  factory ReminderConfig.custom({
    required DateTime dateTime,
    bool enabled = true,
  }) {
    return ReminderConfig(
      enabled: enabled,
      type: ReminderType.custom,
      customDateTime: dateTime,
      time: ReminderTime(hour: dateTime.hour, minute: dateTime.minute),
    );
  }

  /// Helper factory for a Daily recurring reminder.
  factory ReminderConfig.daily({
    required ReminderTime time,
    bool enabled = true,
  }) {
    return ReminderConfig(
      enabled: enabled,
      type: ReminderType.recurring,
      frequency: ReminderFrequency.daily,
      time: time,
    );
  }

  /// Helper factory for a Weekly recurring reminder.
  factory ReminderConfig.weekly({
    required List<int> weekdays,
    required ReminderTime time,
    bool enabled = true,
  }) {
    return ReminderConfig(
      enabled: enabled,
      type: ReminderType.recurring,
      frequency: ReminderFrequency.weekly,
      selectedWeekdays: _normalizedWeekdays(weekdays),
      time: time,
    );
  }

  /// Helper factory for a Monthly recurring reminder.
  factory ReminderConfig.monthly({
    required int dayOfMonth,
    required ReminderTime time,
    bool enabled = true,
  }) {
    return ReminderConfig(
      enabled: enabled,
      type: ReminderType.recurring,
      frequency: ReminderFrequency.monthly,
      dayOfMonth: _clampDayOfMonth(dayOfMonth),
      time: time,
    );
  }

  /// Validates the configuration. Returns `null` if valid, or an error message.
  String? validate({DateTime? now}) {
    if (!enabled) return null;
    final current = now ?? DateTime.now();

    if (type == ReminderType.custom) {
      if (customDateTime == null) {
        return 'Please select a date and time for the custom reminder.';
      }
      if (!customDateTime!.isAfter(current)) {
        return 'Reminder date and time must be in the future.';
      }
    } else if (type == ReminderType.recurring) {
      if (frequency == null) {
        return 'Please select a recurring frequency.';
      }
      if (time == null) {
        return 'Please select a time for the recurring reminder.';
      }
      if (frequency == ReminderFrequency.weekly) {
        if (selectedWeekdays.isEmpty) {
          return 'Select at least one day for weekly reminder.';
        }
      } else if (frequency == ReminderFrequency.monthly) {
        if (dayOfMonth == null || dayOfMonth! < 1 || dayOfMonth! > 31) {
          return 'Day of the month must be between 1 and 31.';
        }
      }
    }
    return null;
  }

  /// Human-readable summary for display in tiles and details.
  String get displayLabel {
    if (!enabled) return 'Reminder off';
    if (type == ReminderType.custom) {
      if (customDateTime == null) return 'Custom';
      return 'Custom · ${_formatDate(customDateTime!)} at ${ReminderTime(hour: customDateTime!.hour, minute: customDateTime!.minute).format()}';
    }

    final formattedTime = time?.format() ?? '';
    switch (frequency) {
      case ReminderFrequency.daily:
        return formattedTime.isEmpty ? 'Daily' : 'Daily at $formattedTime';
      case ReminderFrequency.weekly:
        final days = _weekdayNames(selectedWeekdays);
        if (days.isEmpty) return 'Weekly';
        return 'Weekly · $days${formattedTime.isNotEmpty ? ' at $formattedTime' : ''}';
      case ReminderFrequency.monthly:
        final dayStr = _ordinal(dayOfMonth ?? 1);
        return 'Monthly · $dayStr${formattedTime.isNotEmpty ? ' at $formattedTime' : ''}';
      case null:
        return 'Recurring';
    }
  }

  ReminderConfig copyWith({
    bool? enabled,
    ReminderType? type,
    DateTime? customDateTime,
    bool clearCustomDateTime = false,
    ReminderFrequency? frequency,
    bool clearFrequency = false,
    ReminderTime? time,
    bool clearTime = false,
    List<int>? selectedWeekdays,
    int? dayOfMonth,
    bool clearDayOfMonth = false,
  }) {
    return ReminderConfig(
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      customDateTime:
          clearCustomDateTime ? null : (customDateTime ?? this.customDateTime),
      frequency: clearFrequency ? null : (frequency ?? this.frequency),
      time: clearTime ? null : (time ?? this.time),
      selectedWeekdays: selectedWeekdays != null
          ? _normalizedWeekdays(selectedWeekdays)
          : this.selectedWeekdays,
      dayOfMonth: clearDayOfMonth ? null : (dayOfMonth ?? this.dayOfMonth),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'type': type.name,
        'customDateTime': customDateTime?.toIso8601String(),
        'frequency': frequency?.name,
        'time': time?.toJson(),
        'selectedWeekdays': selectedWeekdays,
        'dayOfMonth': dayOfMonth,
      };

  factory ReminderConfig.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'] as bool? ?? true;
    final type = _parseType(json['type']);

    DateTime? customDateTime;
    final rawDate = json['customDateTime'];
    if (rawDate is String) {
      try {
        customDateTime = DateTime.parse(rawDate);
      } catch (_) {}
    }

    final frequency = _parseFrequency(json['frequency']);
    ReminderTime? time;
    if (json['time'] != null) {
      time = ReminderTime.fromJson(json['time']);
    } else if (customDateTime != null) {
      time = ReminderTime(
        hour: customDateTime.hour,
        minute: customDateTime.minute,
      );
    }

    final weekdays = <int>[];
    final rawDays = json['selectedWeekdays'] ?? json['weekdays'];
    if (rawDays is List) {
      for (final item in rawDays) {
        if (item is num) {
          weekdays.add(item.toInt());
        }
      }
    }

    int? dayOfMonth;
    final rawMonthDay = json['dayOfMonth'];
    if (rawMonthDay is num) {
      dayOfMonth = _clampDayOfMonth(rawMonthDay.toInt());
    }

    return ReminderConfig(
      enabled: enabled,
      type: type,
      customDateTime: customDateTime,
      frequency: frequency,
      time: time,
      selectedWeekdays: _normalizedWeekdays(weekdays),
      dayOfMonth: dayOfMonth,
    );
  }

  static ReminderType _parseType(Object? raw) {
    if (raw is String) {
      for (final val in ReminderType.values) {
        if (val.name == raw) return val;
      }
    }
    return ReminderType.custom;
  }

  static ReminderFrequency? _parseFrequency(Object? raw) {
    if (raw is String) {
      for (final val in ReminderFrequency.values) {
        if (val.name == raw) return val;
      }
    }
    return null;
  }

  static List<int> _normalizedWeekdays(List<int> days) {
    final unique = <int>{};
    for (final day in days) {
      if (day >= DateTime.monday && day <= DateTime.sunday) {
        unique.add(day);
      }
    }
    final sorted = unique.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  static int _clampDayOfMonth(int day) {
    if (day < 1) return 1;
    if (day > 31) return 31;
    return day;
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) {
      return '${day}th';
    }
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  static String _weekdayNames(List<int> days) {
    const names = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return days.map((day) => names[day] ?? '$day').join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderConfig &&
          enabled == other.enabled &&
          type == other.type &&
          customDateTime == other.customDateTime &&
          frequency == other.frequency &&
          time == other.time &&
          dayOfMonth == other.dayOfMonth &&
          _listEquals(selectedWeekdays, other.selectedWeekdays);

  @override
  int get hashCode => Object.hash(
        enabled,
        type,
        customDateTime,
        frequency,
        time,
        dayOfMonth,
        Object.hashAll(selectedWeekdays),
      );
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
