import 'package:flutter/material.dart';

import '../models/avatar_progression.dart';
import '../services/avatar_engine.dart';
import 'avatar_character.dart';

/// Reusable avatar component for the player character that visually reflects
/// the player's current avatar evolution tier.
///
/// Renders a cartoon RPG character portrait that evolves with the resolved
/// [AvatarProgression] tier. Level thresholds and tier math stay in [AvatarEngine].
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    this.size = 96,
    this.level = 1,
    this.progression,
    this.showLevelBadge = true,
    this.showTierSymbol = true,
  });

  /// The diameter of the avatar circle.
  final double size;

  /// The player's current level. Used to derive [AvatarProgression] if not provided directly.
  final int level;

  /// Optional pre-computed [AvatarProgression]. If omitted, derived from [level].
  final AvatarProgression? progression;

  /// Whether to render the 'Lv X' badge at the bottom-right.
  final bool showLevelBadge;

  /// Whether to render a small tier accent pip (non-emoji) at the top-right.
  final bool showTierSymbol;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentProgression =
        progression ?? const AvatarEngine().progressionFor(level: level);
    final def = currentProgression.definition;

    final baseBorderColor =
        def.borderColor ?? def.gradientColors.first.withValues(alpha: 0.85);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (def.hasGlow)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: def.gradientColors.first.withValues(alpha: 0.45),
                    blurRadius: size * 0.22,
                    spreadRadius: size * 0.04,
                  ),
                ],
              ),
            ),

          if (def.borderWidth >= 3.5)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: def.gradientColors.last.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),

          Container(
            width: def.borderWidth >= 3.5 ? size - 6 : size,
            height: def.borderWidth >= 3.5 ? size - 6 : size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: def.gradientColors,
              ),
              border: Border.all(
                color: baseBorderColor,
                width: def.borderWidth,
              ),
            ),
            child: ClipOval(
              child: def.imagePath != null
                  ? Image.asset(
                      def.imagePath!,
                      width: def.borderWidth >= 3.5 ? size - 6 : size,
                      height: def.borderWidth >= 3.5 ? size - 6 : size,
                      fit: BoxFit.cover,
                    )
                  : AvatarCharacterPortrait(
                      tier: def.tier,
                      size: def.borderWidth >= 3.5 ? size - 6 : size,
                      accentColors: def.gradientColors,
                    ),
            ),
          ),

          if (showTierSymbol)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: baseBorderColor, width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: def.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),

          if (showLevelBadge)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.surface,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  'Lv ${currentProgression.level}',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: size * 0.13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
