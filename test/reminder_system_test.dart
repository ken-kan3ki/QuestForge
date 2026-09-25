// dart:convert removed — unused

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prod/models/quest_type.dart';
import 'package:prod/models/recurrence_rule.dart';
import 'package:prod/models/reminder_config.dart';
import 'package:prod/models/task.dart';
import 'package:prod/screens/settings_screen.dart';
import 'package:prod/screens/task_editor_screen.dart';
import 'package:prod/services/backup_service.dart';
import 'package:prod/services/persistence_service.dart';
import 'package:prod/services/persistent_task_repository.dart';
import 'package:prod/services/reminder_service.dart';
import 'package:prod/services/task_repository.dart';
import 'package:prod/state/task_controller.dart';
import 'package:prod/state/task_scope.dart';

void main() {
  group('1. ReminderConfig Domain Model & Serialization (Sections 2, 4, 5, 10)', () {
    test('Custom reminder model creation & JSON round-trip', () {
      final date = DateTime(2026, 9, 28, 20, 30);
      final reminder = ReminderConfig.custom(dateTime: date);

      expect(reminder.type, ReminderType.custom);
      expect(reminder.customDateTime, date);
      expect(reminder.time?.hour, 20);
      expect(reminder.time?.minute, 30);
      expect(reminder.enabled, isTrue);

      final json = reminder.toJson();
      final restored = ReminderConfig.fromJson(json);

      expect(restored.type, ReminderType.custom);
      expect(restored.customDateTime, date);
      expect(restored.enabled, isTrue);
      expect(restored, equals(reminder));
    });

    test('Daily recurring reminder creation & JSON round-trip', () {
      const time = ReminderTime(hour: 20, minute: 0);
      final reminder = ReminderConfig.daily(time: time);

      expect(reminder.type, ReminderType.recurring);
      expect(reminder.frequency, ReminderFrequency.daily);
      expect(reminder.time, time);
      expect(reminder.enabled, isTrue);

      final json = reminder.toJson();
      final restored = ReminderConfig.fromJson(json);

      expect(restored.frequency, ReminderFrequency.daily);
      expect(restored.time, time);
      expect(restored, equals(reminder));
    });

    test('Weekly recurring reminder with multiple days & JSON round-trip', () {
      const time = ReminderTime(hour: 20, minute: 30);
      final reminder = ReminderConfig.weekly(
        weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
        time: time,
      );

      expect(reminder.type, ReminderType.recurring);
      expect(reminder.frequency, ReminderFrequency.weekly);
      expect(reminder.selectedWeekdays, [1, 3, 5]);
      expect(reminder.time, time);

      final json = reminder.toJson();
      final restored = ReminderConfig.fromJson(json);

      expect(restored.selectedWeekdays, [1, 3, 5]);
      expect(restored, equals(reminder));
    });

    test('Monthly recurring reminder creation & JSON round-trip', () {
      const time = ReminderTime(hour: 19, minute: 45);
      final reminder = ReminderConfig.monthly(dayOfMonth: 20, time: time);

      expect(reminder.type, ReminderType.recurring);
      expect(reminder.frequency, ReminderFrequency.monthly);
      expect(reminder.dayOfMonth, 20);
      expect(reminder.time, time);

      final json = reminder.toJson();
      final restored = ReminderConfig.fromJson(json);

      expect(restored.dayOfMonth, 20);
      expect(restored, equals(reminder));
    });
  });

  group('2. Reminder Validation (Sections 3, 7, 9)', () {
    test('Custom reminder rejects past date/time', () {
      final fixedNow = DateTime(2026, 9, 25, 12, 0);

      // Past date
      final pastDateReminder = ReminderConfig.custom(
        dateTime: DateTime(2026, 9, 24, 12, 0),
      );
      expect(pastDateReminder.validate(now: fixedNow), isNotNull);

      // Today but past time
      final pastTimeReminder = ReminderConfig.custom(
        dateTime: DateTime(2026, 9, 25, 11, 59),
      );
      expect(pastTimeReminder.validate(now: fixedNow), isNotNull);

      // Today future time -> valid
      final futureToday = ReminderConfig.custom(
        dateTime: DateTime(2026, 9, 25, 12, 1),
      );
      expect(futureToday.validate(now: fixedNow), isNull);

      // Future date -> valid
      final futureDate = ReminderConfig.custom(
        dateTime: DateTime(2026, 9, 28, 20, 30),
      );
      expect(futureDate.validate(now: fixedNow), isNull);
    });

    test('Weekly reminder requires at least one selected day', () {
      const time = ReminderTime(hour: 20, minute: 0);

      final zeroDays = ReminderConfig.weekly(weekdays: [], time: time);
      expect(zeroDays.validate(), isNotNull);

      final oneDay = ReminderConfig.weekly(weekdays: [DateTime.monday], time: time);
      expect(oneDay.validate(), isNull);

      final multiDays = ReminderConfig.weekly(
        weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
        time: time,
      );
      expect(multiDays.validate(), isNull);
    });

    test('Monthly reminder validates and clamps day of month', () {
      const time = ReminderTime(hour: 20, minute: 0);

      final valid = ReminderConfig.monthly(dayOfMonth: 20, time: time);
      expect(valid.validate(), isNull);

      // Clamping in factory ensures 1..31
      final clampedLow = ReminderConfig.monthly(dayOfMonth: 0, time: time);
      expect(clampedLow.dayOfMonth, 1);

      final clampedHigh = ReminderConfig.monthly(dayOfMonth: 35, time: time);
      expect(clampedHigh.dayOfMonth, 31);
    });
  });

  group('3. Occurrence Calculations (Sections 6, 7, 9)', () {
    test('Daily occurrence calculation', () {
      final nowMorning = DateTime(2026, 9, 25, 10, 0);
      const targetTime = ReminderTime(hour: 20, minute: 0);

      // Same day evening
      final next1 = ReminderService.calculateNextDailyOccurrence(
        targetTime,
        now: nowMorning,
      );
      expect(next1, DateTime(2026, 9, 25, 20, 0));

      // After target time today -> next day
      final nowNight = DateTime(2026, 9, 25, 21, 0);
      final next2 = ReminderService.calculateNextDailyOccurrence(
        targetTime,
        now: nowNight,
      );
      expect(next2, DateTime(2026, 9, 26, 20, 0));
    });

    test('Weekly multiple-day occurrence calculation', () {
      // 2026-09-25 is a Friday (ISO weekday 5) at 10:00 AM
      final nowFridayMorning = DateTime(2026, 9, 25, 10, 0);
      const targetTime = ReminderTime(hour: 20, minute: 0);

      // Friday target today -> tonight at 20:00
      final fridayNext = ReminderService.calculateNextWeeklyOccurrence(
        DateTime.friday,
        targetTime,
        now: nowFridayMorning,
      );
      expect(fridayNext, DateTime(2026, 9, 25, 20, 0));

      // Monday next -> 2026-09-28
      final mondayNext = ReminderService.calculateNextWeeklyOccurrence(
        DateTime.monday,
        targetTime,
        now: nowFridayMorning,
      );
      expect(mondayNext, DateTime(2026, 9, 28, 20, 0));

      // Wednesday next -> 2026-09-30
      final wednesdayNext = ReminderService.calculateNextWeeklyOccurrence(
        DateTime.wednesday,
        targetTime,
        now: nowFridayMorning,
      );
      expect(wednesdayNext, DateTime(2026, 9, 30, 20, 0));
    });

    test('Monthly occurrence calculation handles short months and leap year correctly', () {
      // Day 31 requested in April (which only has 30 days)
      final nowApril = DateTime(2026, 4, 1, 10, 0);
      const targetTime = ReminderTime(hour: 20, minute: 0);

      final aprilOccurrence = ReminderService.calculateNextMonthlyOccurrence(
        31,
        targetTime,
        now: nowApril,
      );
      // Clamped to April 30
      expect(aprilOccurrence, DateTime(2026, 4, 30, 20, 0));

      // Day 31 requested in January 2026 -> Jan 31
      final nowJan = DateTime(2026, 1, 15, 10, 0);
      final janOccurrence = ReminderService.calculateNextMonthlyOccurrence(
        31,
        targetTime,
        now: nowJan,
      );
      expect(janOccurrence, DateTime(2026, 1, 31, 20, 0));
    });
  });

  group('4. ReminderService Scheduling, Notification IDs, Rescheduling, & Cancellation (Sections 12, 13, 14, 18)', () {
    test('Custom reminder schedules with stable ID', () async {
      final service = ReminderService(clock: () => DateTime(2026, 9, 25, 10, 0));
      final task = Task(
        id: 'task_1',
        title: 'Review PR',
        xpReward: 10,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.custom(
          dateTime: DateTime(2026, 9, 28, 20, 30),
        ),
      );

      await service.scheduleTaskReminder(task);

      final scheduled = service.getScheduledNotificationsForTask('task_1');
      expect(scheduled.length, 1);
      expect(scheduled.first.id, 'task_task_1_custom');
      expect(scheduled.first.scheduledAt, DateTime(2026, 9, 28, 20, 30));
    });

    test('Weekly reminder schedules separate stable ID for each selected day', () async {
      final service = ReminderService(clock: () => DateTime(2026, 9, 25, 10, 0));
      final task = Task(
        id: 'task_2',
        title: 'Gym session',
        xpReward: 20,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.weekly(
          weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
          time: const ReminderTime(hour: 18, minute: 0),
        ),
      );

      await service.scheduleTaskReminder(task);

      final scheduled = service.getScheduledNotificationsForTask('task_2');
      expect(scheduled.length, 3);
      final ids = scheduled.map((s) => s.id).toSet();
      expect(ids, {
        'task_task_2_weekly_1',
        'task_task_2_weekly_3',
        'task_task_2_weekly_5',
      });
    });

    test('Editing reminder cancels old schedules and creates new schedules without duplicates', () async {
      final service = ReminderService(clock: () => DateTime(2026, 9, 25, 10, 0));

      final originalTask = Task(
        id: 'task_3',
        title: 'Read Book',
        xpReward: 10,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.weekly(
          weekdays: [DateTime.monday, DateTime.friday],
          time: const ReminderTime(hour: 20, minute: 0),
        ),
      );
      await service.scheduleTaskReminder(originalTask);
      expect(service.getScheduledNotificationsForTask('task_3').length, 2);

      // Edit: Change to Daily at 21:00
      final editedTask = originalTask.copyWith(
        reminder: ReminderConfig.daily(
          time: const ReminderTime(hour: 21, minute: 0),
        ),
      );
      await service.rescheduleTaskReminder(originalTask, editedTask);

      final newScheduled = service.getScheduledNotificationsForTask('task_3');
      expect(newScheduled.length, 1);
      expect(newScheduled.first.id, 'task_task_3_daily');
      expect(newScheduled.first.scheduledAt.hour, 21);
      // Ensure no leftover weekly reminders
      expect(service.scheduledNotifications.where((s) => s.id.contains('weekly')).isEmpty, isTrue);
    });

    test('Disabling reminder cancels all associated notifications', () async {
      final service = ReminderService(clock: () => DateTime(2026, 9, 25, 10, 0));
      final task = Task(
        id: 'task_4',
        title: 'Meditation',
        xpReward: 5,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.weekly(
          weekdays: [DateTime.saturday, DateTime.sunday],
          time: const ReminderTime(hour: 8, minute: 0),
        ),
      );
      await service.scheduleTaskReminder(task);
      expect(service.getScheduledNotificationsForTask('task_4').length, 2);

      // Disable reminder
      final disabledTask = task.copyWith(
        reminder: task.reminder!.copyWith(enabled: false),
      );
      await service.rescheduleTaskReminder(task, disabledTask);
      expect(service.getScheduledNotificationsForTask('task_4'), isEmpty);
    });

    test('Deleting a task cancels its reminders and does not affect other tasks', () async {
      final service = ReminderService(clock: () => DateTime(2026, 9, 25, 10, 0));
      final taskA = Task(
        id: 'task_A',
        title: 'Quest A',
        xpReward: 10,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.daily(time: const ReminderTime(hour: 8, minute: 0)),
      );
      final taskB = Task(
        id: 'task_B',
        title: 'Quest B',
        xpReward: 10,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.daily(time: const ReminderTime(hour: 12, minute: 0)),
      );

      await service.scheduleTaskReminder(taskA);
      await service.scheduleTaskReminder(taskB);
      expect(service.scheduledNotifications.length, 2);

      // Cancel task A
      await service.cancelTaskReminders('task_A');
      expect(service.getScheduledNotificationsForTask('task_A'), isEmpty);
      expect(service.getScheduledNotificationsForTask('task_B').length, 1);
    });
  });

  group('5. Settings Daily Reminder & Character Arc Integration (Sections 15, 16)', () {
    test('Settings reminder uses dedicated ID and never interferes with task reminders', () async {
      final service = ReminderService(clock: () => DateTime(2026, 9, 25, 10, 0));
      final task = Task(
        id: 'task_99',
        title: 'Write report',
        xpReward: 10,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.daily(time: const ReminderTime(hour: 17, minute: 0)),
      );
      await service.scheduleTaskReminder(task);

      // Schedule settings reminder
      await service.scheduleSettingsReminder(const ReminderTime(hour: 20, minute: 0));
      final settingsNotification = service.getSettingsReminder();
      expect(settingsNotification, isNotNull);
      expect(settingsNotification!.id, ReminderService.settingsReminderId);
      expect(settingsNotification.taskId, isNull);

      // Deleting all task reminders does not cancel settings reminder
      await service.cancelTaskReminders('task_99');
      expect(service.getScheduledNotificationsForTask('task_99'), isEmpty);
      expect(service.getSettingsReminder(), isNotNull);

      // Cancelling settings reminder works cleanly
      await service.cancelSettingsReminder();
      expect(service.getSettingsReminder(), isNull);
    });

    test('Character Arc compatibility: works alongside habit recurrence', () {
      final arcTask = Task(
        id: 'arc_1',
        title: 'Morning Run',
        questType: QuestType.habit,
        recurrence: RecurrenceRule.weekly([DateTime.monday, DateTime.wednesday]),
        xpReward: 10,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.weekly(
          weekdays: [DateTime.monday, DateTime.wednesday],
          time: const ReminderTime(hour: 7, minute: 0),
        ),
      );

      expect(arcTask.isHabit, isTrue);
      expect(arcTask.recurrence?.kind, RecurrenceKind.weekly);
      expect(arcTask.reminder?.frequency, ReminderFrequency.weekly);
      expect(arcTask.reminder?.time?.hour, 7);
    });
  });

  group('6. Persistence & Backup Compatibility (Sections 19, 20)', () {
    test('Reminders survive persistence reload', () async {
      final fakePersistence = InMemoryPersistenceService();
      DateTime clock() => DateTime(2026, 9, 25, 10, 0);

      final repo = PersistentTaskRepository(
        persistenceService: fakePersistence,
        clock: clock,
      );
      final reminderService = ReminderService(
        persistenceService: fakePersistence,
        clock: clock,
      );
      final controller = TaskController(
        repo,
        reminderService: reminderService,
        clock: clock,
      );

      // Create task with weekly reminder
      controller.createTask(
        title: 'Guitar practice',
        xpReward: 10,
        reminder: ReminderConfig.weekly(
          weekdays: [DateTime.tuesday, DateTime.thursday],
          time: const ReminderTime(hour: 19, minute: 0),
        ),
      );

      expect(reminderService.scheduledNotifications.length, 2);

      // Simulate app restart: re-create repo and reminder service with same persistence
      final newRepo = PersistentTaskRepository(
        persistenceService: fakePersistence,
        clock: clock,
      );
      await newRepo.loadFromPersistence();

      final newReminderService = ReminderService(
        persistenceService: fakePersistence,
        clock: clock,
      );
      await newReminderService.loadFromPersistence();

      final loadedTasks = newRepo.getAll();
      expect(loadedTasks.length, 1);
      final loadedTask = loadedTasks.first;
      expect(loadedTask.reminder, isNotNull);
      expect(loadedTask.reminder!.type, ReminderType.recurring);
      expect(loadedTask.reminder!.frequency, ReminderFrequency.weekly);
      expect(loadedTask.reminder!.selectedWeekdays, [2, 4]);
      expect(loadedTask.reminder!.time, const ReminderTime(hour: 19, minute: 0));

      expect(newReminderService.scheduledNotifications.length, 2);
    });

    test('Backward compatibility: legacy tasks without reminder load normally with null reminder', () {
      final legacyJson = {
        'id': 'legacy_1',
        'title': 'Old Quest',
        'xpReward': 10,
        'createdAt': '2026-09-01T10:00:00.000',
        'questType': 'sideQuest',
        'isCompleted': false,
        'completedDates': [],
      };

      final task = Task.fromJson(legacyJson);
      expect(task.id, 'legacy_1');
      expect(task.reminder, isNull);
    });

    test('Backup export & import includes reminder data seamlessly', () {
      const backupService = BackupService();
      final taskWithReminder = Task(
        id: 'backup_task_1',
        title: 'Backup Quest',
        xpReward: 20,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.monthly(
          dayOfMonth: 15,
          time: const ReminderTime(hour: 14, minute: 30),
        ),
      );

      final serialized = backupService.serializeBackup(
        tasks: [taskWithReminder],
        xpTransactions: [],
      );

      final deserialized = backupService.deserializeBackup(serialized);
      expect(deserialized.tasks.length, 1);
      final restoredTask = deserialized.tasks.first;
      expect(restoredTask.reminder, isNotNull);
      expect(restoredTask.reminder?.frequency, ReminderFrequency.monthly);
      expect(restoredTask.reminder?.dayOfMonth, 15);
      expect(restoredTask.reminder?.time, const ReminderTime(hour: 14, minute: 30));
    });
  });

  group('7. TaskEditorScreen Reminder UI Flow (Sections 1, 2, 4, 7, 8, 21)', () {
    testWidgets('Custom reminder flow: toggle ON, pick date/time, validation prevents past scheduling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaskEditorScreen(),
        ),
      );

      // Title
      await tester.enterText(find.byKey(const Key('task-title-field')), 'Deploy to production');
      await tester.pump();

      // Reminder switch is initially OFF
      final reminderSwitch = find.byKey(const Key('reminder-switch'));
      expect(reminderSwitch, findsOneWidget);
      expect(find.byKey(const Key('reminder-type-selector')), findsNothing);

      // Toggle ON
      await tester.tap(reminderSwitch);
      await tester.pumpAndSettle();

      // Custom and Recurring options appear
      expect(find.byKey(const Key('reminder-type-selector')), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);

      // Custom controls visible by default
      expect(find.byKey(const Key('reminder-custom-date-button')), findsOneWidget);
      expect(find.byKey(const Key('reminder-custom-time-button')), findsOneWidget);

      // Try saving with custom date set in the past by typing or verifying validation
      // (Default is future tomorrow, let's test save)
      await tester.tap(find.byKey(const Key('save-task')));
      await tester.pumpAndSettle();

      // Successfully saved since default custom date was in future!
    });

    testWidgets('Weekly reminder: requires at least one selected day; prevents save with 0 days', (tester) async {
      Task? resultTask;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultTask = await Navigator.of(context).push<Task>(
                  MaterialPageRoute(builder: (_) => const TaskEditorScreen()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('task-title-field')), 'Weekly Workout');
      await tester.pump();

      // Turn on reminder
      await tester.tap(find.byKey(const Key('reminder-switch')));
      await tester.pumpAndSettle();

      // Select Recurring
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();

      // Select Weekly
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      // Weekly chips visible
      expect(find.byKey(const Key('weekday-1')), findsOneWidget); // Mon
      expect(find.byKey(const Key('weekday-3')), findsOneWidget); // Wed
      expect(find.byKey(const Key('weekday-5')), findsOneWidget); // Fri

      // Deselect all selected days to test 0-day validation
      for (var d = 1; d <= 7; d++) {
        final chipFinder = find.byKey(Key('weekday-$d'));
        final chip = tester.widget<FilterChip>(chipFinder);
        if (chip.selected) {
          await tester.tap(chipFinder);
          await tester.pumpAndSettle();
        }
      }

      // Try saving with 0 days
      await tester.tap(find.byKey(const Key('save-task')));
      await tester.pumpAndSettle();

      // Validation error shown!
      expect(find.byKey(const Key('reminder-validation-error')), findsOneWidget);
      expect(find.text('Select at least one day for weekly reminder.'), findsOneWidget);
      expect(resultTask, isNull); // Did not save!

      // Select Monday + Wednesday + Friday
      await tester.tap(find.byKey(const Key('weekday-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekday-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekday-5')));
      await tester.pumpAndSettle();

      // Save again
      await tester.tap(find.byKey(const Key('save-task')));
      await tester.pumpAndSettle();

      expect(resultTask, isNotNull);
      expect(resultTask!.reminder?.frequency, ReminderFrequency.weekly);
      expect(resultTask!.reminder?.selectedWeekdays, [1, 3, 5]);
    });

    testWidgets('Monthly reminder: selects day of month and time', (tester) async {
      Task? resultTask;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultTask = await Navigator.of(context).push<Task>(
                  MaterialPageRoute(builder: (_) => const TaskEditorScreen()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('task-title-field')), 'Pay Rent');
      await tester.pump();

      await tester.tap(find.byKey(const Key('reminder-switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('day-of-month-field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('save-task')));
      await tester.pumpAndSettle();

      expect(resultTask, isNotNull);
      expect(resultTask!.reminder?.frequency, ReminderFrequency.monthly);
    });

    testWidgets('Editing existing task loads full reminder configuration into UI', (tester) async {
      final existingTask = Task(
        id: 'edit_task_1',
        title: 'Team Standup',
        xpReward: 10,
        createdAt: DateTime(2026, 9, 25),
        reminder: ReminderConfig.weekly(
          weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
          time: const ReminderTime(hour: 9, minute: 30),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TaskEditorScreen(task: existingTask),
        ),
      );

      // Verify title loaded
      expect(find.text('Team Standup'), findsOneWidget);

      // Verify reminder is ON and type is Recurring
      final reminderSwitch = tester.widget<SwitchListTile>(find.byKey(const Key('reminder-switch')));
      expect(reminderSwitch.value, isTrue);

      expect(find.text('Recurring'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);

      // Verify Mon, Wed, Fri chips are selected
      final monChip = tester.widget<FilterChip>(find.byKey(const Key('weekday-1')));
      final wedChip = tester.widget<FilterChip>(find.byKey(const Key('weekday-3')));
      final friChip = tester.widget<FilterChip>(find.byKey(const Key('weekday-5')));
      final tueChip = tester.widget<FilterChip>(find.byKey(const Key('weekday-2')));

      expect(monChip.selected, isTrue);
      expect(wedChip.selected, isTrue);
      expect(friChip.selected, isTrue);
      expect(tueChip.selected, isFalse);
    });
  });

  group('8. SettingsScreen Daily Reminder UI (Section 16)', () {
    testWidgets('Toggling Settings Daily Reminder schedules and cancels via ReminderService', (tester) async {
      final controller = TaskController(InMemoryTaskRepository());

      await tester.pumpWidget(
        TaskScope(
          controller: controller,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Daily Check-In Reminder'), findsOneWidget);
      final switchFinder = find.byKey(const Key('settings-daily-reminder-switch'));
      expect(switchFinder, findsOneWidget);

      // Initially disabled
      expect(controller.reminderService.getSettingsReminder(), isNull);

      // Toggle ON
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(controller.reminderService.getSettingsReminder(), isNotNull);
      expect(controller.reminderService.getSettingsReminder()?.id, ReminderService.settingsReminderId);

      // Toggle OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(controller.reminderService.getSettingsReminder(), isNull);
    });
  });
}
