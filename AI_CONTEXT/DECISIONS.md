# QuestForge — Architectural Decisions

> These decisions are derived from the actual implementation as inspected on 2026-09-27.  
> Verify against source code before relying on them for a specific task.  
> Do NOT reverse these decisions casually — they are load-bearing.

---

## Game Mechanics

### D-01: Level Maximum Is 100

**Decision:** Player level is capped at 100.  
**Source:** `GameConstants.maxLevel = 100` (`lib/core/constants/game_constants.dart`), `LevelEngine.maxLevel`.  
**Do not change** without an explicit feature request and migration plan.

### D-02: XP Calculations Are Centralized

**Decision:** All XP award logic flows through `XpEngine`, `LevelEngine`, and `GameConstants`. No magic numbers scattered across widgets or controllers.  
**Source:** `lib/services/xp_engine.dart`, `lib/services/level_engine.dart`, `lib/core/constants/game_constants.dart`.  
**Implication:** If XP values change, change `GameConstants` only.

### D-03: XP Curve Formula

**Decision:** XP required to advance from level L to L+1 is `round(40 + 2*L + 0.05*L²)`.  
**Source:** `LevelEngine.requiredXpForLevel()` (`lib/services/level_engine.dart`).  
**Cumulative to Level 100:** ~30,265 XP.  
**Do not change** the formula without updating all level engine tests.

### D-04: Streak Multiplier Range

**Decision:** Base multiplier 1.00, +0.05 per consecutive productive day, maximum 1.50.  
**Source:** `GameConstants.baseStreakMultiplier`, `.streakBonusPerDay`, `.maxStreakMultiplier`.

### D-05: XP Difficulty Tiers

**Decision:** Three fixed difficulty tiers: Light (5 XP), Standard (10 XP), Challenging (20 XP). Custom XP is also supported in the range 5–50.  
**Source:** `GameConstants.xpLight/xpStandard/xpChallenging/minCustomXp/maxCustomXp`.

### D-06: Avatar Evolution Is Level-Derived

**Decision:** Avatar tier is computed from the player's current level — it is NOT independently persisted.  
**Source:** `AvatarEngine.progressionFor()` (`lib/services/avatar_engine.dart`) — tier is derived from level at read time.  
**Implication:** Avatar visuals update automatically when level changes; no separate avatar state to persist.

### D-07: Avatar Tier Registry Is Canonical in AvatarEngine

**Decision:** `AvatarEngine.tiers` (static const List) is the single source of truth for tier boundaries, titles, and visual metadata.  
**Source:** `lib/services/avatar_engine.dart`.  
**Do not duplicate** tier boundary constants elsewhere.

### D-08: Avatar Tiers (Verified Boundaries)

| Tier | Enum | Level Range |
|------|------|------------|
| Yowaimo | `AvatarTier.yowaimo` | 1–4 |
| Karen | `AvatarTier.karen` | 5–11 |
| Skinny | `AvatarTier.skinny` | 12–20 |
| NPC | `AvatarTier.npc` | 21–32 |
| Sigma | `AvatarTier.sigma` | 33–47 |
| Alpha | `AvatarTier.alpha` | 48–65 |
| Gigachad | `AvatarTier.gigachad` | 66–82 |
| Super Saiyan | `AvatarTier.superSaiyan` | 83–99 |
| Super Saiyan God | `AvatarTier.superSaiyanGod` | 100 |

---

## Quest / Task System

### D-09: Two Quest Types

**Decision:** Quests are either `QuestType.habit` (recurring) or `QuestType.sideQuest` (one-time).  
**Source:** `lib/models/quest_type.dart`.  
**Note:** The in-code type names are `habit` and `sideQuest`. The UI may display these as different names. The git history references "Character Arc" and "Side Hustle" as earlier names — the current code uses `habit`/`sideQuest`.

### D-10: Habits Can Be Completed Repeatedly

**Decision:** Habit quests store `completedDates: List<DateTime>` and can be completed once per day. Side quests use `isCompleted: bool`.  
**Source:** `Task` model, `RecurrenceEngine.canComplete()`.

### D-11: XP Reversal on Uncomplete

**Decision:** Uncompleting a task reverses the associated XP transaction via `XpLedger.reverseForCompletion()`.  
**Source:** `TaskController.uncompleteTask()`.

---

## Persistence

### D-12: Local Only — No Cloud

**Decision:** All data persists locally via `SharedPreferences`. No backend, no auth, no cloud sync.  
**Source:** `pubspec.yaml` (no cloud dependencies), `SharedPreferencesPersistenceService`.  
**Do not add** Firebase, Supabase, or any network service without an explicit requirement.

### D-13: SharedPreferences Keys Are Migration-Sensitive

**Decision:** SharedPreferences storage keys are used as-is across app updates. Renaming them would cause data loss for existing users.  
**Implication:** Do not rename persistence keys. Add new keys for new fields; do not repurpose old ones.

### D-14: PersistenceService Abstraction

**Decision:** All repositories and services depend on the abstract `PersistenceService` interface, not on `SharedPreferences` directly. This enables test isolation via `InMemoryPersistenceService`.  
**Source:** `lib/services/persistence_service.dart`.

---

## Architecture

### D-15: Single Controller Orchestrator

**Decision:** `TaskController` is the single state orchestrator — it owns all services and is the only place where task/XP/streak/avatar state is mutated.  
**Source:** `lib/state/task_controller.dart`.  
**Do not** bypass `TaskController` to call service methods directly from widgets.

### D-16: State Management via ChangeNotifier + InheritedWidget

**Decision:** No third-party state management library (Provider, Riverpod, Bloc, etc.). Uses Flutter's built-in `ChangeNotifier` + a custom `InheritedWidget` (`TaskScope`).  
**Source:** `lib/state/task_scope.dart`, `lib/state/task_controller.dart`.

### D-17: All Engines Are Pure/Stateless

**Decision:** `LevelEngine`, `XpEngine`, `AvatarEngine`, `StreakEngine`, `RecurrenceEngine`, `StatisticsService` are all pure, stateless classes instantiated with `const`. They do not read or write UI state.  
**Implication:** These are safe to test in complete isolation.

---

## Platform

### D-18: Windows Support Must Be Preserved

**Decision:** Windows is a supported target and must remain working.  
**Source:** `windows/` platform folder present and maintained; generated plugin files modified in git.  
**Implication:** Avoid `dart:io` APIs or plugins that do not support Windows.

---

## Backup

### D-19: Backup Format Is Versioned

**Decision:** JSON backup files contain a `formatVersion` field. Breaking changes to the schema must increment the version and provide migration logic.  
**Source:** `BackupService`, `BackupData.formatVersion` (`lib/services/backup_service.dart`).
