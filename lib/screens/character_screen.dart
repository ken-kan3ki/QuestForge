import 'package:flutter/material.dart';

import '../models/avatar_progression.dart';
import '../services/level_engine.dart';
import '../services/streak_engine.dart';
import '../state/task_scope.dart';
import '../widgets/player_avatar.dart';

/// The Character screen — an RPG-inspired hero sheet that displays the
/// player's current progression state.
///
/// It reads already-calculated [LevelProgress], [AvatarProgression], and [StreakInfo] from
/// [TaskController] and renders them. No XP/level/streak math happens here.
class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TaskScope.of(context);
    final LevelProgress progress = controller.levelProgress;
    final StreakInfo streak = controller.streakInfo();
    final AvatarProgression avatarProgression = controller.avatarProgression;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Character')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // ── Hero header ──────────────────────────────────────────
            _HeroHeader(
              progression: avatarProgression,
              totalXp: progress.totalXp,
              colors: colors,
              theme: theme,
            ),
            const SizedBox(height: 24),

            // ── Avatar Evolution Progress card ───────────────────────
            _SectionCard(
              children: [
                _SectionTitle(
                  label: 'Avatar Evolution',
                  colors: colors,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                _AvatarEvolutionCard(
                  progression: avatarProgression,
                  colors: colors,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── XP progress card ─────────────────────────────────────
            _SectionCard(
              children: [
                _SectionTitle(
                  label: 'Experience',
                  colors: colors,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                _XpProgressBar(
                  progress: progress,
                  colors: colors,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Streak & multiplier card ─────────────────────────────
            _SectionCard(
              children: [
                _SectionTitle(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  colors: colors,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        label: 'Current streak',
                        value: '${streak.streakLength}',
                        unit: streak.streakLength == 1 ? 'day' : 'days',
                        icon: Icons.whatshot,
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatBlock(
                        label: 'XP multiplier',
                        value: '×${streak.currentMultiplier.toStringAsFixed(2)}',
                        unit: '',
                        icon: Icons.auto_awesome,
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets — kept in the same file to avoid over-fragmentation
// for a single screen. None of these do calculation; they only format and
// display the values they receive.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.progression,
    required this.totalXp,
    required this.colors,
    required this.theme,
  });

  final AvatarProgression progression;
  final int totalXp;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlayerAvatar(
          size: 104,
          level: progression.level,
          progression: progression,
        ),
        const SizedBox(height: 16),
        Text(
          progression.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Level ${progression.level}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$totalXp XP earned',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AvatarEvolutionCard extends StatelessWidget {
  const _AvatarEvolutionCard({
    required this.progression,
    required this.colors,
    required this.theme,
  });

  final AvatarProgression progression;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final nextEvolution = progression.nextTitle;
    final progress = progression.progress;
    final percent = (progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Evolution Progress',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              key: const Key('avatar-evolution-percent'),
              '$percent%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _AvatarEvolutionBar(
          progress: progress,
          color: progression.definition.gradientColors.first,
          trackColor: colors.outlineVariant.withValues(alpha: 0.20),
        ),
        const SizedBox(height: 10),
        if (nextEvolution != null) ...[
          Row(
            children: [
              Text(
                'Next evolution: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                nextEvolution,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ] else ...[
          Text(
            'Max evolution reached (${progression.title})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _AvatarEvolutionBar extends StatelessWidget {
  const _AvatarEvolutionBar({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        key: const Key('avatar-evolution-track'),
        height: 12,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: trackColor),
                  child: const SizedBox.expand(),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: color),
                    child: SizedBox(
                      key: const Key('avatar-evolution-bar'),
                      width: constraints.maxWidth * clamped,
                      height: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    this.icon,
    required this.label,
    required this.colors,
    required this.theme,
  });

  final IconData? icon;
  final String label;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _XpProgressBar extends StatelessWidget {
  const _XpProgressBar({
    required this.progress,
    required this.colors,
    required this.theme,
  });

  final LevelProgress progress;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isMaxLevel = progress.level >= LevelEngine.maxLevel;
    final clampedProgress = progress.progressToNextLevel.clamp(0.0, 1.0);
    final percentText =
        isMaxLevel ? '100%' : '${(clampedProgress * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // progress fraction text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMaxLevel
                  ? '${progress.xpSpanForCurrentLevel} / ${progress.xpSpanForCurrentLevel} XP'
                  : '${progress.xpIntoCurrentLevel} / ${progress.xpSpanForCurrentLevel} XP',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              percentText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: clampedProgress,
            minHeight: 12,
            backgroundColor: colors.outlineVariant.withValues(alpha: 0.20),
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
        const SizedBox(height: 10),

        // next-level hint
        Text(
          isMaxLevel
              ? 'MAX LEVEL'
              : '${progress.xpToNextLevel} XP to level ${progress.level + 1}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.colors,
    required this.theme,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
