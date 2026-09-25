import 'package:flutter/material.dart';

import '../models/task.dart';
import '../state/task_scope.dart';
import '../widgets/task_empty_state.dart';
import '../widgets/task_tile.dart';
import 'task_editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openEditor(BuildContext context, {Task? task}) async {
    final draft = await Navigator.of(context).push<Task>(
      MaterialPageRoute(builder: (_) => TaskEditorScreen(task: task)),
    );
    if (!context.mounted || draft == null) {
      return;
    }

    final controller = TaskScope.of(context);
    if (task == null) {
      controller.createTask(
        title: draft.title,
        description: draft.description,
        xpReward: draft.xpReward,
        dueDate: draft.dueDate,
        questType: draft.questType,
        recurrence: draft.recurrence,
        reminder: draft.reminder,
      );
      return;
    }

    controller.updateTask(
      task.copyWith(
        title: draft.title,
        description: draft.description,
        clearDescription: draft.description == null,
        xpReward: draft.xpReward,
        dueDate: draft.dueDate,
        clearDueDate: draft.dueDate == null,
        questType: draft.questType,
        recurrence: draft.recurrence,
        clearRecurrence: draft.recurrence == null,
        reminder: draft.reminder,
        clearReminder: draft.reminder == null,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete this quest?'),
          content: Text('"${task.title}" will be removed. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && context.mounted) {
      TaskScope.of(context).deleteTask(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = TaskScope.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('QuestForge')),
      floatingActionButton: controller.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('New Quest'),
            ),
      body: SafeArea(
        child: controller.isEmpty
            ? TaskEmptyState(onCreate: () => _openEditor(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                children: [
                  Text(
                    'Adventure board',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track real-life quests. Character Arcs return when they are due; Side Hustles stay done.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (controller.activeTasks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Active',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...controller.activeTasks.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskTile(
                          task: task,
                          canComplete: controller.canComplete(task),
                          isComplete: false,
                          onComplete: () => controller.completeTask(task.id),
                          onEdit: () => _openEditor(context, task: task),
                          onDelete: () => _confirmDelete(context, task),
                        ),
                      ),
                    ),
                  ],
                  if (controller.completedTasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Completed',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...controller.completedTasks.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskTile(
                          task: task,
                          canComplete: false,
                          isComplete: true,
                          onComplete: () {},
                          onEdit: () => _openEditor(context, task: task),
                          onDelete: () => _confirmDelete(context, task),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
