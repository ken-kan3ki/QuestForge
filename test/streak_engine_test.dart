import 'package:flutter_test/flutter_test.dart';
import 'package:prod/services/streak_engine.dart';

void main() {
  const engine = StreakEngine();

  group('CalendarDay', () {
    test('normalizes year, month, and day ignoring time of day', () {
      final dt1 = DateTime(2026, 5, 10, 8, 30);
      final dt2 = DateTime(2026, 5, 10, 23, 45);
      final day1 = CalendarDay.from(dt1);
      final day2 = CalendarDay.from(dt2);

      expect(day1, equals(day2));
      expect(day1.hashCode, equals(day2.hashCode));
      expect(day1.toString(), '2026-05-10');
    });

    test('supports addDays and subtractDays across month and year boundaries', () {
      const day = CalendarDay(2026, 1, 1);
      expect(day.previousDay, const CalendarDay(2025, 12, 31));
      expect(day.subtractDays(2), const CalendarDay(2025, 12, 30));
      expect(day.nextDay, const CalendarDay(2026, 1, 2));

      const leapEnd = CalendarDay(2024, 2, 28);
      expect(leapEnd.nextDay, const CalendarDay(2024, 2, 29));
      expect(leapEnd.addDays(2), const CalendarDay(2024, 3, 1));
    });
  });

  group('First productive day', () {
    test('no completions yields 0 streak, not productive, 1.00x multiplier', () {
      final today = DateTime(2026, 9, 12, 14);
      final info = engine.calculate(completionDates: [], today: today);

      expect(info.streakLength, 0);
      expect(info.isTodayProductive, isFalse);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
      expect(engine.isProductiveDay(completionDates: [], day: today), isFalse);
    });

    test('completing the first task today creates streak of 1 with 1.00x multiplier', () {
      final today = DateTime(2026, 9, 12, 14);
      final completions = [DateTime(2026, 9, 12, 9, 15)];
      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 1);
      expect(info.isTodayProductive, isTrue);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
      expect(
        engine.isProductiveDay(completionDates: completions, day: today),
        isTrue,
      );
    });

    test('before any task completed today, if no prior history, new reward multiplier is 1.00x', () {
      final today = DateTime(2026, 9, 12, 10);
      final mult = engine.multiplierForNewReward(
        completionDates: [],
        today: today,
      );
      expect(mult, 1.00);
    });
  });

  group('Consecutive productive days', () {
    test('consecutive days increase multiplier starting on day 4 (0.05 per day after 3 days)', () {
      final today = DateTime(2026, 9, 13, 18);
      final completions = [
        DateTime(2026, 9, 10, 10), // Day 1
        DateTime(2026, 9, 11, 11), // Day 2
        DateTime(2026, 9, 12, 12), // Day 3
        DateTime(2026, 9, 13, 12), // Day 4 (today)
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 4);
      expect(info.isTodayProductive, isTrue);
      expect(info.currentMultiplier, 1.05);
      expect(info.multiplierForNewReward, 1.05);
    });

    test('days 1, 2, and 3 maintain baseline 1.00x multiplier', () {
      final completions = [
        DateTime(2026, 9, 10, 10), // Day 1
        DateTime(2026, 9, 11, 11), // Day 2
        DateTime(2026, 9, 12, 12), // Day 3
      ];

      final info1 = engine.calculate(
        completionDates: [completions[0]],
        today: DateTime(2026, 9, 10, 18),
      );
      expect(info1.streakLength, 1);
      expect(info1.currentMultiplier, 1.00);

      final info2 = engine.calculate(
        completionDates: completions.take(2),
        today: DateTime(2026, 9, 11, 18),
      );
      expect(info2.streakLength, 2);
      expect(info2.currentMultiplier, 1.00);

      final info3 = engine.calculate(
        completionDates: completions,
        today: DateTime(2026, 9, 12, 18),
      );
      expect(info3.streakLength, 3);
      expect(info3.currentMultiplier, 1.00);
      expect(info3.multiplierForNewReward, 1.00);

      // On Day 4 morning (before any task completed today), streak is 3 from yesterday:
      final info4Morning = engine.calculate(
        completionDates: completions,
        today: DateTime(2026, 9, 13, 9),
      );
      expect(info4Morning.streakLength, 3);
      expect(info4Morning.currentMultiplier, 1.00);
      // Completing Day 4 will advance streak to 4 and trigger first boosted multiplier (1.05)
      expect(info4Morning.multiplierForNewReward, 1.05);
    });

    test('maintains active streak from yesterday when today has not yet been completed', () {
      final today = DateTime(2026, 9, 12, 9); // Morning, nothing done yet today
      final completions = [
        DateTime(2026, 9, 10, 15),
        DateTime(2026, 9, 11, 20),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      // Streak from yesterday is 2 days
      expect(info.streakLength, 2);
      expect(info.isTodayProductive, isFalse);
      expect(info.currentMultiplier, 1.00);
      // Completing a task today will advance streak to 3 (multiplier remains 1.00)
      expect(info.multiplierForNewReward, 1.00);
    });

    test('advances streak once today is completed after yesterday', () {
      final today = DateTime(2026, 9, 12, 12);
      final completions = [
        DateTime(2026, 9, 11, 20),
        DateTime(2026, 9, 12, 11),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 2);
      expect(info.isTodayProductive, isTrue);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
    });

    test('supports custom daily bonus configured on the engine', () {
      const customEngine = StreakEngine(bonusPerDay: 0.10);
      final today = DateTime(2026, 9, 14, 12);
      final completions = [
        DateTime(2026, 9, 11, 10),
        DateTime(2026, 9, 12, 10),
        DateTime(2026, 9, 13, 10),
        DateTime(2026, 9, 14, 10),
      ];

      final info = customEngine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 4);
      expect(info.currentMultiplier, 1.10);
    });
  });

  group('One missed day', () {
    test('missing yesterday breaks consecutive streak to 0 if today not completed', () {
      final today = DateTime(2026, 9, 12, 10);
      // Completed on 9/10, missed 9/11
      final completions = [
        DateTime(2026, 9, 10, 14),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 0);
      expect(info.isTodayProductive, isFalse);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
    });

    test('after missing yesterday, completing a task today restarts streak at 1 with 1.00x', () {
      final today = DateTime(2026, 9, 12, 15);
      // Completed on 9/9, 9/10, missed 9/11, completed today 9/12
      final completions = [
        DateTime(2026, 9, 9, 10),
        DateTime(2026, 9, 10, 10),
        DateTime(2026, 9, 12, 14),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 1);
      expect(info.isTodayProductive, isTrue);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
    });
  });

  group('Multiple missed days', () {
    test('gap of several days breaks streak to 0', () {
      final today = DateTime(2026, 9, 20, 10);
      final completions = [
        DateTime(2026, 9, 1, 10),
        DateTime(2026, 9, 2, 10),
        DateTime(2026, 9, 3, 10),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 0);
      expect(info.isTodayProductive, isFalse);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
    });

    test('completing after multiple missed days starts new streak at 1 with 1.00x', () {
      final today = DateTime(2026, 9, 20, 10);
      final completions = [
        DateTime(2026, 9, 1, 10),
        DateTime(2026, 9, 20, 9),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 1);
      expect(info.isTodayProductive, isTrue);
      expect(info.currentMultiplier, 1.00);
    });
  });

  group('Duplicate completions on the same day', () {
    test('multiple tasks on the same day count as a single productive day', () {
      final today = DateTime(2026, 9, 12, 22);
      final completions = [
        DateTime(2026, 9, 12, 8, 0),
        DateTime(2026, 9, 12, 11, 30),
        DateTime(2026, 9, 12, 15, 45),
        DateTime(2026, 9, 12, 21, 10),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 1);
      expect(info.isTodayProductive, isTrue);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
    });

    test('multiple tasks on multiple consecutive days count each day once', () {
      final today = DateTime(2026, 9, 12, 20);
      final completions = [
        DateTime(2026, 9, 11, 9, 0),
        DateTime(2026, 9, 11, 14, 0),
        DateTime(2026, 9, 11, 23, 0),
        DateTime(2026, 9, 12, 7, 0),
        DateTime(2026, 9, 12, 19, 0),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 2);
      expect(info.isTodayProductive, isTrue);
      expect(info.currentMultiplier, 1.00);
      expect(info.multiplierForNewReward, 1.00);
    });
  });

  group('Multiplier cap', () {
    test('caps multiplier at hard maximum of 1.50x and starts positive boost on day 4', () {
      expect(engine.calculateMultiplier(1), 1.00);
      expect(engine.calculateMultiplier(2), 1.00);
      expect(engine.calculateMultiplier(3), 1.00);
      expect(engine.calculateMultiplier(4), 1.05);
      expect(engine.calculateMultiplier(5), 1.10);
      expect(engine.calculateMultiplier(7), 1.20);
      expect(engine.calculateMultiplier(13), 1.50);
      expect(engine.calculateMultiplier(14), 1.50);
      expect(engine.calculateMultiplier(30), 1.50);
      expect(engine.calculateMultiplier(100), 1.50);
    });

    test('streak calculation with 15 consecutive days respects 1.50x cap', () {
      final today = DateTime(2026, 9, 15, 12);
      final completions = List.generate(
        15,
        (i) => DateTime(2026, 9, 1 + i, 10),
      );

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 15);
      expect(info.currentMultiplier, 1.50);
      expect(info.multiplierForNewReward, 1.50);
    });
  });

  group('Date boundaries', () {
    test('handles month boundaries correctly (January 31 to February 1)', () {
      final today = DateTime(2026, 2, 1, 10);
      final completions = [
        DateTime(2026, 1, 31, 22),
        DateTime(2026, 2, 1, 9),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 2);
      expect(info.currentMultiplier, 1.00);
    });

    test('handles leap year transition (Feb 28 -> Feb 29 -> Mar 1, 2024)', () {
      final today = DateTime(2024, 3, 1, 10);
      final completions = [
        DateTime(2024, 2, 28, 12),
        DateTime(2024, 2, 29, 12),
        DateTime(2024, 3, 1, 12),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 3);
      expect(info.currentMultiplier, 1.00);
    });

    test('handles non-leap year transition (Feb 28 -> Mar 1, 2026)', () {
      final today = DateTime(2026, 3, 1, 10);
      final completions = [
        DateTime(2026, 2, 28, 14),
        DateTime(2026, 3, 1, 9),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 2);
      expect(info.currentMultiplier, 1.00);
    });

    test('handles year boundaries (December 31 to January 1)', () {
      final today = DateTime(2026, 1, 1, 8);
      final completions = [
        DateTime(2025, 12, 31, 23, 45),
        DateTime(2026, 1, 1, 0, 15),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 2);
      expect(info.currentMultiplier, 1.00);
    });

    test('two tasks minutes apart across midnight are two consecutive days', () {
      final today = DateTime(2026, 6, 2, 0, 5);
      final completions = [
        DateTime(2026, 6, 1, 23, 58),
        DateTime(2026, 6, 2, 0, 2),
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 2);
      expect(info.isTodayProductive, isTrue);
    });

    test('ignores completions strictly in the future relative to today', () {
      final today = DateTime(2026, 9, 12, 10);
      final completions = [
        DateTime(2026, 9, 11, 10),
        DateTime(2026, 9, 12, 10),
        DateTime(2026, 9, 13, 10), // Future date
      ];

      final info = engine.calculate(
        completionDates: completions,
        today: today,
      );

      expect(info.streakLength, 2);
      expect(info.currentMultiplier, 1.00);
    });

    test('works deterministically with unsorted completion dates', () {
      final today = DateTime(2026, 9, 14, 12);
      final completions = [
        DateTime(2026, 9, 13, 18),
        DateTime(2026, 9, 11, 9),
        DateTime(2026, 9, 14, 11),
        DateTime(2026, 9, 12, 15),
      ];

      final info1 = engine.calculate(
        completionDates: completions,
        today: today,
      );
      final info2 = engine.calculate(
        completionDates: completions.reversed,
        today: today,
      );

      expect(info1.streakLength, 4);
      expect(info2.streakLength, 4);
      expect(info1, equals(info2));
    });
  });
}
