import '../models/quest_type.dart';
import '../models/recurrence_rule.dart';
import '../models/reminder_config.dart';
import '../models/task.dart';

abstract class TaskRepository {
  List<Task> getAll();

  Task create({
    required String title,
    String? description,
    required int xpReward,
    DateTime? dueDate,
    QuestType questType = QuestType.sideQuest,
    RecurrenceRule? recurrence,
    ReminderConfig? reminder,
  });

  Task update(Task task);

  Task complete(String id, {DateTime? completedAt});

  Task uncomplete(String id);

  void delete(String id);

  dynamic replaceAll(List<Task> tasks);
}

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({List<Task>? seed, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    if (seed != null) {
      _tasks.addAll(seed);
      _syncNextId();
    }
  }

  final DateTime Function() _clock;
  final List<Task> _tasks = [];
  int _nextId = 1;

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
    return task;
  }

  @override
  Task update(Task task) {
    final index = _indexOf(task.id);
    _tasks[index] = task;
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
    return reopened;
  }

  @override
  void delete(String id) {
    final index = _indexOf(id);
    _tasks.removeAt(index);
  }

  @override
  void replaceAll(List<Task> tasks) {
    _tasks.clear();
    _tasks.addAll(tasks);
    _syncNextId();
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
