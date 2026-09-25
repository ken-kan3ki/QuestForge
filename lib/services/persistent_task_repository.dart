import 'dart:convert';

import '../models/quest_type.dart';
import '../models/recurrence_rule.dart';
import '../models/reminder_config.dart';
import '../models/task.dart';
import 'persistence_service.dart';
import 'task_repository.dart';

/// A [TaskRepository] implementation that transparently persists tasks
/// using a [PersistenceService].
///
/// Keeps an in-memory cache for synchronous operations and asynchronously
/// writes updates to storage whenever tasks are created, updated, completed,
/// uncompleted, or deleted.
class PersistentTaskRepository implements TaskRepository {
  PersistentTaskRepository({
    required PersistenceService persistenceService,
    String storageKey = defaultStorageKey,
    DateTime Function()? clock,
    List<Task>? initialTasks,
  })  : _persistenceService = persistenceService, // ignore: prefer_initializing_formals
        _storageKey = storageKey, // ignore: prefer_initializing_formals
        _clock = clock ?? DateTime.now {
    if (initialTasks != null) {
      _tasks.addAll(initialTasks);
      _syncNextId();
    }
  }

  /// Default storage key used in [PersistenceService].
  static const String defaultStorageKey = 'pro_rpg_tasks';

  final PersistenceService _persistenceService;
  final String _storageKey;
  final DateTime Function() _clock;
  final List<Task> _tasks = [];
  int _nextId = 1;

  /// Loads persisted tasks from [PersistenceService] into memory.
  Future<void> loadFromPersistence() async {
    final rawJson = await _persistenceService.getString(_storageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        _tasks.clear();
        for (final item in decoded) {
          if (item is Map) {
            _tasks.add(Task.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        _syncNextId();
      }
    } catch (_) {
      // Ignore corrupted cache; retain existing state safely.
    }
  }

  /// Replaces the current tasks list completely (used by backup restoration)
  /// and commits to persistence.
  @override
  Future<void> replaceAll(List<Task> newTasks) async {
    _tasks.clear();
    _tasks.addAll(newTasks);
    _syncNextId();
    await _saveToPersistence();
  }

  @override
  List<Task> getAll() => List.unmodifiable(_tasks);

  @override
  Task create({
    required String title,
    String? description,
    required int xpReward,
    DateTime? dueDate,
    QuestType questType = QuestType.sideQuest,
    RecurrenceRule? recurrence,
    ReminderConfig? reminder,
  }) {
    final task = Task(
      id: 'task_${_nextId++}',
      title: title,
      description: description,
      xpReward: xpReward,
      dueDate: dueDate,
      createdAt: _clock(),
      questType: questType,
      recurrence: questType == QuestType.habit
          ? (recurrence ?? RecurrenceRule.daily)
          : null,
      reminder: reminder,
    );
    _tasks.add(task);
    _saveToPersistence();
    return task;
  }

  @override
  Task update(Task task) {
    final index = _indexOf(task.id);
    _tasks[index] = task;
    _saveToPersistence();
    return task;
  }

  @override
  Task complete(String id, {DateTime? completedAt}) {
    final index = _indexOf(id);
    final current = _tasks[index];
    final at = completedAt ?? _clock();

    if (current.questType == QuestType.habit) {
      if (current.hasCompletedOn(at)) {
        return current;
      }
      final completed = current.copyWith(
        completedAt: at,
        completedDates: [...current.completedDates, at],
      );
      _tasks[index] = completed;
      _saveToPersistence();
      return completed;
    }

    if (current.isCompleted) {
      return current;
    }

    final completed = current.copyWith(
      isCompleted: true,
      completedAt: at,
    );
    _tasks[index] = completed;
    _saveToPersistence();
    return completed;
  }

  @override
  Task uncomplete(String id) {
    final index = _indexOf(id);
    final current = _tasks[index];

    if (current.questType == QuestType.habit) {
      if (current.completedDates.isEmpty) {
        return current;
      }
      final remaining = current.completedDates.sublist(
        0,
        current.completedDates.length - 1,
      );
      final reopened = current.copyWith(
        completedDates: remaining,
        completedAt: remaining.isEmpty ? null : remaining.last,
        clearCompletedAt: remaining.isEmpty,
      );
      _tasks[index] = reopened;
      _saveToPersistence();
      return reopened;
    }

    if (!current.isCompleted) {
      return current;
    }

    final reopened = current.copyWith(
      isCompleted: false,
      clearCompletedAt: true,
    );
    _tasks[index] = reopened;
    _saveToPersistence();
    return reopened;
  }

  @override
  void delete(String id) {
    final index = _indexOf(id);
    _tasks.removeAt(index);
    _saveToPersistence();
  }

  Future<void> _saveToPersistence() async {
    final rawJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await _persistenceService.setString(_storageKey, rawJson);
  }

  void _syncNextId() {
    var maxId = 0;
    for (final task in _tasks) {
      if (task.id.startsWith('task_')) {
        final parsed = int.tryParse(task.id.substring(5));
        if (parsed != null && parsed > maxId) {
          maxId = parsed;
        }
      }
    }
    _nextId = maxId + 1;
  }

  int _indexOf(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) {
      throw StateError('Task not found: $id');
    }
    return index;
  }
}
