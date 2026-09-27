import 'calendar_day.dart';

export 'calendar_day.dart';

/// Immutable summary of a user's productivity streak state at a given reference day.
class StreakInfo {
  const StreakInfo({
    required this.streakLength,
    required this.isTodayProductive,
    required this.currentMultiplier,
    required this.multiplierForNewReward,
  });

  /// The active consecutive productive-day streak length.
  final int streakLength;

  /// Whether today has at least one completed task.
  final bool isTodayProductive;

  /// The XP multiplier corresponding to the current streak.
  final double currentMultiplier;

  /// The XP multiplier that will be awarded for a newly completed task today.
  final double multiplierForNewReward;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakInfo &&
          streakLength == other.streakLength &&
          isTodayProductive == other.isTodayProductive &&
          currentMultiplier == other.currentMultiplier &&
          multiplierForNewReward == other.multiplierForNewReward;

  @override
  int get hashCode => Object.hash(
    streakLength,
    isTodayProductive,
    currentMultiplier,
    multiplierForNewReward,
  );

  @override
  String toString() =>
      'StreakInfo('
      'streakLength: $streakLength, '
      'isTodayProductive: $isTodayProductive, '
      'currentMultiplier: $currentMultiplier, '
      'multiplierForNewReward: $multiplierForNewReward)';
}

/// Pure deterministic calculation engine for productivity streaks and XP multipliers.
///
/// A productive day is defined as any calendar day containing at least one
/// eligible completed task.
class StreakEngine {
  const StreakEngine({
    this.bonusPerDay = 0.05,
    this.maxMultiplier = 1.50,
    this.baseMultiplier = 1.00,
  });

  /// The incremental multiplier added for each consecutive productive day after the first.
  final double bonusPerDay;

  /// Hard ceiling for the streak multiplier.
  final double maxMultiplier;

  /// Baseline multiplier for the first productive day or streak of 0.
  final double baseMultiplier;

  /// Calculates the full [StreakInfo] for the provided [completionDates] relative to [today].
  StreakInfo calculate({
    required Iterable<DateTime> completionDates,
    required DateTime today,
  }) {
    final todayDay = CalendarDay.from(today);
    final productiveDays = <CalendarDay>{};

    for (final date in completionDates) {
      final day = CalendarDay.from(date);
      if (day.compareTo(todayDay) <= 0) {
        productiveDays.add(day);
      }
    }

    final isTodayProductive = productiveDays.contains(todayDay);

    var streak = 0;
    if (isTodayProductive) {
      streak = 1;
      var checkDay = todayDay.previousDay;
      while (productiveDays.contains(checkDay)) {
        streak++;
        checkDay = checkDay.previousDay;
      }
    } else {
      final yesterday = todayDay.previousDay;
      if (productiveDays.contains(yesterday)) {
        // Today is still in progress; consecutive streak from yesterday is intact.
        streak = 1;
        var checkDay = yesterday.previousDay;
        while (productiveDays.contains(checkDay)) {
          streak++;
          checkDay = checkDay.previousDay;
        }
      } else {
        // Missing yesterday breaks the consecutive streak.
        streak = 0;
      }
    }

    final currentMult = calculateMultiplier(streak);
    final newRewardStreak = isTodayProductive ? streak : (streak + 1);
    final newRewardMult = calculateMultiplier(newRewardStreak);

    return StreakInfo(
      streakLength: streak,
      isTodayProductive: isTodayProductive,
      currentMultiplier: currentMult,
      multiplierForNewReward: newRewardMult,
    );
  }

  /// Calculates the current consecutive streak length as of [today].
  int calculateStreakLength({
    required Iterable<DateTime> completionDates,
    required DateTime today,
  }) {
    return calculate(
      completionDates: completionDates,
      today: today,
    ).streakLength;
  }

  /// Calculates the all-time longest consecutive productive-day streak from [completionDates].
  int calculateLongestStreak(Iterable<DateTime> completionDates) {
    final uniqueDays = <CalendarDay>{};
    for (final date in completionDates) {
      uniqueDays.add(CalendarDay.from(date));
    }

    if (uniqueDays.isEmpty) {
      return 0;
    }

    final sortedDays = uniqueDays.toList()..sort();
    var longest = 1;
    var current = 1;

    for (var i = 1; i < sortedDays.length; i++) {
      if (sortedDays[i] == sortedDays[i - 1].nextDay) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else {
        current = 1;
      }
    }

    return longest;
  }

  /// Returns whether [day] is a productive day having at least one completion.
  bool isProductiveDay({
    required Iterable<DateTime> completionDates,
    required DateTime day,
  }) {
    final targetDay = CalendarDay.from(day);
    for (final date in completionDates) {
      if (CalendarDay.from(date) == targetDay) {
        return true;
      }
    }
    return false;
  }

  /// Returns the XP multiplier for a given [streakLength], capped at [maxMultiplier].
  ///
  /// Positive multiplier progression begins after 3 consecutive productive days:
  /// - Day 1: 1.00x
  /// - Day 2: 1.00x
  /// - Day 3: 1.00x
  /// - Day 4: 1.05x (first boosted multiplier)
  /// - Day 5+: increases by [bonusPerDay] up to [maxMultiplier]
  double calculateMultiplier(int streakLength) {
    if (streakLength <= 3) {
      return baseMultiplier;
    }
    final raw = baseMultiplier + (streakLength - 3) * bonusPerDay;
    if (raw >= maxMultiplier) {
      return maxMultiplier;
    }
    return double.parse(raw.toStringAsFixed(2));
  }

  /// Returns the XP multiplier that applies to a newly completed task on [today].
  double multiplierForNewReward({
    required Iterable<DateTime> completionDates,
    required DateTime today,
  }) {
    return calculate(
      completionDates: completionDates,
      today: today,
    ).multiplierForNewReward;
  }
}
