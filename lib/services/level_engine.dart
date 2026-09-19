import 'dart:math' as math;

import '../core/constants/game_constants.dart';

/// Immutable snapshot of a player's level-progression state for a given
/// amount of total XP.
///
/// This is a pure value object: it holds only the derived numbers a UI needs
/// to render a level and a progress bar. It performs no calculation itself —
/// all values are computed by [LevelEngine] so widgets never do XP math.
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.totalXp,
    required this.xpForCurrentLevel,
    required this.xpForNextLevel,
    required this.xpIntoCurrentLevel,
    required this.progressToNextLevel,
  });

  /// The player's current level. In the range `1..100`. Never 101.
  final int level;

  /// The total accumulated XP this snapshot was calculated from. Never negative.
  final int totalXp;

  /// Total XP required to have *reached* the current level — the lower
  /// boundary of the current level. For level 1 this is `0`.
  final int xpForCurrentLevel;

  /// Total XP required to reach the *next* level — the upper boundary of the
  /// current level. At level 100, equals [xpForCurrentLevel] + span of level 99.
  final int xpForNextLevel;

  /// XP earned since reaching the current level.
  final int xpIntoCurrentLevel;

  /// Progress toward the next level as a fraction in the range `[0.0, 1.0]`.
  /// At level 100, this is always `1.0` (100%).
  final double progressToNextLevel;

  /// Remaining XP needed to reach the next level. `0` at level 100.
  int get xpToNextLevel =>
      level >= LevelEngine.maxLevel ? 0 : math.max(0, xpForNextLevel - totalXp);

  /// The XP width of the current level (`xpForNextLevel - xpForCurrentLevel`).
  int get xpSpanForCurrentLevel => xpForNextLevel - xpForCurrentLevel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelProgress &&
          level == other.level &&
          totalXp == other.totalXp &&
          xpForCurrentLevel == other.xpForCurrentLevel &&
          xpForNextLevel == other.xpForNextLevel &&
          xpIntoCurrentLevel == other.xpIntoCurrentLevel &&
          progressToNextLevel == other.progressToNextLevel;

  @override
  int get hashCode => Object.hash(
        level,
        totalXp,
        xpForCurrentLevel,
        xpForNextLevel,
        xpIntoCurrentLevel,
        progressToNextLevel,
      );

  @override
  String toString() =>
      'LevelProgress('
      'level: $level, '
      'totalXp: $totalXp, '
      'xpForCurrentLevel: $xpForCurrentLevel, '
      'xpForNextLevel: $xpForNextLevel, '
      'xpIntoCurrentLevel: $xpIntoCurrentLevel, '
      'progressToNextLevel: $progressToNextLevel)';
}

/// Pure, deterministic engine that converts a total XP amount into a
/// [LevelProgress].
///
/// Implements the exact 100-level XP progression formula:
/// `requiredXpForLevel(L) = round(20 + 3 * L + 0.20 * L^2)` for `L = 1..99`.
/// Level 100 is the final level cap (~82,500 total cumulative XP).
class LevelEngine {
  const LevelEngine({
    this.baseXp = GameConstants.minCustomXp,
    this.growthFactor = 1.0,
  });

  static const int minLevel = GameConstants.minLevel;
  static const int maxLevel = GameConstants.maxLevel;

  /// Retained for backward compatibility.
  final int baseXp;
  final double growthFactor;

  // ---------------------------------------------------------------------------
  // THE XP CURVE — single source of truth.
  // ---------------------------------------------------------------------------

  /// XP required to advance *from* [level] to `level + 1`.
  ///
  /// Formula: `round(20 + 3 * L + 0.20 * L^2)` where `L = 1..99`.
  /// Returns 0 for level >= 100 (max level).
  int requiredXpForLevel(int level) {
    if (level < 1) return requiredXpForLevel(1);
    if (level >= maxLevel) return 0;
    return (20 + 3 * level + 0.20 * level * level).round();
  }

  /// Total (cumulative) XP required to reach [level].
  ///
  /// `totalXpRequiredForLevel(1) = 0`.
  /// For level N: `sum(requiredXpForLevel(L), L = 1..N-1)`.
  /// For level 100, this evaluates to exactly 82,500 XP.
  int totalXpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    final target = level > maxLevel ? maxLevel : level;
    var total = 0;
    for (var l = 1; l < target; l++) {
      total += requiredXpForLevel(l);
    }
    return total;
  }

  /// Calculates XP earned into the current level from [totalXp].
  int xpIntoCurrentLevel(int totalXp) {
    final xp = totalXp < 0 ? 0 : totalXp;
    final lvl = levelFromTotalXp(xp);
    final floor = totalXpRequiredForLevel(lvl);
    return xp - floor;
  }

  /// XP required to reach the next level from [level].
  /// Returns 0 if already at or beyond [maxLevel].
  int xpRequiredForNextLevel(int level) {
    return requiredXpForLevel(level);
  }

  /// Calculates the player's level from [totalXp].
  ///
  /// Starting level = 1, maximum level = 100.
  /// Never returns level 101.
  int levelFromTotalXp(int totalXp) {
    if (totalXp <= 0) return 1;
    final capXp = totalXpRequiredForLevel(maxLevel);
    if (totalXp >= capXp) return maxLevel;

    var level = 1;
    var floor = 0;
    while (level < maxLevel) {
      final span = requiredXpForLevel(level);
      if (totalXp < floor + span) {
        return level;
      }
      floor += span;
      level++;
    }
    return maxLevel;
  }

  /// Progress fraction in `[0.0, 1.0]` toward the next level from [totalXp].
  ///
  /// At level 100, always returns 1.0 (100%).
  double progressPercentage(int totalXp) {
    if (totalXp <= 0) return 0.0;
    final capXp = totalXpRequiredForLevel(maxLevel);
    if (totalXp >= capXp) return 1.0;

    final lvl = levelFromTotalXp(totalXp);
    final span = requiredXpForLevel(lvl);
    if (span <= 0) return 1.0;
    final into = xpIntoCurrentLevel(totalXp);
    return (into / span).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Backward compatibility methods for existing code.
  // ---------------------------------------------------------------------------

  /// XP required to advance *from* [level] to `level + 1`.
  int xpSpanForLevel(int level) {
    if (level >= maxLevel) {
      return requiredXpForLevel(maxLevel - 1);
    }
    return requiredXpForLevel(level);
  }

  /// Total (cumulative) XP required to reach [level].
  int xpToReachLevel(int level) {
    return totalXpRequiredForLevel(level);
  }

  /// Computes the full [LevelProgress] for the given [totalXp].
  LevelProgress progressFor(int totalXp) {
    final xp = totalXp < 0 ? 0 : totalXp;
    final lvl = levelFromTotalXp(xp);

    if (lvl >= maxLevel) {
      final floor = totalXpRequiredForLevel(maxLevel);
      final span = requiredXpForLevel(maxLevel - 1);
      final intoLevel = xp - floor;
      return LevelProgress(
        level: maxLevel,
        totalXp: xp,
        xpForCurrentLevel: floor,
        xpForNextLevel: floor + span,
        xpIntoCurrentLevel: span,
        progressToNextLevel: 1.0,
      );
    }

    final currentFloor = totalXpRequiredForLevel(lvl);
    final span = requiredXpForLevel(lvl);
    final nextFloor = currentFloor + span;
    final intoLevel = xp - currentFloor;
    final progress = span > 0 ? (intoLevel / span).clamp(0.0, 1.0) : 1.0;

    return LevelProgress(
      level: lvl,
      totalXp: xp,
      xpForCurrentLevel: currentFloor,
      xpForNextLevel: nextFloor,
      xpIntoCurrentLevel: intoLevel,
      progressToNextLevel: progress,
    );
  }
}
