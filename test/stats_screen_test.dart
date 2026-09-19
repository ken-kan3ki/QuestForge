import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prod/screens/stats_screen.dart';
import 'package:prod/services/task_repository.dart';
import 'package:prod/state/task_controller.dart';
import 'package:prod/state/task_scope.dart';

Future<void> pumpStatsScreen(
  WidgetTester tester,
  TaskController controller,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    TaskScope(
      controller: controller,
      child: const MaterialApp(home: StatsScreen()),
    ),
  );
}

void main() {
  testWidgets('StatsScreen renders zeroed state gracefully for a brand-new player',
      (tester) async {
    final controller = TaskController(InMemoryTaskRepository());
    await pumpStatsScreen(tester, controller);

    // Progression
    expect(find.text('Character Progression'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 / 23 XP (0.0%)'), findsOneWidget);
    expect(find.text('23 XP needed to reach Level 2'), findsOneWidget);

    // Streaks
    expect(find.text('Streaks & Multipliers'), findsOneWidget);
    expect(find.text('×1.00'), findsOneWidget);

    // Completed Quests
    expect(find.text('Quests Completed'), findsOneWidget);

    // Experience
    expect(find.text('Experience Gained'), findsOneWidget);

    // Activity History
    expect(find.text('Activity History'), findsOneWidget);
    expect(
      find.text('Complete quests to forge your activity history!'),
      findsOneWidget,
    );
  });

  testWidgets('StatsScreen reflects updated task and XP counts after completing a task',
      (tester) async {
    final now = DateTime(2026, 9, 13, 10, 0);
    final controller = TaskController(
      InMemoryTaskRepository(clock: () => now),
      clock: () => now,
    );

    controller.createTask(title: 'Conquer Boss', xpReward: 50);
    final task = controller.activeTasks.first;
    controller.completeTask(task.id, completedAt: now);

    await pumpStatsScreen(tester, controller);

    // Level progress reflects 50 XP (advancing to Level 3)
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('0 / 31 XP (0.0%)'), findsOneWidget);
    expect(find.text('31 XP needed to reach Level 4'), findsOneWidget);

    // Streak shows 1 day
    expect(find.text('1'), findsWidgets);

    // Quests completed
    expect(find.byKey(const Key('stats-tasks-today')), findsOneWidget);
    expect(find.byKey(const Key('stats-tasks-week')), findsOneWidget);
    expect(find.byKey(const Key('stats-total-tasks')), findsOneWidget);

    // XP gained
    expect(find.byKey(const Key('stats-xp-today')), findsOneWidget);
    expect(find.byKey(const Key('stats-xp-week')), findsOneWidget);
    expect(find.byKey(const Key('stats-total-xp')), findsOneWidget);

    // Activity chart is rendered
    expect(find.byKey(const Key('stats-activity-chart')), findsOneWidget);
  });
}
