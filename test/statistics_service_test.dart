import 'package:flutter_test/flutter_test.dart';
import 'package:prod/models/quest_type.dart';
import 'package:prod/models/task.dart';
import 'package:prod/models/xp_transaction.dart';
import 'package:prod/services/calendar_day.dart';
import 'package:prod/services/statistics_service.dart';

void main() {
  const service = StatisticsService();

  group('StatisticsService - Empty History / Brand New User', () {
    test('returns clean zeroed statistics without errors for fresh account', () {
      final now = DateTime(2026, 9, 13, 14, 0); // Sunday
      final stats = service.calculate(
        tasks: [],
        xpTransactions: [],
        now: now,
      );

      expect(stats.totalTasksCompleted, 0);
      expect(stats.tasksCompletedToday, 0);
      expect(stats.tasksCompletedThisWeek, 0);
      expect(stats.totalXpAllTime, 0);
      expect(stats.xpEarnedToday, 0);
      expect(stats.xpEarnedThisWeek, 0);
      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 0);
      expect(stats.currentMultiplier, 1.0);
      expect(stats.currentLevel, 1);
      expect(stats.levelProgress.totalXp, 0);
      expect(stats.levelProgress.progressToNextLevel, 0.0);
      expect(stats.levelProgress.xpToNextLevel, 23);

      expect(stats.recentDailyActivity.length, 7);
      for (final dayStat in stats.recentDailyActivity) {
        expect(dayStat.xpEarned, 0);
        expect(dayStat.tasksCompleted, 0);
      }
      expect(stats.recentDailyActivity.last.isToday, isTrue);
      expect(stats.recentDailyActivity.last.day, CalendarDay.from(now));
    });
  });

  group('StatisticsService - Task Totals and Today/This-Week Boundaries', () {
    test('accurately categorizes tasks completed today, this week, and earlier', () {
      // Reference date: Wednesday, Sept 16, 2026
      // Monday of this week: Sept 14, 2026
      // Previous Sunday: Sept 13, 2026 (last week)
      final now = DateTime(2026, 9, 16, 12, 0);

      final taskToday = Task(
        id: 't_today',
        title: 'Task Today',
        xpReward: 10,
        createdAt: DateTime(2026, 9, 16, 8, 0),
        isCompleted: true,
        completedAt: DateTime(2026, 9, 16, 10, 0),
      );

      final taskMonday = Task(
        id: 't_monday',
        title: 'Task Monday',
        xpReward: 15,
        createdAt: DateTime(2026, 9, 14, 8, 0),
        isCompleted: true,
        completedAt: DateTime(2026, 9, 14, 11, 0),
      );

      final taskLastWeek = Task(
        id: 't_last_week',
        title: 'Task Last Week',
        xpReward: 20,
        createdAt: DateTime(2026, 9, 13, 8, 0),
        isCompleted: true,
        completedAt: DateTime(2026, 9, 13, 11, 0),
      );

      final taskIncomplete = Task(
        id: 't_incomplete',
        title: 'Incomplete Task',
        xpReward: 30,
        createdAt: DateTime(2026, 9, 16, 8, 0),
        isCompleted: false,
      );

      // Habit completed on Monday and Today
      final habitTask = Task(
        id: 't_habit',
        title: 'Daily Habit',
        xpReward: 5,
        createdAt: DateTime(2026, 9, 1, 8, 0),
        questType: QuestType.habit,
        completedDates: [
          DateTime(2026, 9, 13, 9, 0), // Last week
          DateTime(2026, 9, 14, 9, 0), // This week (Monday)
          DateTime(2026, 9, 16, 9, 0), // Today
        ],
      );

      final stats = service.calculate(
        tasks: [taskToday, taskMonday, taskLastWeek, taskIncomplete, habitTask],
        xpTransactions: [],
        now: now,
      );

      // All-time: taskToday(1) + taskMonday(1) + taskLastWeek(1) + habit(3) = 6
      expect(stats.totalTasksCompleted, 6);

      // Today: taskToday(1) + habitToday(1) = 2
      expect(stats.tasksCompletedToday, 2);

      // This week: taskToday(1) + taskMonday(1) + habitMonday(1) + habitToday(1) = 4
      expect(stats.tasksCompletedThisWeek, 4);
    });
  });

  group('StatisticsService - XP Aggregation and Reversals', () {
    test('calculates today, this-week, all-time XP while properly ignoring reversed transactions', () {
      final now = DateTime(2026, 9, 16, 15, 0); // Wednesday

      final txToday = XpTransaction(
        id: 'tx_1',
        sourceTaskId: 't1',
        completionId: 'c1',
        baseXp: 50,
        awardedXp: 50,
        timestamp: DateTime(2026, 9, 16, 10, 0),
      );

      final txTodayReversed = XpTransaction(
        id: 'tx_2',
        sourceTaskId: 't2',
        completionId: 'c2',
        baseXp: 30,
        awardedXp: 30,
        timestamp: DateTime(2026, 9, 16, 11, 0),
        reversed: true, // should be ignored!
      );

      final txEarlierThisWeek = XpTransaction(
        id: 'tx_3',
        sourceTaskId: 't3',
        completionId: 'c3',
        baseXp: 40,
        awardedXp: 40,
        timestamp: DateTime(2026, 9, 15, 14, 0), // Tuesday
      );

      final txLastWeek = XpTransaction(
        id: 'tx_4',
        sourceTaskId: 't4',
        completionId: 'c4',
        baseXp: 60,
        awardedXp: 60,
        timestamp: DateTime(2026, 9, 13, 10, 0), // Sunday last week
      );

      final stats = service.calculate(
        tasks: [],
        xpTransactions: [txToday, txTodayReversed, txEarlierThisWeek, txLastWeek],
        now: now,
      );

      // Today: only txToday = 50
      expect(stats.xpEarnedToday, 50);

      // This week: txToday(50) + txEarlierThisWeek(40) = 90
      expect(stats.xpEarnedThisWeek, 90);

      // All-time: txToday(50) + txEarlierThisWeek(40) + txLastWeek(60) = 150
      expect(stats.totalXpAllTime, 150);

      // Level progress for 150 XP
      // Cumulative: L1=23, L2=27, L3=31, L4=35, L5=40 => level 5 floor=116, into=34
      expect(stats.currentLevel, 5);
      expect(stats.levelProgress.xpIntoCurrentLevel, 34);
    });
  });

  group('StatisticsService - Streak and Longest Streak Retrieval', () {
    test('calculates current streak and longest streak across historic gaps', () {
      final now = DateTime(2026, 9, 20, 10, 0); // Day 20

      // Past streak: Day 1, 2, 3, 4, 5 (streak of 5)
      // Gap on Day 6, 7
      // Recent streak: Day 19, 20 (streak of 2)
      final completionDates = [
        DateTime(2026, 9, 1, 10),
        DateTime(2026, 9, 2, 10),
        DateTime(2026, 9, 3, 10),
        DateTime(2026, 9, 4, 10),
        DateTime(2026, 9, 5, 10),
        DateTime(2026, 9, 19, 10),
        DateTime(2026, 9, 20, 10),
      ];

      final tasks = completionDates.map((d) {
        return Task(
          id: 'task_${d.day}',
          title: 'Task on day ${d.day}',
          xpReward: 10,
          createdAt: d,
          isCompleted: true,
          completedAt: d,
        );
      }).toList();

      final stats = service.calculate(
        tasks: tasks,
        xpTransactions: [],
        now: now,
      );

      // Current streak is 2 (yesterday + today)
      expect(stats.currentStreak, 2);
      // Longest streak was 5 (days 1 to 5)
      expect(stats.longestStreak, 5);
      // Multiplier for streak of 2: 1.00 + 1 * 0.05 = 1.05
      expect(stats.currentMultiplier, 1.05);
    });
  });

  group('StatisticsService - Historical Daily Activity View', () {
    test('creates ordered 7-day window with correct day labels and totals', () {
      final now = DateTime(2026, 9, 13, 12, 0); // Sunday

      final tx1 = XpTransaction(
        id: 'tx_1',
        sourceTaskId: 't1',
        completionId: 'c1',
        baseXp: 100,
        awardedXp: 100,
        timestamp: DateTime(2026, 9, 13, 10, 0), // Today
      );

      final tx2 = XpTransaction(
        id: 'tx_2',
        sourceTaskId: 't2',
        completionId: 'c2',
        baseXp: 50,
        awardedXp: 50,
        timestamp: DateTime(2026, 9, 11, 10, 0), // 2 days ago (Friday)
      );

      final task1 = Task(
        id: 't1',
        title: 'Task 1',
        xpReward: 100,
        createdAt: DateTime(2026, 9, 13),
        isCompleted: true,
        completedAt: DateTime(2026, 9, 13, 10, 0),
      );

      final task2 = Task(
        id: 't2',
        title: 'Task 2',
        xpReward: 50,
        createdAt: DateTime(2026, 9, 11),
        isCompleted: true,
        completedAt: DateTime(2026, 9, 11, 10, 0),
      );

      final stats = service.calculate(
        tasks: [task1, task2],
        xpTransactions: [tx1, tx2],
        now: now,
        historyDays: 7,
      );

      expect(stats.recentDailyActivity.length, 7);

      // Last item is today
      final todayItem = stats.recentDailyActivity.last;
      expect(todayItem.isToday, isTrue);
      expect(todayItem.xpEarned, 100);
      expect(todayItem.tasksCompleted, 1);

      // 2 days ago (index 4 out of 0..6)
      final fridayItem = stats.recentDailyActivity[4];
      expect(fridayItem.isToday, isFalse);
      expect(fridayItem.xpEarned, 50);
      expect(fridayItem.tasksCompleted, 1);

      // Yesterday (index 5) has 0
      final yesterdayItem = stats.recentDailyActivity[5];
      expect(yesterdayItem.xpEarned, 0);
      expect(yesterdayItem.tasksCompleted, 0);
    });
  });
}
