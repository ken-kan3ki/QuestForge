import 'package:flutter/material.dart';

import 'navigation/app_shell.dart';
import 'services/persistence_service.dart';
import 'services/persistent_task_repository.dart';
import 'services/persistent_xp_ledger.dart';
import 'services/reminder_service.dart';
import 'services/shared_preferences_persistence_service.dart';
import 'services/task_repository.dart';
import 'services/xp_ledger.dart';
import 'state/task_controller.dart';
import 'state/task_scope.dart';
import 'theme/app_theme.dart';

class ProRpgApp extends StatefulWidget {
  const ProRpgApp({
    super.key,
    this.taskRepository,
    this.xpLedger,
    this.persistenceService,
    this.reminderService,
  });

  final TaskRepository? taskRepository;
  final XpLedger? xpLedger;
  final PersistenceService? persistenceService;
  final ReminderService? reminderService;

  @override
  State<ProRpgApp> createState() => _ProRpgAppState();
}

class _ProRpgAppState extends State<ProRpgApp> {
  late final TaskController _taskController;

  @override
  void initState() {
    super.initState();
    final persistence =
        widget.persistenceService ?? SharedPreferencesPersistenceService();

    final taskRepo = widget.taskRepository ??
        PersistentTaskRepository(persistenceService: persistence);

    final xpLedger = widget.xpLedger ??
        PersistentXpLedger(persistenceService: persistence);

    final reminderService = widget.reminderService ??
        ReminderService(persistenceService: persistence);

    _taskController = TaskController(
      taskRepo,
      xpLedger: xpLedger,
      reminderService: reminderService,
    );

    if (taskRepo is PersistentTaskRepository) {
      taskRepo.loadFromPersistence().then((_) {
        if (mounted) {
          _taskController.refresh();
        }
      });
    }

    if (xpLedger is PersistentXpLedger) {
      xpLedger.loadFromPersistence().then((_) {
        if (mounted) {
          _taskController.refresh();
        }
      });
    }

    reminderService.loadFromPersistence().then((_) {
      if (mounted) {
        _taskController.refresh();
      }
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TaskScope(
      controller: _taskController,
      child: MaterialApp(
        title: 'QuestForge',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
