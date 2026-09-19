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
      icon: Icons.spa_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFF4A5568), Color(0xFF2D3748)],
      borderWidth: 2.0,
      hasGlow: false,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.karen,
      title: 'Karen',
      minLevel: 5,
      maxLevel: 11,
      icon: Icons.campaign_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFFE53E3E), Color(0xFF9B2C2C)],
      borderWidth: 2.0,
      hasGlow: false,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.skinny,
      title: 'Skinny',
      minLevel: 12,
      maxLevel: 20,
      icon: Icons.directions_run,
      badgeSymbol: '',
      gradientColors: [Color(0xFFDD6B20), Color(0xFFC05621)],
      borderWidth: 2.5,
      hasGlow: false,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.npc,
      title: 'NPC',
      minLevel: 21,
      maxLevel: 32,
      icon: Icons.smart_toy_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFF718096), Color(0xFF4A5568)],
      borderWidth: 2.5,
      hasGlow: false,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.sigma,
      title: 'Sigma',
      minLevel: 33,
      maxLevel: 47,
      icon: Icons.visibility,
      badgeSymbol: '',
      gradientColors: [Color(0xFF2B6CB0), Color(0xFF1A365D)],
      borderWidth: 3.0,
      hasGlow: true,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.alpha,
      title: 'Alpha',
      minLevel: 48,
      maxLevel: 65,
      icon: Icons.workspace_premium,
      badgeSymbol: '',
      gradientColors: [Color(0xFFC53030), Color(0xFF742A2A)],
      borderWidth: 3.5,
      hasGlow: true,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.gigachad,
      title: 'Gigachad',
      minLevel: 66,
      maxLevel: 82,
      icon: Icons.diamond_outlined,
      badgeSymbol: '',
      gradientColors: [Color(0xFFD69E2E), Color(0xFF744210)],
      borderWidth: 3.5,
      hasGlow: true,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.superSaiyan,
      title: 'Super Saiyan',
      minLevel: 83,
      maxLevel: 99,
      icon: Icons.flare,
      badgeSymbol: '',
      gradientColors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
      borderWidth: 4.0,
      hasGlow: true,
    ),
    AvatarTierDefinition(
      tier: AvatarTier.superSaiyanGod,
      title: 'Super Saiyan God',
      minLevel: 100,
      maxLevel: 100,
      icon: Icons.auto_awesome,
      badgeSymbol: '',
      gradientColors: [Color(0xFFFF0055), Color(0xFFFF4500)],
      borderWidth: 5.0,
      hasGlow: true,
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
  /// Evolution progress represents progress through the current evolution tier:
  /// - Level 1  -> beginning of Yowaimo (0%)
  /// - Level 4  -> 100% Yowaimo (100%)
  /// - Level 5  -> beginning of Karen (0%)
  /// - Level 11 -> 100% Karen (100%)
  /// - Level 99 -> 100% Super Saiyan (100%)
  /// - Level 100 -> 100% Super Saiyan God (100%)
  AvatarProgression progressionFor({
    int? totalXp,
    int? level,
    LevelEngine? levelEngine,
  }) {
    final le = levelEngine ?? this.levelEngine;

    final int safeLevel;
    if (level != null) {
      safeLevel = level < 1 ? 1 : (level > 100 ? 100 : level);
    } else if (totalXp != null) {
      final safeXp = totalXp < 0 ? 0 : totalXp;
      safeLevel = le.levelFromTotalXp(safeXp);
    } else {
      safeLevel = 1;
    }

    // Find the matching tier index
    var matchIndex = 0;
    for (var i = 0; i < tiers.length; i++) {
      if (tiers[i].containsLevel(safeLevel)) {
        matchIndex = i;
        break;
      }
    }

    final currentDef = tiers[matchIndex];
    final hasNext = matchIndex < tiers.length - 1;
    final nextDef = hasNext ? tiers[matchIndex + 1] : null;

    final double progress;
    if (safeLevel >= 100 || currentDef.maxLevel == currentDef.minLevel) {
      progress = 1.0;
    } else {
      final span = currentDef.maxLevel - currentDef.minLevel;
      progress = ((safeLevel - currentDef.minLevel) / span).clamp(0.0, 1.0);
    }

    final int? currentTierXp;
    final int? tierTotalXp;
    if (totalXp != null) {
      final tierStartXp = le.totalXpRequiredForLevel(currentDef.minLevel);
      final tierEndXp = le.totalXpRequiredForLevel(
        currentDef.maxLevel >= 100 ? 100 : currentDef.maxLevel + 1,
      );
      final span = tierEndXp - tierStartXp;
      if (span > 0) {
        tierTotalXp = span;
        currentTierXp = (totalXp - tierStartXp).clamp(0, span);
      } else {
        tierTotalXp = null;
        currentTierXp = null;
      }
    } else {
      currentTierXp = null;
      tierTotalXp = null;
    }

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
      currentTierXp: currentTierXp,
      tierTotalXp: tierTotalXp,
    );
  }

  /// Convenience method to compute [AvatarProgression] when only [level] is available.
  AvatarProgression progressionForLevel(int level, {LevelEngine? levelEngine}) {
    return progressionFor(level: level, levelEngine: levelEngine);
  }
}
