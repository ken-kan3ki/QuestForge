import 'package:flutter_test/flutter_test.dart';
import 'package:prod/services/level_engine.dart';

void main() {
  const engine = LevelEngine();

  group('Exact XP formula implementation', () {
    test('requiredXpForLevel formula matches round(20 + 3 * L + 0.20 * L^2)', () {
      for (var l = 1; l <= 99; l++) {
        final expected = (20 + 3 * l + 0.20 * l * l).round();
        expect(
          engine.requiredXpForLevel(l),
          expected,
          reason: 'L=$l should match formula',
        );
      }
    });

    test('exact formula values from prompt specification', () {
      expect(engine.requiredXpForLevel(1), 23);
      expect(engine.requiredXpForLevel(2), 27);
      expect(engine.requiredXpForLevel(3), 31);
      expect(engine.requiredXpForLevel(4), 35);
      expect(engine.requiredXpForLevel(5), 40);

      expect(engine.requiredXpForLevel(10), 70);
      expect(engine.requiredXpForLevel(20), 160);
      expect(engine.requiredXpForLevel(30), 290);
      expect(engine.requiredXpForLevel(40), 460);
      expect(engine.requiredXpForLevel(50), 670);
      expect(engine.requiredXpForLevel(60), 920);
      expect(engine.requiredXpForLevel(70), 1210);
      expect(engine.requiredXpForLevel(80), 1540);
      expect(engine.requiredXpForLevel(90), 1910);
      expect(engine.requiredXpForLevel(99), 2277);
    });

    test('monotonic increase of XP requirements across levels 1..99', () {
      for (var l = 1; l < 99; l++) {
        expect(
          engine.requiredXpForLevel(l + 1),
          greaterThan(engine.requiredXpForLevel(l)),
          reason: 'Level ${l + 1} requirement must exceed Level $l',
        );
      }
    });
  });

  group('Progression scale & cumulative XP', () {
    test('Level 1 starts at 0 cumulative XP', () {
      expect(engine.totalXpRequiredForLevel(1), 0);
    });

    test('Actual cumulative XP to reach Level 100 is exactly 82,500 XP', () {
      expect(engine.totalXpRequiredForLevel(100), 82500);
    });

    test('Cumulative XP matches sum of requiredXpForLevel(L) for L=1..N-1', () {
      for (var n = 1; n <= 100; n++) {
        var sum = 0;
        for (var l = 1; l < n; l++) {
          sum += engine.requiredXpForLevel(l);
        }
        expect(engine.totalXpRequiredForLevel(n), sum);
      }
    });
  });

  group('Level boundaries and resolution', () {
    test('Level 1 at 0 XP', () {
      final p = engine.progressFor(0);
      expect(p.level, 1);
      expect(p.totalXp, 0);
      expect(p.xpForCurrentLevel, 0);
      expect(p.xpForNextLevel, 23);
      expect(p.xpIntoCurrentLevel, 0);
      expect(p.progressToNextLevel, 0.0);
      expect(p.xpToNextLevel, 23);
      expect(engine.levelFromTotalXp(0), 1);
      expect(engine.progressPercentage(0), 0.0);
    });

    test('XP immediately before boundary lands on lower level with high progress', () {
      // Level 1 -> 2 threshold is 23 XP
      final p22 = engine.progressFor(22);
      expect(p22.level, 1);
      expect(p22.xpIntoCurrentLevel, 22);
      expect(p22.xpToNextLevel, 1);
      expect(p22.progressToNextLevel, closeTo(22 / 23, 1e-9));

      // Level 2 -> 3 threshold is 23 + 27 = 50 XP
      final p49 = engine.progressFor(49);
      expect(p49.level, 2);
      expect(p49.xpIntoCurrentLevel, 26);
      expect(p49.xpToNextLevel, 1);
    });

    test('XP exactly at boundary lands on new level with 0.0 progress', () {
      final p23 = engine.progressFor(23);
      expect(p23.level, 2);
      expect(p23.xpIntoCurrentLevel, 0);
      expect(p23.progressToNextLevel, 0.0);

      final p50 = engine.progressFor(50);
      expect(p50.level, 3);
      expect(p50.xpIntoCurrentLevel, 0);
      expect(p50.progressToNextLevel, 0.0);
    });

    test('XP immediately after boundary lands on new level with positive progress', () {
      final p24 = engine.progressFor(24);
      expect(p24.level, 2);
      expect(p24.xpIntoCurrentLevel, 1);
      expect(p24.progressToNextLevel, closeTo(1 / 27, 1e-9));
    });

    test('Level 100 cap and overflow handling', () {
      // Exactly at Level 100 (82,500 XP)
      final p100 = engine.progressFor(82500);
      expect(p100.level, 100);
      expect(p100.progressToNextLevel, 1.0);
      expect(p100.xpToNextLevel, 0);
      expect(engine.levelFromTotalXp(82500), 100);
      expect(engine.progressPercentage(82500), 1.0);

      // Beyond Level 100 (e.g. 100,000 XP, 1,000,000 XP)
      final pExtra = engine.progressFor(100000);
      expect(pExtra.level, 100);
      expect(pExtra.totalXp, 100000);
      expect(pExtra.progressToNextLevel, 1.0);
      expect(pExtra.xpToNextLevel, 0);
      expect(engine.levelFromTotalXp(100000), 100);
      expect(engine.progressPercentage(100000), 1.0);

      final pMega = engine.progressFor(10000000);
      expect(pMega.level, 100);
      expect(pMega.progressToNextLevel, 1.0);
      expect(engine.levelFromTotalXp(10000000), 100);
    });

    test('Never returns level 101', () {
      for (final xp in [82500, 82501, 85000, 100000, 500000, 1000000, 99999999]) {
        expect(engine.levelFromTotalXp(xp), 100);
        expect(engine.progressFor(xp).level, 100);
      }
    });

    test('Negative XP clamp defensively to 0 / Level 1', () {
      final pNeg = engine.progressFor(-100);
      expect(pNeg.level, 1);
      expect(pNeg.totalXp, 0);
      expect(pNeg.progressToNextLevel, 0.0);
      expect(engine.levelFromTotalXp(-100), 1);
      expect(engine.progressPercentage(-100), 0.0);
    });

    test('Progress percentage is always clamped in [0.0, 1.0]', () {
      for (var xp = -1000; xp <= 100000; xp += 250) {
        final pct = engine.progressPercentage(xp);
        expect(pct, greaterThanOrEqualTo(0.0));
        expect(pct, lessThanOrEqualTo(1.0));
        expect(pct.isNaN, isFalse);
        expect(pct.isInfinite, isFalse);
      }
    });
  });

  group('Named progression functions (Section 7)', () {
    test('requiredXpForLevel, totalXpRequiredForLevel, xpIntoCurrentLevel, xpRequiredForNextLevel, levelFromTotalXp, progressPercentage', () {
      expect(engine.requiredXpForLevel(1), 23);
      expect(engine.totalXpRequiredForLevel(1), 0);
      expect(engine.totalXpRequiredForLevel(2), 23);
      expect(engine.xpIntoCurrentLevel(20), 20);
      expect(engine.xpIntoCurrentLevel(25), 2); // 25 - 23
      expect(engine.xpRequiredForNextLevel(1), 23);
      expect(engine.xpRequiredForNextLevel(100), 0);
      expect(engine.levelFromTotalXp(23), 2);
      expect(engine.progressPercentage(0), 0.0);
      expect(engine.progressPercentage(82500), 1.0);
    });
  });
}
