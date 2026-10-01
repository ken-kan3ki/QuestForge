import 'package:flutter/material.dart';

import '../models/avatar_progression.dart';
import '../models/avatar_tier.dart';
import 'level_engine.dart';

/// Pure, deterministic engine responsible for mapping player levels to
/// avatar evolution tiers and calculating intra-tier progression.
///
/// Holds all tier thresholds and title definitions in a centralized, easily
/// modifiable registry matching the exact 100-level specification.
class AvatarEngine {
  const AvatarEngine({
    this.levelEngine = const LevelEngine(),
  });

  /// The level progression engine used to resolve level and XP boundaries.
  final LevelEngine levelEngine;

  /// Centralized source of truth for all avatar tiers, their level boundaries,
  /// display titles, and visual characteristics.
  static const List<AvatarTierDefinition> tiers = [
    AvatarTierDefinition(
      tier: AvatarTier.yowaimo,
      title: 'Yowaimo',
      minLevel: 1,
      maxLevel: 4,
      auraThreshold: 0,
      icon: Icons.spa_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFF4A5568), Color(0xFF2D3748)],
      borderWidth: 2.0,
      hasGlow: false,
      imagePath: 'assets/avatars/yowaimo.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.karen,
      title: 'Karen',
      minLevel: 5,
      maxLevel: 11,
      auraThreshold: 181,
      icon: Icons.campaign_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFFE53E3E), Color(0xFF9B2C2C)],
      borderWidth: 2.0,
      hasGlow: false,
      imagePath: 'assets/avatars/karen.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.skinny,
      title: 'Skinny',
      minLevel: 12,
      maxLevel: 20,
      auraThreshold: 596,
      icon: Icons.directions_run,
      badgeSymbol: '',
      gradientColors: [Color(0xFFDD6B20), Color(0xFFC05621)],
      borderWidth: 2.5,
      hasGlow: false,
      imagePath: 'assets/avatars/skinny.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.npc,
      title: 'NPC',
      minLevel: 21,
      maxLevel: 32,
      auraThreshold: 1361,
      icon: Icons.smart_toy_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFF718096), Color(0xFF4A5568)],
      borderWidth: 2.5,
      hasGlow: false,
      imagePath: 'assets/avatars/npc.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.sigma,
      title: 'Sigma',
      minLevel: 33,
      maxLevel: 47,
      auraThreshold: 2904,
      icon: Icons.visibility,
      badgeSymbol: '',
      gradientColors: [Color(0xFF2B6CB0), Color(0xFF1A365D)],
      borderWidth: 3.0,
      hasGlow: true,
      imagePath: 'assets/avatars/sigma.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.alpha,
      title: 'Alpha',
      minLevel: 48,
      maxLevel: 65,
      auraThreshold: 5916,
      icon: Icons.workspace_premium,
      badgeSymbol: '',
      gradientColors: [Color(0xFFC53030), Color(0xFF742A2A)],
      borderWidth: 3.5,
      hasGlow: true,
      imagePath: 'assets/avatars/alpha.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.gigachad,
      title: 'Gigachad',
      minLevel: 66,
      maxLevel: 82,
      auraThreshold: 11565,
      icon: Icons.diamond_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFFD69E2E), Color(0xFF744210)],
      borderWidth: 3.5,
      hasGlow: true,
      imagePath: 'assets/avatars/gigachad.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.superSaiyan,
      title: 'Super Saiyan',
      minLevel: 83,
      maxLevel: 99,
      auraThreshold: 19434,
      icon: Icons.flare,
      badgeSymbol: '',
      gradientColors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
      borderWidth: 4.0,
      hasGlow: true,
      imagePath: 'assets/avatars/super_saiyan.jpg',
    ),
    AvatarTierDefinition(
      tier: AvatarTier.superSaiyanGod,
      title: 'Super Saiyan God',
      minLevel: 100,
      maxLevel: 100,
      auraThreshold: 30265,
      icon: Icons.auto_awesome,
      badgeSymbol: '',
      gradientColors: [Color(0xFFFF0055), Color(0xFFFF4500)],
      borderWidth: 5.0,
      hasGlow: true,
      imagePath: 'assets/avatars/super_saiyan_god.jpg',
    ),
  ];

  /// Resolves the tier definition corresponding to [tier].
  AvatarTierDefinition definitionForTier(AvatarTier tier) {
    return tiers.firstWhere(
      (def) => def.tier == tier,
      orElse: () => tiers.first,
    );
  }

  /// Computes the complete [AvatarProgression] for a player.
  ///
  /// Source of truth is total Aura earned from completing tasks.
  /// Evolution tier is determined by total Aura matching or exceeding tier thresholds.
  /// Evolution progress within non-final tiers is calculated from Aura earned since
  /// the previous evolution threshold:
  /// `(totalAura - previousThreshold) / (currentThreshold - previousThreshold)`.
  /// At maximum progression (Super Saiyan God / Level 100), progress is exactly 100% (1.0).
  AvatarProgression progressionFor({
    int? totalAura,
    int? totalXp,
    int? level,
    LevelEngine? levelEngine,
  }) {
    final le = levelEngine ?? this.levelEngine;

    final int effectiveAura;
    if (totalAura != null) {
      effectiveAura = totalAura;
    } else if (totalXp != null) {
      effectiveAura = totalXp;
    } else if (level != null) {
      effectiveAura = le.totalXpRequiredForLevel(level);
    } else {
      effectiveAura = 0;
    }

    final safeAura = effectiveAura < 0 ? 0 : effectiveAura;

    // Find the matching tier index based on total Aura
    var matchIndex = 0;
    for (var i = tiers.length - 1; i >= 0; i--) {
      if (safeAura >= tiers[i].auraThreshold) {
        matchIndex = i;
        break;
      }
    }

    final currentDef = tiers[matchIndex];
    final hasNext = matchIndex < tiers.length - 1;
    final nextDef = hasNext ? tiers[matchIndex + 1] : null;

    final double progress;
    final int? currentTierAura;
    final int? tierAuraRequired;

    if (!hasNext) {
      // Final evolution tier (Super Saiyan God)
      progress = 1.0;
      currentTierAura = null;
      tierAuraRequired = null;
    } else {
      final previousThreshold = currentDef.auraThreshold;
      final currentThreshold = nextDef!.auraThreshold;
      final span = currentThreshold - previousThreshold;
      final intoTier = safeAura - previousThreshold;

      tierAuraRequired = span;
      currentTierAura = intoTier.clamp(0, span);
      progress = span > 0 ? (currentTierAura / span).clamp(0.0, 1.0) : 1.0;
    }

    final int safeLevel = level ?? le.levelFromTotalXp(safeAura);

    return AvatarProgression(
      tier: currentDef.tier,
      title: currentDef.title,
      level: safeLevel,
      minLevel: currentDef.minLevel,
      maxLevel: currentDef.maxLevel,
      progress: progress,
      nextTier: nextDef?.tier,
      nextTitle: nextDef?.title,
      definition: currentDef,
      currentTierXp: currentTierAura,
      tierTotalXp: tierAuraRequired,
    );
  }

  /// Convenience method to compute [AvatarProgression] from [totalAura].
  AvatarProgression progressionForAura(int totalAura, {LevelEngine? levelEngine}) {
    return progressionFor(totalAura: totalAura, levelEngine: levelEngine);
  }

  /// Convenience method to compute [AvatarProgression] when only [level] is available.
  AvatarProgression progressionForLevel(int level, {LevelEngine? levelEngine}) {
    return progressionFor(level: level, levelEngine: levelEngine);
  }
}
