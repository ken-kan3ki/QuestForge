import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prod/models/quest_difficulty.dart';
import 'package:prod/models/task.dart';
import 'package:prod/screens/task_editor_screen.dart';

void main() {
  group('QuestDifficulty Model & Defaults (Sections 8, 10, 14)', () {
    test('difficulty names and default values match specification', () {
      expect(QuestDifficulty.light.label, 'Light');
      expect(QuestDifficulty.light.defaultXp, 5);

      expect(QuestDifficulty.standard.label, 'Standard');
      expect(QuestDifficulty.standard.defaultXp, 10);

      expect(QuestDifficulty.challenging.label, 'Challenging');
      expect(QuestDifficulty.challenging.defaultXp, 20);

      expect(QuestDifficulty.custom.label, 'Custom');
      expect(QuestDifficulty.custom.defaultXp, isNull);
    });

    test('fromXp maps presets to appropriate difficulty and non-presets to custom', () {
      expect(QuestDifficulty.fromXp(5), QuestDifficulty.light);
      expect(QuestDifficulty.fromXp(10), QuestDifficulty.standard);
      expect(QuestDifficulty.fromXp(20), QuestDifficulty.challenging);

      // Custom values
      expect(QuestDifficulty.fromXp(25), QuestDifficulty.custom);
      expect(QuestDifficulty.fromXp(50), QuestDifficulty.custom);
      expect(QuestDifficulty.fromXp(100), QuestDifficulty.custom);
      expect(QuestDifficulty.fromXp(37), QuestDifficulty.custom);
    });
  });

  group('TaskEditorScreen Difficulty Selector UI (Sections 9, 11, 12, 13, 22, 23, 28)', () {
    testWidgets('new quest defaults to Standard with 10 XP disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaskEditorScreen(),
        ),
      );

      expect(find.byKey(const Key('difficulty-selector')), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Challenging'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      final xpField = tester.widget<TextFormField>(find.byKey(const Key('task-xp-field')));
      expect(xpField.enabled, isFalse);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('tapping Light switches XP to 5 and remains disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaskEditorScreen(),
        ),
      );

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      final xpField = tester.widget<TextFormField>(find.byKey(const Key('task-xp-field')));
      expect(xpField.enabled, isFalse);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('tapping Challenging switches XP to 20 and remains disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaskEditorScreen(),
        ),
      );

      await tester.tap(find.text('Challenging'));
      await tester.pumpAndSettle();

      final xpField = tester.widget<TextFormField>(find.byKey(const Key('task-xp-field')));
      expect(xpField.enabled, isFalse);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('tapping Custom enables the XP field and allows input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaskEditorScreen(),
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      final xpField = tester.widget<TextFormField>(find.byKey(const Key('task-xp-field')));
      expect(xpField.enabled, isTrue);

      await tester.enterText(find.byKey(const Key('task-xp-field')), '37');
      await tester.pumpAndSettle();
      expect(find.text('37'), findsOneWidget);
    });

    testWidgets('switching from Custom back to Standard sets XP to 10 and disables it', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaskEditorScreen(),
        ),
      );

      // Select custom and enter 37
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('task-xp-field')), '37');
      await tester.pumpAndSettle();

      // Switch back to Standard
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();

      final xpField = tester.widget<TextFormField>(find.byKey(const Key('task-xp-field')));
      expect(xpField.enabled, isFalse);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('editing an existing quest preserves stored XP and selects right difficulty', (tester) async {
      // Legacy 100 XP quest
      final task100 = Task(
        id: 'legacy-1',
        title: 'Old Task',
        xpReward: 100,
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TaskEditorScreen(task: task100),
        ),
      );

      // Loads as Custom with 100 XP intact
      expect(find.text('100'), findsOneWidget);
      final xpField = tester.widget<TextFormField>(find.byKey(const Key('task-xp-field')));
      expect(xpField.enabled, isTrue);
    });
  });
}
