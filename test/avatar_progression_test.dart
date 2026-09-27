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
  const levelEngine = LevelEngine();

  group('Avatar Evolution Tier Boundaries (Total Aura as Source of Truth)', () {
    // Exact calculated Aura thresholds from the implemented level progression curve:
    // Tier 1 — Yowaimo: 0 Aura (minLevel 1)
    // Tier 2 — Karen: 181 Aura (minLevel 5)
    // Tier 3 — Skinny: 596 Aura (minLevel 12)
    // Tier 4 — NPC: 1361 Aura (minLevel 21)
    // Tier 5 — Sigma: 2904 Aura (minLevel 33)
    // Tier 6 — Alpha: 5916 Aura (minLevel 48)
    // Tier 7 — Gigachad: 11565 Aura (minLevel 66)
    // Tier 8 — Super Saiyan: 19434 Aura (minLevel 83)
    // Tier 9 — Super Saiyan God: 30265 Aura (minLevel 100)
    const tierThresholds = <int, (AvatarTier, String)>{
      0: (AvatarTier.yowaimo, 'Yowaimo'),
      181: (AvatarTier.karen, 'Karen'),
      596: (AvatarTier.skinny, 'Skinny'),
      1361: (AvatarTier.npc, 'NPC'),
      2904: (AvatarTier.sigma, 'Sigma'),
      5916: (AvatarTier.alpha, 'Alpha'),
      11565: (AvatarTier.gigachad, 'Gigachad'),
      19434: (AvatarTier.superSaiyan, 'Super Saiyan'),
      30265: (AvatarTier.superSaiyanGod, 'Super Saiyan God'),
    };

    tierThresholds.forEach((threshold, expected) {
      test('totalAura $threshold maps to ${expected.$2} (${expected.$1.name})', () {
        final progression = engine.progressionFor(totalAura: threshold);
        expect(progression.tier, expected.$1);
        expect(progression.title, expected.$2);
      });
    });

    test('exact formula cumulative Aura to reach Level 100 is 30,265', () {
      expect(levelEngine.totalXpRequiredForLevel(100), 30265);
    });
  });

  group('Avatar Evolution Edge Cases', () {
    test('Aura below first threshold clamps to Tier 1 Yowaimo with 0.0 progress', () {
      final pNeg = engine.progressionFor(totalAura: -50);
      expect(pNeg.tier, AvatarTier.yowaimo);
      expect(pNeg.title, 'Yowaimo');
      expect(pNeg.progress, 0.0);
    });

    test('Aura exactly at each evolution threshold starts new tier with 0.0 progress (or 1.0 for max)', () {
      // Tier 1 (0) -> 0.0
      expect(engine.progressionFor(totalAura: 0).progress, 0.0);
      expect(engine.progressionFor(totalAura: 0).tier, AvatarTier.yowaimo);

      // Tier 2 (181) -> 0.0
      expect(engine.progressionFor(totalAura: 181).progress, 0.0);
      expect(engine.progressionFor(totalAura: 181).tier, AvatarTier.karen);

      // Tier 3 (596) -> 0.0
      expect(engine.progressionFor(totalAura: 596).progress, 0.0);
      expect(engine.progressionFor(totalAura: 596).tier, AvatarTier.skinny);

      // Tier 4 (1361) -> 0.0
      expect(engine.progressionFor(totalAura: 1361).progress, 0.0);
      expect(engine.progressionFor(totalAura: 1361).tier, AvatarTier.npc);

      // Tier 5 (2904) -> 0.0
      expect(engine.progressionFor(totalAura: 2904).progress, 0.0);
      expect(engine.progressionFor(totalAura: 2904).tier, AvatarTier.sigma);

      // Tier 6 (5916) -> 0.0
      expect(engine.progressionFor(totalAura: 5916).progress, 0.0);
      expect(engine.progressionFor(totalAura: 5916).tier, AvatarTier.alpha);

      // Tier 7 (11565) -> 0.0
      expect(engine.progressionFor(totalAura: 11565).progress, 0.0);
      expect(engine.progressionFor(totalAura: 11565).tier, AvatarTier.gigachad);

      // Tier 8 (19434) -> 0.0
      expect(engine.progressionFor(totalAura: 19434).progress, 0.0);
      expect(engine.progressionFor(totalAura: 19434).tier, AvatarTier.superSaiyan);

      // Tier 9 (30265) -> 1.0 (final evolution)
      expect(engine.progressionFor(totalAura: 30265).progress, 1.0);
      expect(engine.progressionFor(totalAura: 30265).tier, AvatarTier.superSaiyanGod);
    });

    test('Aura immediately below each threshold belongs to previous tier with high progress', () {
      // 180 is immediately below Karen threshold (181) -> Yowaimo
      final p180 = engine.progressionFor(totalAura: 180);
      expect(p180.tier, AvatarTier.yowaimo);
      expect(p180.progress, closeTo(180 / 181, 1e-9));

      // 595 is immediately below Skinny threshold (596) -> Karen
      final p595 = engine.progressionFor(totalAura: 595);
      expect(p595.tier, AvatarTier.karen);
      expect(p595.progress, closeTo((595 - 181) / (596 - 181), 1e-9));

      // 1360 is immediately below NPC threshold (1361) -> Skinny
      final p1360 = engine.progressionFor(totalAura: 1360);
      expect(p1360.tier, AvatarTier.skinny);
      expect(p1360.progress, closeTo((1360 - 596) / (1361 - 596), 1e-9));

      // 2903 is immediately below Sigma threshold (2904) -> NPC
      final p2903 = engine.progressionFor(totalAura: 2903);
      expect(p2903.tier, AvatarTier.npc);
      expect(p2903.progress, closeTo((2903 - 1361) / (2904 - 1361), 1e-9));

      // 5915 is immediately below Alpha threshold (5916) -> Sigma
      final p5915 = engine.progressionFor(totalAura: 5915);
      expect(p5915.tier, AvatarTier.sigma);
      expect(p5915.progress, closeTo((5915 - 2904) / (5916 - 2904), 1e-9));

      // 11564 is immediately below Gigachad threshold (11565) -> Alpha
      final p11564 = engine.progressionFor(totalAura: 11564);
      expect(p11564.tier, AvatarTier.alpha);
      expect(p11564.progress, closeTo((11564 - 5916) / (11565 - 5916), 1e-9));

      // 19433 is immediately below Super Saiyan threshold (19434) -> Gigachad
      final p19433 = engine.progressionFor(totalAura: 19433);
      expect(p19433.tier, AvatarTier.gigachad);
      expect(p19433.progress, closeTo((19433 - 11565) / (19434 - 11565), 1e-9));

      // 30264 is immediately below Super Saiyan God threshold (30265) -> Super Saiyan
      final p30264 = engine.progressionFor(totalAura: 30264);
      expect(p30264.tier, AvatarTier.superSaiyan);
      expect(p30264.progress, closeTo((30264 - 19434) / (30265 - 19434), 1e-9));
    });

    test('Aura immediately above each threshold belongs to new tier with positive progress', () {
      // 1 is immediately above Yowaimo start (0)
      final p1 = engine.progressionFor(totalAura: 1);
      expect(p1.tier, AvatarTier.yowaimo);
      expect(p1.progress, closeTo(1 / 181, 1e-9));

      // 182 is immediately above Karen threshold (181)
      final p182 = engine.progressionFor(totalAura: 182);
      expect(p182.tier, AvatarTier.karen);
      expect(p182.progress, closeTo(1 / (596 - 181), 1e-9));

      // 597 is immediately above Skinny threshold (596)
      final p597 = engine.progressionFor(totalAura: 597);
      expect(p597.tier, AvatarTier.skinny);
      expect(p597.progress, closeTo(1 / (1361 - 596), 1e-9));

      // 1362 is immediately above NPC threshold (1361)
      final p1362 = engine.progressionFor(totalAura: 1362);
      expect(p1362.tier, AvatarTier.npc);
      expect(p1362.progress, closeTo(1 / (2904 - 1361), 1e-9));

      // 2905 is immediately above Sigma threshold (2904)
      final p2905 = engine.progressionFor(totalAura: 2905);
      expect(p2905.tier, AvatarTier.sigma);
      expect(p2905.progress, closeTo(1 / (5916 - 2904), 1e-9));

      // 5917 is immediately above Alpha threshold (5916)
      final p5917 = engine.progressionFor(totalAura: 5917);
      expect(p5917.tier, AvatarTier.alpha);
      expect(p5917.progress, closeTo(1 / (11565 - 5916), 1e-9));

      // 11566 is immediately above Gigachad threshold (11565)
      final p11566 = engine.progressionFor(totalAura: 11566);
      expect(p11566.tier, AvatarTier.gigachad);
      expect(p11566.progress, closeTo(1 / (19434 - 11565), 1e-9));

      // 19435 is immediately above Super Saiyan threshold (19434)
      final p19435 = engine.progressionFor(totalAura: 19435);
      expect(p19435.tier, AvatarTier.superSaiyan);
      expect(p19435.progress, closeTo(1 / (30265 - 19434), 1e-9));

      // 30266 is beyond Super Saiyan God threshold (30265)
      final p30266 = engine.progressionFor(totalAura: 30266);
      expect(p30266.tier, AvatarTier.superSaiyanGod);
      expect(p30266.progress, 1.0);
    });

    test('current-tier Aura is calculated from the previous evolution threshold', () {
      // 300 Aura is in Karen tier (previousThreshold = 181, currentThreshold = 596)
      final p = engine.progressionFor(totalAura: 300);
      expect(p.tier, AvatarTier.karen);
      expect(p.currentTierXp, 300 - 181); // 119
      expect(p.tierTotalXp, 596 - 181); // 415
      expect(p.progress, closeTo(119 / 415, 1e-9));
    });

    test('current tier threshold is used as the target for progress calculation', () {
      final p = engine.progressionFor(totalAura: 181);
      expect(p.tier, AvatarTier.karen);
      expect(p.nextTier, AvatarTier.skinny);
      expect(p.nextTitle, 'Skinny');
      expect(p.tierTotalXp, 596 - 181);
    });

    test('evolution does not use task count', () {
      // Player with 100 Aura earned (regardless of task count) is Yowaimo
      final p1 = engine.progressionFor(totalAura: 100);
      expect(p1.tier, AvatarTier.yowaimo);

      // Player with 200 Aura earned (even from 1 big task) is Karen
      final p2 = engine.progressionFor(totalAura: 200);
      expect(p2.tier, AvatarTier.karen);
    });

    test('evolution does not directly use player level', () {
      // Even if level parameter is supplied, totalAura determines the tier
      final p = engine.progressionFor(totalAura: 596, level: 1);
      expect(p.tier, AvatarTier.skinny);
      expect(p.title, 'Skinny');
    });

    test('evolution progress never exceeds 100%', () {
      for (final aura in [30265, 30266, 35000, 50000, 100000, 9999999]) {
        final p = engine.progressionFor(totalAura: aura);
        expect(p.progress, lessThanOrEqualTo(1.0));
        expect(p.progress, 1.0);
      }
    });

    test('final evolution displays 100%', () {
      final pMax = engine.progressionFor(totalAura: 30265);
      expect(pMax.tier, AvatarTier.superSaiyanGod);
      expect(pMax.title, 'Super Saiyan God');
      expect(pMax.progress, 1.0);
      expect(pMax.nextTier, isNull);
      expect(pMax.nextTitle, isNull);
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
      expect(find.text('Lv 3'), findsOneWidget);
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
      final percentFinder = find.byKey(const Key('avatar-evolution-percent'));
      expect(percentFinder, findsOneWidget);
      expect(tester.widget<Text>(percentFinder).data, '0%');
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
