import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prod/app.dart';
import 'package:prod/services/persistence_service.dart';
import 'package:prod/services/task_repository.dart';
import 'package:prod/services/xp_ledger.dart';

ProRpgApp testApp() {
  return ProRpgApp(
    taskRepository: InMemoryTaskRepository(),
    xpLedger: InMemoryXpLedger(),
    persistenceService: InMemoryPersistenceService(),
  );
}

void main() {
  testWidgets('shows home and can open other destinations', (tester) async {
    await tester.pumpWidget(testApp());

    expect(find.text('QuestForge'), findsOneWidget);
    expect(find.text('No active quests'), findsOneWidget);

    await tester.tap(find.text('Character'));
    await tester.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Character Progression'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('creates, completes, edits, and deletes a task', (tester) async {
    await tester.pumpWidget(testApp());

    await tester.tap(find.text('New Quest'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a task title.'), findsOneWidget);
    expect(find.text('Enter a whole number for the XP reward.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('task-title-field')), 'Gym');
    await tester.enterText(
      find.byKey(const Key('task-description-field')),
      'Leg day',
    );
    await tester.enterText(find.byKey(const Key('task-xp-field')), '50');
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();

    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Leg day'), findsOneWidget);
    expect(find.text('50 XP'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark complete'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsWidgets);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Gym session',
    );
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    expect(find.text('Gym session'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No active quests'), findsOneWidget);
  });
}
