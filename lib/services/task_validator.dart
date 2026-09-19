import '../core/constants/game_constants.dart';

class TaskValidationResult {
  const TaskValidationResult({
    this.titleError,
    this.xpError,
  });

  final String? titleError;
  final String? xpError;

  bool get isValid => titleError == null && xpError == null;
}

class TaskValidator {
  const TaskValidator({
    this.minXp = GameConstants.minCustomXp,
    this.maxXp = GameConstants.maxCustomXp,
  });

  final int minXp;
  final int maxXp;

  TaskValidationResult validate({
    required String title,
    required String xpText,
    int? originalXp,
  }) {
    return TaskValidationResult(
      titleError: titleError(title),
      xpError: xpError(xpText, originalXp: originalXp),
    );
  }

  String? titleError(String title) {
    if (title.trim().isEmpty) {
      return 'Enter a task title.';
    }
    return null;
  }

  String? xpError(String xpText, {int? originalXp}) {
    final parsed = int.tryParse(xpText.trim());
    if (parsed == null) {
      return 'Enter a whole number for the XP reward.';
    }
    if (originalXp != null && parsed == originalXp) {
      return null;
    }
    if (parsed < minXp) {
      return 'XP reward must be at least $minXp.';
    }
    if (parsed > maxXp) {
      return 'XP reward cannot exceed $maxXp.';
    }
    return null;
  }

  int parseXp(String xpText, {int? originalXp}) {
    final parsed = int.tryParse(xpText.trim());
    if (parsed == null) {
      throw FormatException('Invalid XP reward: $xpText');
    }
    if (originalXp != null && parsed == originalXp) {
      return parsed;
    }
    if (parsed < minXp || parsed > maxXp) {
      throw FormatException('Invalid XP reward: $xpText');
    }
    return parsed;
  }

  String? normalizeDescription(String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
