# QuestForge — File Index

> Compact map of important source files. Grouped by folder.  
> "Purpose: unknown" = inspect before modifying.  
> Do NOT document every trivial widget — only files where purpose was confirmed.

---

## lib/

```
main.dart               — App entry point; calls runApp(ProRpgApp())
app.dart                — ProRpgApp StatefulWidget; wires services, creates TaskController,
                          wraps MaterialApp in TaskScope
```

## lib/core/constants/

```
game_constants.dart     — Canonical game balance values:
                          XP per difficulty (Light=5, Standard=10, Challenging=20),
                          custom XP range (5–50),
                          streak multipliers (base 1.00, +0.05/day, max 1.50),
                          level bounds (min=1, max=100)
```

## lib/models/

```
task.dart               — Task entity: id, title, description, xpReward, dueDate,
                          isCompleted, createdAt, completedAt, questType, recurrence,
                          completedDates, reminder; isHabit getter; hasCompletedOn()
quest_type.dart         — Enum: habit | sideQuest
recurrence_rule.dart    — Recurrence configuration for habit quests
reminder_config.dart    — Per-task reminder scheduling configuration
avatar_progression.dart — Immutable snapshot: tier, title, level, progress, nextTier
avatar_tier.dart        — AvatarTier enum (9 values) + AvatarTierDefinition metadata class
player_stats.dart       — PlayerStats, StatisticsData, DailyActivityStat value objects
xp_transaction.dart     — Single XP ledger entry (award or reversal)
app_settings.dart       — Application settings model
quest_difficulty.dart   — Quest difficulty enum/model
```

## lib/services/

```
game constants used by:
  level_engine.dart              — Pure XP-to-level converter; LevelProgress value object;
                                   formula: round(40 + 2*L + 0.05*L²); Level 100 cap ~30,265 XP
  xp_engine.dart                 — Pure single-award XP calculator; returns XpDecision
  avatar_engine.dart             — Level-to-avatar-tier mapper; AvatarEngine.tiers is the
                                   canonical tier registry; returns AvatarProgression
  streak_engine.dart             — Calculates streak length + XP multiplier from completion dates
  recurrence_engine.dart         — Determines if a habit can be completed at a given time
  statistics_service.dart        — Computes StatisticsData from tasks + XP transactions

persistence:
  persistence_service.dart       — Abstract PersistenceService interface +
                                   InMemoryPersistenceService (testing)
  shared_preferences_persistence_service.dart  — SharedPreferences implementation
  persistent_task_repository.dart — TaskRepository backed by SharedPreferences JSON
  persistent_xp_ledger.dart      — XpLedger backed by SharedPreferences JSON

abstractions:
  task_repository.dart           — TaskRepository interface (CRUD)
  xp_ledger.dart                 — XpLedger interface + InMemoryXpLedger
  task_validator.dart            — Task field validation rules

other:
  backup_service.dart            — JSON export/import of tasks + XP transactions via file_picker
  reminder_service.dart          — Per-task reminder scheduling/cancellation; persists state
  calendar_day.dart              — CalendarDay value object (year/month/day without time)
  date_display.dart              — Date formatting utilities
  xp_completion_id.dart          — Generates stable completion IDs to prevent double-awarding XP
```

## lib/state/

```
task_controller.dart    — Central ChangeNotifier; owns all services; single orchestrator
                          for task CRUD, XP, levels, streaks, avatar, statistics
task_scope.dart         — InheritedWidget providing TaskController to the widget tree;
                          access via TaskScope.of(context)
```

## lib/navigation/

```
app_shell.dart          — AppShell StatefulWidget; IndexedStack of 4 screens +
                          NavigationBar (Material 3)
nav_destination.dart    — NavDestination definitions (icon, label, tooltip) for 4 tabs
```

## lib/screens/

```
home_screen.dart        — Quest list view; complete/uncomplete; FAB to open TaskEditorScreen
character_screen.dart   — Avatar display; tier progress bar; level XP bar; evolution info
stats_screen.dart       — Statistics dashboard: daily/weekly XP, task counts,
                          streak display, level progress
settings_screen.dart    — Backup/restore UI; app settings
task_editor_screen.dart — Create/edit quest form; difficulty slider, type, recurrence,
                          reminder configuration
```

## lib/widgets/

```
avatar_character.dart   — Full animated avatar widget with tier-specific visuals and glow
player_avatar.dart      — Compact avatar circle used across multiple screens
task_tile.dart          — Individual quest tile: title, XP, completion toggle, edit/delete
task_empty_state.dart   — Empty state widget when quest list is empty
placeholder_panel.dart  — Generic placeholder panel widget
```

## lib/theme/

```
app_theme.dart          — AppTheme.light and AppTheme.dark Material ThemeData definitions
```

## test/

```
level_engine_test.dart          — LevelEngine unit tests
xp_engine_test.dart             — XpEngine unit tests
xp_ledger_test.dart             — XpLedger unit tests
streak_engine_test.dart         — StreakEngine unit tests
recurrence_engine_test.dart     — RecurrenceEngine unit tests
avatar_progression_test.dart    — AvatarProgression + AvatarEngine unit tests
task_repository_test.dart       — TaskRepository unit tests
task_validator_test.dart        — TaskValidator unit tests
statistics_service_test.dart    — StatisticsService unit tests
reminder_system_test.dart       — ReminderService unit tests
streak_xp_integration_test.dart — Streak + XP integration tests
habit_quest_test.dart           — Habit quest behavior tests
quest_difficulty_test.dart      — Quest difficulty tests
task_controller_xp_test.dart    — TaskController XP orchestration tests
character_screen_test.dart      — CharacterScreen widget tests
stats_screen_test.dart          — StatsScreen widget tests
widget_test.dart                — App-level smoke test
```

## tool/

```
generate_ai_file_index.ps1  — PowerShell utility; lists lib/ source files with sizes
                              to assist in regenerating FILE_INDEX.md.
                              Does NOT modify application source files.
```

## Root

```
pubspec.yaml                — Package manifest; dependencies; version 1.0.0+1
pubspec.lock                — Locked dependency versions
analysis_options.yaml       — Lint configuration (flutter_lints)
README.md                   — Minimal project README
.gitignore                  — Standard Flutter gitignore
```

---

> To regenerate this index after significant file additions, run:
> `powershell -File tool/generate_ai_file_index.ps1`
> Then update this file manually with purpose descriptions.
