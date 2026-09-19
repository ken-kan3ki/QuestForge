import '../core/constants/game_constants.dart';

/// Difficulty rating for a quest, mapping directly to default base XP awards.
enum QuestDifficulty {
  light,
  standard,
  challenging,
  custom;

  /// User-facing display title for this difficulty.
  String get label {
    switch (this) {
      case QuestDifficulty.light:
        return 'Light';
      case QuestDifficulty.standard:
        return 'Standard';
      case QuestDifficulty.challenging:
        return 'Challenging';
      case QuestDifficulty.custom:
        return 'Custom';
    }
  }

  /// Default base XP reward for preset difficulties, or null for [custom].
  int? get defaultXp {
    switch (this) {
      case QuestDifficulty.light:
        return GameConstants.xpLight;
      case QuestDifficulty.standard:
        return GameConstants.xpStandard;
      case QuestDifficulty.challenging:
        return GameConstants.xpChallenging;
      case QuestDifficulty.custom:
        return null;
    }
  }

  /// Infers the appropriate [QuestDifficulty] from a stored [xp] value.
  /// If the XP matches a preset, selects that preset; otherwise selects [custom].
  static QuestDifficulty fromXp(int xp) {
    if (xp == GameConstants.xpLight) return QuestDifficulty.light;
    if (xp == GameConstants.xpStandard) return QuestDifficulty.standard;
    if (xp == GameConstants.xpChallenging) return QuestDifficulty.challenging;
    return QuestDifficulty.custom;
  }
}
