/// Centralized constants for the Productivity RPG game mechanics.
///
/// Ensures game balancing values (XP rewards, streak multipliers, level curve)
/// are defined in a single location rather than scattered as magic numbers.
abstract final class GameConstants {
  // ── Quest XP Difficulties ───────────────────────────────────────────────────
  /// XP awarded for a Small quest (e.g. quick chore, drinking water).
  static const int xpSmall = 25;

  /// XP awarded for a Normal quest (e.g. 30min walk, normal workout).
  static const int xpNormal = 50;

  /// XP awarded for a Large quest (e.g. focused study session, large task).
  static const int xpLarge = 100;

  /// XP awarded for a Major quest (e.g. exam, project milestone).
  static const int xpMajor = 150;

  /// Minimum custom XP allowed for tasks.
  static const int minCustomXp = 25;

  /// Maximum custom XP allowed for tasks.
  static const int maxCustomXp = 500;

  /// Map of difficulty labels to their respective base XP values.
  static const Map<String, int> difficultyXpMap = {
    'Small': xpSmall,
    'Normal': xpNormal,
    'Large': xpLarge,
    'Major': xpMajor,
  };

  // ── Streak Multipliers ─────────────────────────────────────────────────────
  /// Baseline multiplier for a fresh streak or day 1.
  static const double baseStreakMultiplier = 1.00;

  /// Incremental multiplier added for each consecutive productive day.
  static const double streakBonusPerDay = 0.05;

  /// Maximum multiplier achievable from consecutive productive days.
  static const double maxStreakMultiplier = 1.50;

  // ── Level Progression Curve ────────────────────────────────────────────────
  /// Starting level for a player.
  static const int minLevel = 1;

  /// Maximum level cap (Level 100 is the final level).
  static const int maxLevel = 100;
}
