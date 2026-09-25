import 'package:flutter/foundation.dart';

import '../models/avatar_progression.dart';
import '../models/player_stats.dart';
import '../models/quest_type.dart';
import '../models/recurrence_rule.dart';
import '../models/reminder_config.dart';
import '../models/task.dart';
import '../models/xp_transaction.dart';
import '../services/avatar_engine.dart';
import '../services/level_engine.dart';
import '../services/recurrence_engine.dart';
import '../services/reminder_service.dart';
import '../services/statistics_service.dart';
import '../services/streak_engine.dart';
import '../services/task_repository.dart';
import '../services/xp_completion_id.dart';
import '../services/xp_ledger.dart';

class TaskController extends ChangeNotifier {
  TaskController(
    this._repository, {
    XpLedger? xpLedger,
    StreakEngine? streakEngine,
    LevelEngine? levelEngine,
    AvatarEngine? avatarEngine,
    RecurrenceEngine? recurrenceEngine,
    StatisticsService? statisticsService,
    ReminderService? reminderService,
    DateTime Function()? clock,
  }) : _xpLedger = xpLedger ?? InMemoryXpLedger(),
       _streakEngine = streakEngine ?? const StreakEngine(),
       _levelEngine = levelEngine ?? const LevelEngine(),
       _avatarEngine = avatarEngine ?? const AvatarEngine(),
       _recurrenceEngine = recurrenceEngine ?? const RecurrenceEngine(),
       _statisticsService = statisticsService ?? const StatisticsService(),
       _reminderService = reminderService ?? ReminderService(),
       _clock = clock ?? DateTime.now;

  final TaskRepository _repository;
  final XpLedger _xpLedger;
  final StreakEngine _streakEngine;
  final LevelEngine _levelEngine;
  final AvatarEngine _avatarEngine;
  final RecurrenceEngine _recurrenceEngine;
  final StatisticsService _statisticsService;
  final ReminderService _reminderService;
  final DateTime Function() _clock;

  ReminderService get reminderService => _reminderService;

  List<Task> get tasks => _repository.getAll();

  List<Task> get activeTasks {
    final now = _clock();
    return tasks.where((task) {
      if (task.isHabit) {
        return !task.hasCompletedOn(now);
      }
      return !task.isCompleted;
    }).toList(growable: false);
  }

  List<Task> get completedTasks {
    final now = _clock();
    return tasks.where((task) {
      if (task.isHabit) {
        return task.hasCompletedOn(now);
      }
      return task.isCompleted;
    }).toList(growable: false);
  }

  bool get isEmpty => tasks.isEmpty;

  int get totalXp => _xpLedger.totalXp;

  LevelProgress get levelProgress => _levelEngine.progressFor(totalXp);

  AvatarProgression get avatarProgression =>
      _avatarEngine.progressionFor(
        totalXp: totalXp,
        level: levelProgress.level,
        levelEngine: _levelEngine,
      );

  List<XpTransaction> get xpTransactions => _xpLedger.transactions;

  bool canComplete(Task task, [DateTime? at]) {
    return _recurrenceEngine.canComplete(task, at ?? _clock());
  }

  StreakInfo streakInfo([DateTime? today]) {
    final dates = _completionDates.toList(growable: false);
    return _streakEngine.calculate(
      completionDates: dates,
      today: today ?? _clock(),
    );
  }

  int get currentStreak => streakInfo().streakLength;

  int get longestStreak =>
      _streakEngine.calculateLongestStreak(_completionDates);

  double get currentMultiplier => streakInfo().currentMultiplier;

  StatisticsData get statistics => _statisticsService.calculate(
        tasks: tasks,
        xpTransactions: xpTransactions,
        totalXpOverride: totalXp,
        now: _clock(),
      );

  Task createTask({
    required String title,
    String? description,
    required int xpReward,
    DateTime? dueDate,
    QuestType questType = QuestType.sideQuest,
    RecurrenceRule? recurrence,
    ReminderConfig? reminder,
  }) {
    final task = _repository.create(
      title: title.trim(),
      description: description,
      xpReward: xpReward,
      dueDate: dueDate,
      questType: questType,
      recurrence: recurrence,
      reminder: reminder,
    );
    if (task.reminder != null && task.reminder!.enabled) {
      _reminderService.scheduleTaskReminder(task);
    }
    notifyListeners();
    return task;
  }

  Task updateTask(Task task) {
    final oldTask = tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );
    final updated = _repository.update(task);
    _reminderService.rescheduleTaskReminder(oldTask, updated);
    notifyListeners();
    return updated;
  }

  Task completeTask(String id, {DateTime? completedAt}) {
    final at = completedAt ?? _clock();
    final current = tasks.firstWhere((task) => task.id == id);
    if (!_recurrenceEngine.canComplete(current, at)) {
      return current;
    }
    final completed = _repository.complete(id, completedAt: at);
    _awardXpFor(completed, awardedAt: at);
    notifyListeners();
    return completed;
  }

  Task uncompleteTask(String id) {
    final current = tasks.firstWhere((task) => task.id == id);
    final completionId = _completionIdOf(current);
    final reopened = _repository.uncomplete(id);
    if (completionId != null) {
      _xpLedger.reverseForCompletion(completionId);
    }
    notifyListeners();
    return reopened;
  }

  /// Triggers a UI refresh by notifying all listeners.
  ///
  /// Call this after external async operations (e.g. loading from persistence)
  /// complete to rebuild the widget tree with updated data.
  void refresh() => notifyListeners();

  void deleteTask(String id) {
    _reminderService.cancelTaskReminders(id);
    _repository.delete(id);
    notifyListeners();
  }

  /// Restores complete task and XP transaction history (e.g. from a local backup),
  /// updates underlying persistence, recalculates all derived states, and notifies listeners.
  Future<void> restoreProgress({
    required List<Task> tasks,
    required List<XpTransaction> xpTransactions,
  }) async {
    final repoResult = _repository.replaceAll(tasks);
    if (repoResult is Future) {
      await repoResult;
    }
    final ledgerResult = _xpLedger.replaceAll(xpTransactions);
    if (ledgerResult is Future) {
      await ledgerResult;
    }
    await _reminderService.syncAllTaskReminders(tasks);
    notifyListeners();
  }

  void _awardXpFor(Task task, {required DateTime awardedAt}) {
    final completionId = _completionIdOf(task, at: awardedAt);
    if (completionId == null) {
      return;
    }

    final streakInfo = _streakEngine.calculate(
      completionDates: _completionDates,
      today: awardedAt,
    );
    final multiplier = streakInfo.currentMultiplier;

    _xpLedger.award(
      sourceTaskId: task.id,
      baseXp: task.xpReward,
      completionId: completionId,
      multiplier: multiplier,
      timestamp: awardedAt,
    );
  }

  Iterable<DateTime> get _completionDates sync* {
    for (final t in tasks) {
      if (t.isHabit) {
        yield* t.completedDates;
      } else if (t.isCompleted && t.completedAt != null) {
        yield t.completedAt!;
      }
    }
    for (final tx in _xpLedger.transactions) {
      if (!tx.reversed) {
        yield tx.timestamp;
      }
    }
  }

  String? _completionIdOf(Task task, {DateTime? at}) {
    if (task.isHabit) {
      final occurrenceAt = at ?? task.completedAt;
      if (occurrenceAt == null) {
        return null;
      }
      return xpOccurrenceCompletionId(
        taskId: task.id,
        completedAt: occurrenceAt,
      );
    }
    final completedAt = at ?? task.completedAt;
    if (!task.isCompleted || completedAt == null) {
      return null;
    }
    return xpCompletionId(taskId: task.id, completedAt: completedAt);
  }
}
