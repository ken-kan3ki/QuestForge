import 'package:flutter/material.dart';

import '../models/quest_type.dart';
import '../models/task.dart';
import '../services/date_display.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
    this.canComplete = true,
    this.isComplete = false,
  });

  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canComplete;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final completed = isComplete || task.isCompleted;
    final overdue =
        !completed &&
        task.dueDate != null &&
        isDueDateOverdue(task.dueDate!, DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              key: Key('complete-task-${task.id}'),
              tooltip: completed
                  ? 'Completed'
                  : (canComplete ? 'Mark complete' : 'Not due today'),
              onPressed: canComplete ? onComplete : null,
              icon: Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: completed ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: completed
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
                  ),
                  if (task.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.bolt,
                        label: '${task.xpReward} XP',
                      ),
                      _MetaChip(
                        icon: task.questType == QuestType.habit
                            ? Icons.replay
                            : Icons.flag_outlined,
                        label: task.questType == QuestType.habit
                            ? 'Character Arc'
                            : 'Side Hustle',
                      ),
                      if (task.isHabit && task.recurrence != null)
                        _MetaChip(
                          icon: Icons.schedule,
                          label: task.recurrence!.displayLabel,
                        ),
                      if (task.dueDate != null)
                        _MetaChip(
                          icon: Icons.event,
                          label: overdue
                              ? 'Due ${formatTaskDate(task.dueDate!)} · overdue'
                              : 'Due ${formatTaskDate(task.dueDate!)}',
                          emphasize: overdue,
                        ),
                      if (completed)
                        const _MetaChip(
                          icon: Icons.flag,
                          label: 'Completed',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('edit-task-${task.id}'),
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: Key('delete-task-${task.id}'),
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = emphasize ? colors.error : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (emphasize ? colors.error : colors.outlineVariant).withValues(
          alpha: 0.16,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
