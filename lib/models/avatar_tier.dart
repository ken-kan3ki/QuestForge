import 'package:flutter/material.dart';

/// Supported avatar progression tiers for the exact 100-level RPG system.
enum AvatarTier {
  yowaimo,
  karen,
  skinny,
  npc,
  sigma,
  alpha,
  gigachad,
  superSaiyan,
  superSaiyanGod;

  /// Backward-compatibility aliases for existing test or UI references.
  static const AvatarTier yoyaimo = AvatarTier.yowaimo;
  static const AvatarTier gigaChad = AvatarTier.gigachad;
}

/// Metadata definition for an [AvatarTier], holding all tier thresholds,
/// display titles, and visual characteristics.
class AvatarTierDefinition {
  const AvatarTierDefinition({
    required this.tier,
    required this.title,
    required this.minLevel,
    required this.maxLevel,
    required this.icon,
    required this.badgeSymbol,
    required this.gradientColors,
    this.borderColor,
    this.borderWidth = 2.5,
    this.hasGlow = false,
  });

  /// The enum identifier for this tier.
  final AvatarTier tier;

  /// Fun display title (e.g. 'Gigachad', 'Super Saiyan God').
  final String title;

  /// Minimum level required for this tier (inclusive).
  final int minLevel;

  /// Maximum level for this tier (inclusive).
  final int maxLevel;

  /// Primary icon representing this avatar tier visually.
  final IconData icon;

  /// Optional short badge marker for this tier.
  final String badgeSymbol;

  /// Gradient colors for the avatar's circular backdrop.
  final List<Color> gradientColors;

  /// Custom border color override (or falls back to theme primary/accent).
  final Color? borderColor;

  /// Border stroke width for the avatar circle.
  final double borderWidth;

  /// Whether this tier displays an outer radiant glow aura.
  final bool hasGlow;

  /// Returns whether a given [level] falls within this tier's bounds.
  bool containsLevel(int level) {
    if (level < minLevel) return false;
    if (level > maxLevel) return false;
    return true;
  }
}
