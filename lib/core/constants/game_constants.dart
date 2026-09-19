/// Centralized constants for the Productivity RPG game mechanics.
///
/// Ensures game balancing values (XP rewards, streak multipliers, level curve)
/// are defined in a single location rather than scattered as magic numbers.
abstract final class GameConstants {
  // ── Quest XP Difficulties ───────────────────────────────────────────────────
  /// XP awarded for a Light quest.
  static const int xpLight = 5;

  /// XP awarded for a Standard quest.
  static const int xpStandard = 10;

  /// XP awarded for a Challenging quest.
  static const int xpChallenging = 20;

  /// Minimum custom XP allowed for tasks (Section 11).
  static const int minCustomXp = 5;

  /// Maximum custom XP allowed for tasks (Section 11).
  static const int maxCustomXp = 50;

  /// Retained aliases for backward compatibility.
  static const int xpSmall = xpLight;
  static const int xpNormal = xpStandard;
  static const int xpLarge = xpChallenging;
  static const int xpMajor = 50;

  /// Map of difficulty labels to their respective base XP values.
  static const Map<String, int> difficultyXpMap = {
    'Light': xpLight,
    'Standard': xpStandard,
    'Challenging': xpChallenging,
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
