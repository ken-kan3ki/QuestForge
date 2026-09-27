# QuestForge — Project Context

**Type:** Flutter application (productivity RPG)  
**Package name in pubspec:** `prod` (internal name; app title is `QuestForge`)  
**Version:** 1.0.0+1  
**SDK requirement:** Dart `^3.13.1`

## What It Is

QuestForge is a local-only productivity RPG. Users create quests (tasks), complete them to earn XP, level up a character avatar, maintain daily streaks for XP multipliers, and track progress through statistics and a character evolution screen.

## Supported Platforms

| Platform | Status |
|----------|--------|
| Windows  | Supported — must remain working |
| Android  | Platform folder present |
| Linux    | Platform folder present |
| Web      | Platform folder present |

Windows is the primary development target confirmed by recent git history and generated plugin files.

## Key Features (Confirmed)

- **Quests** — Two types: `habit` (recurring) and `sideQuest` (one-time)
- **XP system** — Base XP by difficulty (Light 5, Standard 10, Challenging 20, custom 5–50), modified by streak multiplier
- **Levels** — 1 to 100 cap; XP curve formula `round(40 + 2*L + 0.05*L²)` per level; ~30,265 total XP to reach Level 100
- **Avatar evolution** — 9 tiers derived from level (Yowaimo → Karen → Skinny → NPC → Sigma → Alpha → Gigachad → Super Saiyan → Super Saiyan God)
- **Streaks** — Consecutive productive days; multiplier 1.00 to 1.50 (+0.05/day)
- **Statistics** — Daily/weekly XP, task counts, streak history, level progress bar
- **Reminders** — Per-quest reminder scheduling (ReminderService)
- **Backup/Restore** — JSON file export/import via file_picker (BackupService)
- **Persistence** — SharedPreferences (local only, no cloud/auth)

## Dependencies

```
shared_preferences: ^2.5.5   (local persistence)
file_picker: ^12.3.0         (backup file selection)
cupertino_icons: ^1.0.8
flutter_lints: ^6.0.0        (dev)
```

No backend, no auth, no cloud services.

---

## Coding Rules for Future AI Agents

1. **Inspect before modifying.** Read relevant source files before making changes.
2. **Make the smallest targeted change.** Do not touch unrelated code.
3. **Do not rewrite working systems.** Refactor only when the task explicitly requires it.
4. **Do not refactor unrelated code.** Stay focused on TASK.md.
5. **Do not introduce unnecessary dependencies.** Prefer existing packages.
6. **Do not add backend, auth, or cloud services** unless explicitly requested.
7. **Preserve persistence and migration compatibility.** SharedPreferences keys are load-bearing.
8. **Preserve Windows support.** Verify Windows builds are not broken by platform-specific code.
9. **Do not change established game mechanics** (XP values, level cap, streak multipliers, avatar tiers) unless TASK.md explicitly requests it.
10. **Run `flutter test` after implementation** to confirm no regressions.

### Additional Constraints

- Do NOT change `GameConstants` values without an explicit requirement.
- XP calculations must remain centralized in `XpEngine` + `LevelEngine` + `GameConstants`.
- Avatar tier boundaries are defined in `AvatarEngine.tiers` — do not scatter them elsewhere.
- `PersistenceService` is an abstract interface; the production implementation is `SharedPreferencesPersistenceService`. Tests use `InMemoryPersistenceService`.
- `TaskController` is the single orchestrator for task/XP/streak/avatar state — do not bypass it.
- `TaskScope` is the InheritedWidget that provides `TaskController` to the widget tree.

---

## Source-of-Truth Hierarchy

```
1. Actual source code
2. Tests (test/)
3. Git state / diff
4. AI_CONTEXT/CURRENT_STATE.md
5. AI_CONTEXT/TASK.md
6. AI_CONTEXT/ARCHITECTURE.md
7. Other AI_CONTEXT documentation

If documentation conflicts with the implementation:
-> inspect the implementation, resolve the discrepancy, update the documentation.
```

---

## AI SESSION START PROTOCOL

When starting a new session:

1. Read `AI_CONTEXT/PROJECT.md` (this file)
2. Read `AI_CONTEXT/CURRENT_STATE.md`
3. Read `AI_CONTEXT/TASK.md`
4. Read `AI_CONTEXT/SESSION_HANDOFF.md` if it contains an active handoff
5. Read relevant sections of `AI_CONTEXT/ARCHITECTURE.md`
6. Inspect only source files relevant to `TASK.md`
7. Check `git status` / `git diff` when relevant

**Do NOT automatically scan the entire repository.**  
Only inspect additional files when dependencies or evidence require them.

---

## AI SESSION END PROTOCOL

Before ending a session, an AI agent should:

1. Record what was actually changed.
2. Record exact files changed.
3. Record tests/commands actually run.
4. Record exact pass/fail results.
5. Record unfinished work.
6. Record the next concrete action.
7. Update `AI_CONTEXT/CURRENT_STATE.md`.
8. Update `AI_CONTEXT/SESSION_HANDOFF.md`.
9. Update `AI_CONTEXT/CHANGELOG.md` when appropriate.
10. **Do not claim tests passed unless they were actually run.**

The handoff must be concise.

---

## Token-Efficiency Rules

**Do NOT:**
- Recursively inspect the whole repository for every task
- Re-read unrelated source files
- Rediscover architecture already documented in `AI_CONTEXT/`
- Paste entire source files into `AI_CONTEXT/`
- Rewrite documentation unnecessarily
- Refactor unrelated code
- Investigate unrelated bugs unless they block the current task

**DO:**
- Start from `TASK.md`
- Use `FILE_INDEX.md` to locate likely files
- Use `ARCHITECTURE.md` to understand responsibilities
- Inspect only relevant source files
- Use `git diff` / `git status` to understand recent changes
- Update `CURRENT_STATE.md` when work changes state
