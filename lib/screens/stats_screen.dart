import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/player_stats.dart';
import '../state/task_scope.dart';

/// The Statistics screen — displays comprehensive player progression,
/// streak data, task completion metrics, and an interactive historical activity view.
///
/// All calculations and aggregations are performed by [StatisticsService] and
/// retrieved via [TaskController.statistics]. This widget performs zero business logic.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _ChartMetric { xp, tasks }

class _StatsScreenState extends State<StatsScreen> {
  _ChartMetric _selectedMetric = _ChartMetric.xp;

  @override
  Widget build(BuildContext context) {
    final controller = TaskScope.of(context);
    final StatisticsData stats = controller.statistics;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // ── Level & Progression Overview ─────────────────────────────────
            _SectionCard(
              children: [
                _SectionTitle(
                  icon: Icons.military_tech_rounded,
                  label: 'Character Progression',
                  colors: colors,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                _LevelProgressSection(stats: stats, colors: colors, theme: theme),
              ],
            ),
            const SizedBox(height: 16),

            // ── Streaks & Multiplier Card ────────────────────────────────────
            _SectionCard(
              children: [
                _SectionTitle(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streaks & Multipliers',
                  colors: colors,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-current-streak'),
                        icon: Icons.whatshot_rounded,
                        label: 'Current Streak',
                        value: '${stats.currentStreak}',
                        unit: stats.currentStreak == 1 ? 'day' : 'days',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-longest-streak'),
                        icon: Icons.emoji_events_outlined,
                        label: 'Longest Streak',
                        value: '${stats.longestStreak}',
                        unit: stats.longestStreak == 1 ? 'day' : 'days',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-current-multiplier'),
                        icon: Icons.auto_awesome_rounded,
                        label: 'XP Multiplier',
                        value: '×${stats.currentMultiplier.toStringAsFixed(2)}',
                        unit: '',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Quests Completed Card ────────────────────────────────────────
            _SectionCard(
              children: [
                _SectionTitle(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Quests Completed',
                  colors: colors,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-tasks-today'),
                        icon: Icons.today_rounded,
                        label: 'Today',
                        value: '${stats.tasksCompletedToday}',
                        unit: 'quests',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-tasks-week'),
                        icon: Icons.date_range_rounded,
                        label: 'This Week',
                        value: '${stats.tasksCompletedThisWeek}',
                        unit: 'quests',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-total-tasks'),
                        icon: Icons.all_inclusive_rounded,
                        label: 'All-Time',
                        value: '${stats.totalTasksCompleted}',
                        unit: 'quests',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Experience Earned Card ───────────────────────────────────────
            _SectionCard(
              children: [
                _SectionTitle(
                  icon: Icons.bolt_rounded,
                  label: 'Experience Gained',
                  colors: colors,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-xp-today'),
                        icon: Icons.flash_on_rounded,
                        label: 'Today',
                        value: '${stats.xpEarnedToday}',
                        unit: 'XP',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-xp-week'),
                        icon: Icons.trending_up_rounded,
                        label: 'This Week',
                        value: '${stats.xpEarnedThisWeek}',
                        unit: 'XP',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBlock(
                        key: const Key('stats-total-xp'),
                        icon: Icons.military_tech_rounded,
                        label: 'All-Time',
                        value: '${stats.totalXpAllTime}',
                        unit: 'XP',
                        colors: colors,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Historical View (Recent Activity Chart) ──────────────────────
            _SectionCard(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionTitle(
                      icon: Icons.bar_chart_rounded,
                      label: 'Activity History',
                      colors: colors,
                      theme: theme,
                    ),
                    // Metric Selector
                    SegmentedButton<_ChartMetric>(
                      segments: const [
                        ButtonSegment(
                          value: _ChartMetric.xp,
                          label: Text('XP'),
                          icon: Icon(Icons.bolt, size: 14),
                        ),
                        ButtonSegment(
                          value: _ChartMetric.tasks,
                          label: Text('Quests'),
                          icon: Icon(Icons.task_alt, size: 14),
                        ),
                      ],
                      selected: {_selectedMetric},
                      onSelectionChanged: (selected) {
                        setState(() => _selectedMetric = selected.first);
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStateProperty.all(
                          theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _HistoricalBarChart(
                  key: const Key('stats-activity-chart'),
                  activity: stats.recentDailyActivity,
                  metric: _selectedMetric,
                  colors: colors,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────────────

class _LevelProgressSection extends StatelessWidget {
  const _LevelProgressSection({
    required this.stats,
    required this.colors,
    required this.theme,
  });

  final StatisticsData stats;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final progress = stats.levelProgress;
    final percent = (progress.progressToNextLevel * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              key: const Key('stats-current-level'),
              'Level ${stats.currentLevel}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            Text(
              key: const Key('stats-level-progress'),
              '${progress.xpIntoCurrentLevel} / ${progress.xpSpanForCurrentLevel} XP ($percent%)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.progressToNextLevel,
            minHeight: 12,
            backgroundColor: colors.outlineVariant.withValues(alpha: 0.20),
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          stats.currentLevel >= 100
              ? 'MAX LEVEL'
              : '${progress.xpToNextLevel} XP needed to reach Level ${stats.currentLevel + 1}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HistoricalBarChart extends StatelessWidget {
  const _HistoricalBarChart({
    super.key,
    required this.activity,
    required this.metric,
    required this.colors,
    required this.theme,
  });

  final List<DailyActivityStat> activity;
  final _ChartMetric metric;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No recent activity recorded.',
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }

    final values = activity.map((e) => metric == _ChartMetric.xp ? e.xpEarned : e.tasksCompleted).toList();
    final maxValue = values.fold<int>(0, math.max);
    final allZero = maxValue == 0;

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(activity.length, (index) {
              final item = activity[index];
              final val = metric == _ChartMetric.xp ? item.xpEarned : item.tasksCompleted;
              final fraction = allZero ? 0.0 : (val / maxValue).clamp(0.0, 1.0);
              final isToday = item.isToday;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value indicator
                      Text(
                        val > 0 ? '$val' : '-',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday ? colors.primary : colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Bar
                      Flexible(
                        child: Container(
                          width: double.infinity,
                          height: math.max(6.0, 90.0 * fraction),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            color: isToday
                                ? colors.primary
                                : (val > 0
                                    ? colors.primary.withValues(alpha: 0.55)
                                    : colors.outlineVariant.withValues(alpha: 0.15)),
                            border: isToday
                                ? Border.all(color: colors.onPrimary.withValues(alpha: 0.3), width: 1)
                                : null,
                            boxShadow: isToday && val > 0
                                ? [
                                    BoxShadow(
                                      color: colors.primary.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Day label
                      Text(
                        isToday ? 'Today' : _shortWeekday(item.date.weekday),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                          color: isToday ? colors.primary : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        if (allZero) ...[
          const SizedBox(height: 12),
          Text(
            'Complete quests to forge your activity history!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  String _shortWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    super.key,
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
      padding: const EdgeInsets.all(12),
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
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
