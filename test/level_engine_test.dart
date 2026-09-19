import 'package:flutter_test/flutter_test.dart';
import 'package:prod/services/level_engine.dart';

void main() {
  const engine = LevelEngine();

  group('Exact XP formula implementation', () {
    test('requiredXpForLevel formula matches round(40 + 2 * L + 0.05 * L^2)', () {
      for (var l = 1; l <= 99; l++) {
        final expected = (40 + 2 * l + 0.05 * l * l).round();
        expect(
          engine.requiredXpForLevel(l),
          expected,
          reason: 'L=$l should match formula',
        );
      }
    });

    test('exact formula values from specification checkpoints (Section 32)', () {
      expect(engine.requiredXpForLevel(1), 42);
      expect(engine.requiredXpForLevel(2), 44);
      expect(engine.requiredXpForLevel(5), 51);
      expect(engine.requiredXpForLevel(10), 65);
      expect(engine.requiredXpForLevel(20), 100);
      expect(engine.requiredXpForLevel(30), 145);
      expect(engine.requiredXpForLevel(40), 200);
      expect(engine.requiredXpForLevel(50), 265);
      expect(engine.requiredXpForLevel(60), 340);
      expect(engine.requiredXpForLevel(70), 425);
      expect(engine.requiredXpForLevel(80), 520);
      expect(engine.requiredXpForLevel(90), 625);
      expect(engine.requiredXpForLevel(95), 681);
      expect(engine.requiredXpForLevel(99), 728);
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

  group('Progression scale & cumulative XP (Section 6)', () {
    test('Level 1 starts at 0 cumulative XP', () {
      expect(engine.totalXpRequiredForLevel(1), 0);
    });

    test('Actual cumulative XP to reach Level 100 is 30,265 XP (within 28k-32k range)', () {
      final total = engine.totalXpRequiredForLevel(100);
      expect(total, 30265);
      expect(total, greaterThanOrEqualTo(28000));
      expect(total, lessThanOrEqualTo(32000));
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

  group('Level boundaries and resolution (Section 2, 17, 27)', () {
    test('Level 1 at 0 XP', () {
      final p = engine.progressFor(0);
      expect(p.level, 1);
      expect(p.totalXp, 0);
      expect(p.xpForCurrentLevel, 0);
      expect(p.xpForNextLevel, 42);
      expect(p.xpIntoCurrentLevel, 0);
      expect(p.progressToNextLevel, 0.0);
      expect(p.xpToNextLevel, 42);
      expect(engine.levelFromTotalXp(0), 1);
      expect(engine.progressPercentage(0), 0.0);
    });

    test('XP immediately before boundary lands on lower level with high progress', () {
      // Level 1 -> 2 threshold is 42 XP
      final p41 = engine.progressFor(41);
      expect(p41.level, 1);
      expect(p41.xpIntoCurrentLevel, 41);
      expect(p41.xpToNextLevel, 1);
      expect(p41.progressToNextLevel, closeTo(41 / 42, 1e-9));

      // Level 2 -> 3 threshold is 42 + 44 = 86 XP
      final p85 = engine.progressFor(85);
      expect(p85.level, 2);
      expect(p85.xpIntoCurrentLevel, 43);
      expect(p85.xpToNextLevel, 1);
    });

    test('XP exactly at boundary lands on new level with 0.0 progress', () {
      final p42 = engine.progressFor(42);
      expect(p42.level, 2);
      expect(p42.xpIntoCurrentLevel, 0);
      expect(p42.progressToNextLevel, 0.0);

      final p86 = engine.progressFor(86);
      expect(p86.level, 3);
      expect(p86.xpIntoCurrentLevel, 0);
      expect(p86.progressToNextLevel, 0.0);
    });

    test('XP immediately after boundary lands on new level with positive progress', () {
      final p43 = engine.progressFor(43);
      expect(p43.level, 2);
      expect(p43.xpIntoCurrentLevel, 1);
      expect(p43.progressToNextLevel, closeTo(1 / 44, 1e-9));
    });

    test('Level 100 cap and overflow handling', () {
      // Exactly at Level 100 (30,265 XP)
      final p100 = engine.progressFor(30265);
      expect(p100.level, 100);
      expect(p100.progressToNextLevel, 1.0);
      expect(p100.xpToNextLevel, 0);
      expect(engine.levelFromTotalXp(30265), 100);
      expect(engine.progressPercentage(30265), 1.0);

      // Beyond Level 100 (e.g. 50,000 XP, 100,000 XP)
      final pExtra = engine.progressFor(50000);
      expect(pExtra.level, 100);
      expect(pExtra.totalXp, 50000);
      expect(pExtra.progressToNextLevel, 1.0);
      expect(pExtra.xpToNextLevel, 0);
      expect(engine.levelFromTotalXp(50000), 100);
      expect(engine.progressPercentage(50000), 1.0);
    });

    test('Never returns level 101', () {
      for (final xp in [30265, 30266, 35000, 50000, 100000, 99999999]) {
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
      for (var xp = -1000; xp <= 50000; xp += 100) {
        final pct = engine.progressPercentage(xp);
        expect(pct, greaterThanOrEqualTo(0.0));
        expect(pct, lessThanOrEqualTo(1.0));
        expect(pct.isNaN, isFalse);
        expect(pct.isInfinite, isFalse);
      }
    });
  });

  group('Consistency across Level Progression Functions (Section 2, 17, 27)', () {
    test('levelFromTotalXp, xpIntoCurrentLevel, xpRequiredForNextLevel, progressPercentage describe the exact same state', () {
      final testXpValues = [0, 10, 21, 41, 42, 43, 85, 86, 100, 500, 1000, 5000, 15000, 30265, 50000];

      for (final xp in testXpValues) {
        final lvl = engine.levelFromTotalXp(xp);
        final into = engine.xpIntoCurrentLevel(xp);
        final req = engine.xpRequiredForNextLevel(xp);
        final pct = engine.progressPercentage(xp);

        expect(lvl, greaterThanOrEqualTo(1));
        expect(lvl, lessThanOrEqualTo(100));

        if (lvl == 100) {
          expect(pct, 1.0);
          expect(req, 0);
        } else {
          expect(req, engine.requiredXpForLevel(lvl));
          expect(into, greaterThanOrEqualTo(0));
          expect(into, lessThan(req));
          expect(pct, closeTo(into / req, 1e-9));
        }
      }
    });
  });
}
