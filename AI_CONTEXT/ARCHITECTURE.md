# QuestForge — Architecture

> Keep this concise. Do not paste source code. Purpose: help a future AI understand where to look.

---

## Folder Responsibilities

| Folder | Responsibility |
|--------|---------------|
| `lib/` | All application source code |
| `lib/core/constants/` | Game-wide constants (XP values, level cap, multipliers) |
| `lib/models/` | Immutable domain value objects |
| `lib/services/` | Pure business logic engines + persistence abstractions |
| `lib/state/` | Flutter state management (`ChangeNotifier`-based) |
| `lib/navigation/` | App shell and navigation destination config |
| `lib/screens/` | Top-level screen widgets |
| `lib/widgets/` | Reusable widget components |
| `lib/theme/` | Material theme definitions |
| `test/` | Unit and widget tests (flat structure, no subfolders) |
| `assets/icons/` | Icon assets (currently minimal) |
| `windows/`, `linux/`, `android/`, `web/` | Platform runners |

---

## Entry Points

```
lib/main.dart
  -> ProRpgApp (lib/app.dart)
     -> wires up services, creates TaskController
     -> TaskScope (InheritedWidget) wraps MaterialApp
        -> AppShell (navigation/app_shell.dart)
           -> IndexedStack of 4 screens
```

---

## State Management

**Pattern:** `ChangeNotifier` (vanilla Flutter — no Provider, Riverpod, Bloc, etc.)

**Key class:** `TaskController` (`lib/state/task_controller.dart`)
- Central orchestrator for all game state
- Owns: `TaskRepository`, `XpLedger`, `StreakEngine`, `LevelEngine`, `AvatarEngine`, `RecurrenceEngine`, `StatisticsService`, `ReminderService`
- Exposes: tasks, XP totals, level progress, avatar progression, streak info, statistics
- Notifies listeners on any mutation

**Access pattern:** `TaskScope.of(context).controller` — `TaskScope` (`lib/state/task_scope.dart`) is an `InheritedWidget`.

---

## Important Services

### `GameConstants` — `lib/core/constants/game_constants.dart`
- Single source of truth for all game balance values
- XP difficulties: Light=5, Standard=10, Challenging=20, custom range 5–50
- Streak: base 1.00, +0.05/day, max 1.50
- Level: min=1, max=100

### `LevelEngine` — `lib/services/level_engine.dart`
- Pure, stateless XP-to-level converter
- Formula: `round(40 + 2*L + 0.05*L²)` XP per level step
- Level 100 cap at ~30,265 cumulative XP
- Returns `LevelProgress` value object
- `const LevelEngine()` — no dependencies

### `XpEngine` — `lib/services/xp_engine.dart`
- Pure stateless calculator for a single XP award decision
- Handles duplicate detection and multiplier application
- Returns `XpDecision` value object

### `AvatarEngine` — `lib/services/avatar_engine.dart`
- Maps player level → avatar tier (see DECISIONS.md for tier boundaries)
- Returns `AvatarProgression` value object
- Tier definitions are the canonical list inside this class (`AvatarEngine.tiers`)

### `StreakEngine` — `lib/services/streak_engine.dart`
- Calculates current streak length and XP multiplier from completion date history
- Returns `StreakInfo` value object

### `StatisticsService` — `lib/services/statistics_service.dart`
- Computes `StatisticsData` from task list + XP transaction log
- Pure, stateless — all inputs supplied by caller

### `RecurrenceEngine` — `lib/services/recurrence_engine.dart`
- Determines if a habit task can be completed given its recurrence rule and current time

### `ReminderService` — `lib/services/reminder_service.dart`
- Schedules, reschedules, and cancels per-task reminders
- Persists reminder state via `PersistenceService`

### `BackupService` — `lib/services/backup_service.dart`
- JSON export/import of tasks + XP transactions
- Uses `file_picker` for file I/O
- Versioned format (`formatVersion` field in JSON)

### `PersistenceService` — `lib/services/persistence_service.dart`
- Abstract key-value storage interface
- Production implementation: `SharedPreferencesPersistenceService`
- Test implementation: `InMemoryPersistenceService` (also defined in persistence_service.dart)

### `PersistentTaskRepository` — `lib/services/persistent_task_repository.dart`
- Implements `TaskRepository` with SharedPreferences-backed JSON persistence
- Call `loadFromPersistence()` on startup

### `PersistentXpLedger` — `lib/services/persistent_xp_ledger.dart`
- Implements `XpLedger` with SharedPreferences-backed JSON persistence
- Call `loadFromPersistence()` on startup

---

## Important Models

| Model | File | Purpose |
|-------|------|---------|
| `Task` | `lib/models/task.dart` | Core quest entity with XP reward, type, recurrence, reminder |
| `QuestType` | `lib/models/quest_type.dart` | Enum: `habit` (recurring) / `sideQuest` (one-time) |
| `RecurrenceRule` | `lib/models/recurrence_rule.dart` | How/when a habit repeats |
| `ReminderConfig` | `lib/models/reminder_config.dart` | Per-task reminder settings |
| `AvatarProgression` | `lib/models/avatar_progression.dart` | Snapshot: current tier, progress, next tier |
| `AvatarTier` | `lib/models/avatar_tier.dart` | Enum of 9 evolution tiers + `AvatarTierDefinition` metadata |
| `PlayerStats` | `lib/models/player_stats.dart` | Snapshot: XP, level, streak, quest count; also `StatisticsData`, `DailyActivityStat` |
| `XpTransaction` | `lib/models/xp_transaction.dart` | Ledger entry for one XP award or reversal |
| `AppSettings` | `lib/models/app_settings.dart` | App-level settings |

---

## Interfaces (Abstractions)

| Interface | File | Purpose |
|-----------|------|---------|
| `TaskRepository` | `lib/services/task_repository.dart` | CRUD for Task list |
| `XpLedger` | `lib/services/xp_ledger.dart` | XP transaction log; includes `InMemoryXpLedger` |
| `PersistenceService` | `lib/services/persistence_service.dart` | Key-value store |

---

## Screens

| Screen | File | Purpose |
|--------|------|---------|
| `HomeScreen` | `lib/screens/home_screen.dart` | Quest list, complete/uncomplete, add quest |
| `CharacterScreen` | `lib/screens/character_screen.dart` | Avatar display, tier progress, level XP bar |
| `StatsScreen` | `lib/screens/stats_screen.dart` | Statistics charts and counters |
| `SettingsScreen` | `lib/screens/settings_screen.dart` | Backup/restore, app settings |
| `TaskEditorScreen` | `lib/screens/task_editor_screen.dart` | Create/edit quest form (title, XP, type, recurrence, reminder) |

---

## Navigation

- **Pattern:** `IndexedStack` inside `AppShell` (`lib/navigation/app_shell.dart`)
- **4 tabs:** Home, Character, Stats, Settings
- **No named routes** — all navigation is index-based tab switching + modal push for `TaskEditorScreen`
- Tab definitions: `NavDestination.items` (`lib/navigation/nav_destination.dart`)

---

## Widgets

| Widget | File | Purpose |
|--------|------|---------|
| `AvatarCharacter` | `lib/widgets/avatar_character.dart` | Renders the animated avatar with tier visuals |
| `PlayerAvatar` | `lib/widgets/player_avatar.dart` | Avatar circle widget used in multiple screens |
| `TaskTile` | `lib/widgets/task_tile.dart` | Individual quest row in the home list |
| `TaskEmptyState` | `lib/widgets/task_empty_state.dart` | Empty state when no quests exist |
| `PlaceholderPanel` | `lib/widgets/placeholder_panel.dart` | Generic placeholder widget |

---

## Theme

- `AppTheme` (`lib/theme/app_theme.dart`) — defines `AppTheme.light` and `AppTheme.dark` Material themes
- App starts in `ThemeMode.dark` (`lib/app.dart`)

---

## Persistence

- **Engine:** `shared_preferences` package
- **Abstraction:** `PersistenceService` interface
- **Keys:** Defined within each repository/service; SharedPreferences keys are migration-sensitive — do not rename them
- **Startup load:** `app.dart` calls `loadFromPersistence()` on both `PersistentTaskRepository` and `PersistentXpLedger`, then calls `TaskController.refresh()`

---

## Testing

- **Location:** `test/` (flat, 17 test files)
- **Framework:** `flutter_test` (standard Flutter test SDK)
- **No test subdirectories** — all tests are at the root of `test/`
- **Coverage areas:** level engine, XP engine, XP ledger, streak engine, recurrence engine, avatar progression, task repository, task validator, statistics service, reminder system, character screen, stats screen, widget smoke test, integration-style streak+XP test
- **Run:** `flutter test`
- **Mocking:** `InMemoryPersistenceService` and `InMemoryXpLedger` used in tests; no external mocking library

---

## Utility Files (Non-Application)

| File | Purpose |
|------|---------|
| `tool/generate_ai_file_index.ps1` | PowerShell script to regenerate `AI_CONTEXT/FILE_INDEX.md` |
