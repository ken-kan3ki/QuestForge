import 'package:flutter_test/flutter_test.dart';
import 'package:prod/core/constants/game_constants.dart';
import 'package:prod/services/xp_engine.dart';

void main() {
  const engine = XpEngine();

  group('Quest XP defaults & custom range (Section 4, 5, 10)', () {
    test('standard quest defaults match specification', () {
      expect(GameConstants.xpSmall, 25);
      expect(GameConstants.xpNormal, 50);
      expect(GameConstants.xpLarge, 100);
      expect(GameConstants.xpMajor, 150);
    });

    test('custom range matches specification', () {
      expect(GameConstants.minCustomXp, 25);
      expect(GameConstants.maxCustomXp, 500);
    });
  });

  group('Base XP + Streak Multiplier (Section 6, 10)', () {
    test('exact multiplier calculations from specification', () {
      // 50 × 1.00 = 50
      final d1 = engine.decide(
        baseXp: 50,
        alreadyAwardedForCompletion: false,
        multiplier: 1.00,
      );
      expect(d1.baseXp, 50);
      expect(d1.awardedXp, 50);

      // 50 × 1.05 = 52.5 -> round = 53
      final d2 = engine.decide(
        baseXp: 50,
        alreadyAwardedForCompletion: false,
        multiplier: 1.05,
      );
      expect(d2.baseXp, 50);
      expect(d2.awardedXp, 53);

      // 50 × 1.10 = 55
      final d3 = engine.decide(
        baseXp: 50,
        alreadyAwardedForCompletion: false,
        multiplier: 1.10,
      );
      expect(d3.baseXp, 50);
      expect(d3.awardedXp, 55);

      // 100 × 1.25 = 125
      final d4 = engine.decide(
        baseXp: 100,
        alreadyAwardedForCompletion: false,
        multiplier: 1.25,
      );
      expect(d4.baseXp, 100);
      expect(d4.awardedXp, 125);

      // 150 × 1.30 = 195
      final d5 = engine.decide(
        baseXp: 150,
        alreadyAwardedForCompletion: false,
        multiplier: 1.30,
      );
      expect(d5.baseXp, 150);
      expect(d5.awardedXp, 195);

      // 500 × 1.35 = 675
      final d6 = engine.decide(
        baseXp: 500,
        alreadyAwardedForCompletion: false,
        multiplier: 1.35,
      );
      expect(d6.baseXp, 500);
      expect(d6.awardedXp, 675);
    });

    test('base XP remains unchanged and rounding occurs once', () {
      final decision = engine.decide(
        baseXp: 50,
        alreadyAwardedForCompletion: false,
        multiplier: 1.05,
      );
      expect(decision.baseXp, 50);
      expect(decision.awardedXp, 53);
    });
  });

  group('Safety & duplicate protection', () {
    test('rejects zero and negative XP', () {
      expect(
        engine.decide(baseXp: 0, alreadyAwardedForCompletion: false),
        const XpDecision.invalidXp(baseXp: 0),
      );
      expect(
        engine.decide(baseXp: -10, alreadyAwardedForCompletion: false),
        const XpDecision.invalidXp(baseXp: -10),
      );
    });

    test('rejects duplicate completion', () {
      final first = engine.decide(
        baseXp: 50,
        alreadyAwardedForCompletion: false,
        multiplier: 1.10,
      );
      final second = engine.decide(
        baseXp: 50,
        alreadyAwardedForCompletion: true,
        multiplier: 1.10,
      );

      expect(first.isAwarded, isTrue);
      expect(first.awardedXp, 55);
      expect(second.status, XpAwardStatus.duplicate);
      expect(second.awardedXp, 0);
    });
  });
}
