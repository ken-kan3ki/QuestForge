import 'package:flutter_test/flutter_test.dart';
import 'package:prod/models/reminder_config.dart';
import 'package:prod/models/task.dart';
import 'package:prod/services/notification_service.dart';
import 'package:prod/services/reminder_service.dart';

void main() {
  group('NotificationService & Integration Unit Tests', () {
    test('stringToIntId generates stable, positive 32-bit integer IDs', () {
      final id1 = NotificationService.stringToIntId('task_123_custom');
      final id2 = NotificationService.stringToIntId('task_123_custom');
      final id3 = NotificationService.stringToIntId('task_123_daily');
      final settingsId = NotificationService.stringToIntId('settings_daily_reminder');

      expect(id1, equals(id2));
      expect(id1, isNot(equals(id3)));
      expect(id1, isNot(equals(settingsId)));
      expect(id1, greaterThanOrEqualTo(0));
      expect(id1, lessThan(2147483647));
    });

    test('ReminderService passes OS notification scheduling to NotificationService', () async {
      final reminderService = ReminderService(
        clock: () => DateTime(2026, 10, 1, 10, 0),
      );

      final task = Task(
        id: 'quest_1',
        title: 'Slay Dragon',
        xpReward: 50,
        createdAt: DateTime(2026, 10, 1, 10, 0),
        reminder: ReminderConfig.custom(
          dateTime: DateTime(2026, 10, 1, 14, 0),
        ),
      );

      final result = await reminderService.scheduleTaskReminder(task);
      expect(result, isTrue);

      final scheduled = reminderService.getScheduledNotificationsForTask('quest_1');
      expect(scheduled.length, equals(1));
      expect(scheduled.first.id, equals('task_quest_1_custom'));
      expect(scheduled.first.title, equals('Quest Reminder: Slay Dragon'));
    });

    test('ReminderService cancels OS notification when task is deleted', () async {
      final reminderService = ReminderService(
        clock: () => DateTime(2026, 10, 1, 10, 0),
      );

      final task = Task(
        id: 'quest_2',
        title: 'Daily Training',
        xpReward: 10,
        createdAt: DateTime(2026, 10, 1, 10, 0),
        reminder: ReminderConfig.daily(
          time: const ReminderTime(hour: 9, minute: 0),
        ),
      );

      await reminderService.scheduleTaskReminder(task);
      expect(reminderService.getScheduledNotificationsForTask('quest_2').length, equals(1));

      await reminderService.cancelTaskReminders('quest_2');
      expect(reminderService.getScheduledNotificationsForTask('quest_2').isEmpty, isTrue);
    });

    test('Settings reminder creates dedicated notification ID', () async {
      final reminderService = ReminderService(
        clock: () => DateTime(2026, 10, 1, 10, 0),
      );

      final result = await reminderService.scheduleSettingsReminder(
        const ReminderTime(hour: 20, minute: 0),
      );

      expect(result, isTrue);
      final settingsNotif = reminderService.getSettingsReminder();
      expect(settingsNotif, isNotNull);
      expect(settingsNotif!.id, equals(ReminderService.settingsReminderId));

      await reminderService.cancelSettingsReminder();
      expect(reminderService.getSettingsReminder(), isNull);
    });
  });
}
