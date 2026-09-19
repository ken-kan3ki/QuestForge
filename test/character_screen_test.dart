import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prod/services/task_repository.dart';
import 'package:prod/state/task_controller.dart';
import 'package:prod/state/task_scope.dart';
import 'package:prod/screens/character_screen.dart';

/// Pumps a [CharacterScreen] inside a minimal app with a [TaskScope] wired
/// to the given [controller].
Future<void> pumpCharacterScreen(
  WidgetTester tester,
  TaskController controller,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TaskScope(
      controller: controller,
      child: const MaterialApp(home: CharacterScreen()),
    ),
  );
}

void main() {
  testWidgets('displays level 1 and 0 XP for a fresh player', (tester) async {
    final controller = TaskController(InMemoryTaskRepository());
    await pumpCharacterScreen(tester, controller);

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 XP earned'), findsOneWidget);
    expect(find.text('23 XP to level 2'), findsOneWidget);
    expect(find.text('0 / 23 XP'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
  });

  testWidgets('displays streak info for a fresh player', (tester) async {
    final controller = TaskController(InMemoryTaskRepository());
    await pumpCharacterScreen(tester, controller);

    expect(find.text('0'), findsOneWidget); // streak length
    expect(find.text('days'), findsOneWidget);
    expect(find.text('×1.00'), findsOneWidget); // multiplier
  });

  testWidgets('reacts to XP changes after completing a task', (tester) async {
    final now = DateTime(2026, 9, 12, 10, 0);
    final controller = TaskController(
      InMemoryTaskRepository(),
      clock: () => now,
    );

    // 25 XP task: 23 XP to reach level 2, leaves 2 XP into level 2 (span 27)
    controller.createTask(title: 'Read a book', xpReward: 25);
    final task = controller.activeTasks.first;
    controller.completeTask(task.id, completedAt: now);

    await pumpCharacterScreen(tester, controller);

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('25 XP earned'), findsOneWidget);
    expect(find.text('2 / 27 XP'), findsOneWidget);
    expect(find.text('25 XP to level 3'), findsOneWidget);
  });

  testWidgets('reaches level 2 after earning 23+ XP', (tester) async {
    final now = DateTime(2026, 9, 12, 10, 0);
    final controller = TaskController(
      InMemoryTaskRepository(),
      clock: () => now,
    );

    controller.createTask(title: 'Task A', xpReward: 25);
    final taskA = controller.activeTasks.first;
    controller.completeTask(taskA.id, completedAt: now);

    await pumpCharacterScreen(tester, controller);

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('25 XP earned'), findsOneWidget);
  });

  testWidgets('streak badge shows singular "day" for streak of 1',
      (tester) async {
    final now = DateTime(2026, 9, 12, 10, 0);
    final controller = TaskController(
      InMemoryTaskRepository(),
      clock: () => now,
    );

    controller.createTask(title: 'Task', xpReward: 25);
    controller.completeTask(
      controller.activeTasks.first.id,
      completedAt: now,
    );

    await pumpCharacterScreen(tester, controller);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('day'), findsOneWidget);
  });

  testWidgets('player avatar renders with correct level badge',
      (tester) async {
    final controller = TaskController(InMemoryTaskRepository());
    await pumpCharacterScreen(tester, controller);

    // The avatar shows "Lv 1" badge
    expect(find.text('Lv 1'), findsOneWidget);
  });
}
