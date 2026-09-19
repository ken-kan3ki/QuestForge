import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prod/models/avatar_progression.dart';
import 'package:prod/models/avatar_tier.dart';
import 'package:prod/screens/character_screen.dart';
import 'package:prod/services/avatar_engine.dart';
import 'package:prod/services/level_engine.dart';
import 'package:prod/services/task_repository.dart';
import 'package:prod/services/xp_ledger.dart';
import 'package:prod/state/task_controller.dart';
import 'package:prod/state/task_scope.dart';
import 'package:prod/widgets/player_avatar.dart';

void main() {
  const engine = AvatarEngine();

  group('Avatar Progression Tier Boundaries (Section 13 & 24)', () {
    const boundaryCases = <int, (AvatarTier, String)>{
      1: (AvatarTier.yowaimo, 'Yowaimo'),
      4: (AvatarTier.yowaimo, 'Yowaimo'),
      5: (AvatarTier.karen, 'Karen'),
      11: (AvatarTier.karen, 'Karen'),
      12: (AvatarTier.skinny, 'Skinny'),
      20: (AvatarTier.skinny, 'Skinny'),
      21: (AvatarTier.npc, 'NPC'),
      32: (AvatarTier.npc, 'NPC'),
      33: (AvatarTier.sigma, 'Sigma'),
      47: (AvatarTier.sigma, 'Sigma'),
      48: (AvatarTier.alpha, 'Alpha'),
      65: (AvatarTier.alpha, 'Alpha'),
      66: (AvatarTier.gigachad, 'Gigachad'),
      82: (AvatarTier.gigachad, 'Gigachad'),
      83: (AvatarTier.superSaiyan, 'Super Saiyan'),
      99: (AvatarTier.superSaiyan, 'Super Saiyan'),
      100: (AvatarTier.superSaiyanGod, 'Super Saiyan God'),
    };

    boundaryCases.forEach((level, expected) {
      test('level $level maps to ${expected.$2} (${expected.$1.name})', () {
        final progression = engine.progressionFor(level: level);
        expect(progression.tier, expected.$1);
        expect(progression.title, expected.$2);
      });
    });
  });

  group('Avatar Evolution Progress (Section 14 & 24)', () {
    test('beginning and end of each tier have exact 0.0 and 1.0 progress', () {
      // Yowaimo 1-4
      expect(engine.progressionFor(level: 1).progress, 0.0);
      expect(engine.progressionFor(level: 4).progress, 1.0);

      // Karen 5-11
      expect(engine.progressionFor(level: 5).progress, 0.0);
      expect(engine.progressionFor(level: 11).progress, 1.0);

      // Skinny 12-20
      expect(engine.progressionFor(level: 12).progress, 0.0);
      expect(engine.progressionFor(level: 20).progress, 1.0);

      // NPC 21-32
      expect(engine.progressionFor(level: 21).progress, 0.0);
      expect(engine.progressionFor(level: 32).progress, 1.0);

      // Sigma 33-47
      expect(engine.progressionFor(level: 33).progress, 0.0);
      expect(engine.progressionFor(level: 47).progress, 1.0);

      // Alpha 48-65
      expect(engine.progressionFor(level: 48).progress, 0.0);
      expect(engine.progressionFor(level: 65).progress, 1.0);

      // Gigachad 66-82
      expect(engine.progressionFor(level: 66).progress, 0.0);
      expect(engine.progressionFor(level: 82).progress, 1.0);

      // Super Saiyan 83-99
      expect(engine.progressionFor(level: 83).progress, 0.0);
      expect(engine.progressionFor(level: 99).progress, 1.0);

      // Super Saiyan God 100
      expect(engine.progressionFor(level: 100).progress, 1.0);
    });

    test('progress is always between 0.0 and 1.0 across all levels', () {
      for (var lvl = -5; lvl <= 120; lvl++) {
        final p = engine.progressionFor(level: lvl);
        expect(p.progress, greaterThanOrEqualTo(0.0));
        expect(p.progress, lessThanOrEqualTo(1.0));
        expect(p.progress.isNaN, isFalse);
        expect(p.progress.isInfinite, isFalse);
      }
    });

    test('level clamp below 1 gives level 1 Yowaimo with 0.0 progress', () {
      final p0 = engine.progressionFor(level: 0);
      expect(p0.level, 1);
      expect(p0.title, 'Yowaimo');
      expect(p0.progress, 0.0);

      final pNeg = engine.progressionFor(level: -10);
      expect(pNeg.level, 1);
      expect(pNeg.title, 'Yowaimo');
      expect(pNeg.progress, 0.0);
    });
  });

  group('Avatar Progression UI Integration', () {
    testWidgets('PlayerAvatar renders level badge and icon without errors', (tester) async {
      final progression = AvatarProgression(
        tier: AvatarTier.yowaimo,
        title: 'Yowaimo',
        level: 3,
        minLevel: 1,
        maxLevel: 4,
        progress: 0.67,
        nextTier: AvatarTier.karen,
        nextTitle: 'Karen',
        definition: AvatarEngine.tiers[0],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatar(
              size: 96,
              level: 3,
              progression: progression,
            ),
          ),
        ),
      );

      expect(find.byType(PlayerAvatar), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('CharacterScreen displays avatar progression title, level, and evolution progress', (tester) async {
      final controller = TaskController(InMemoryTaskRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: TaskScope(
            controller: controller,
            child: const CharacterScreen(),
          ),
        ),
      );

      expect(find.text('Yowaimo'), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.byKey(const Key('avatar-evolution-percent')), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('CharacterScreen at Level 100 displays MAX LEVEL and Super Saiyan God without 101', (tester) async {
      final ledger = InMemoryXpLedger();
      ledger.award(
        sourceTaskId: 'max-task',
        baseXp: 82500,
        completionId: 'comp-max',
      );
      final controller = TaskController(
        InMemoryTaskRepository(),
        xpLedger: ledger,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TaskScope(
            controller: controller,
            child: const CharacterScreen(),
          ),
        ),
      );

      expect(find.text('Super Saiyan God'), findsOneWidget);
      expect(find.text('Level 100'), findsOneWidget);
      expect(find.text('MAX LEVEL'), findsOneWidget);
      expect(find.textContaining('101'), findsNothing);
    });
  });
}
