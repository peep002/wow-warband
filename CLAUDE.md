# CLAUDE.md — Warband

Warband is a Darkest Dungeon / XCOM-style roguelite game mode for a World of Warcraft (WotLK 3.3.5a) private server. The player commands a roster of bot heroes on dungeon missions from level 10 to 80, and heroes can die permanently.

**The full design is in `docs/warband-design.md`. It is the source of truth for every rule, number and system.** Read it before starting any phase. If the design and this file disagree, this file wins on *how we work*; the design wins on *what the game does*.

**Start of every session:** read `docs/PROGRESS.md` (where we are, decisions, known issues), then run `git status` and `git log --oneline -10`.

---

## Priorities (in order)

1. **Make the game work.** A playable, fun Warband mode is mission number one.
2. **Keep it self-contained.** Warband runs on its own server with its own databases. It is **not** merged into the Scholomance Survival server (owner's decision, 2026-11-01).
3. **Improve the bot test network when it helps.** Speeding up testing is useful but never more important than the game itself. See "Bot test network" below.

When priorities conflict, the higher one wins.

---

## About the owner

- **I can't code.** You write all code, SQL, config and scripts. Never ask me to edit code by hand.
- After every step, explain **what you did and why** in plain language, short and concrete. Explain technical terms (database, module, compile, hook, aura) briefly the first time they come up.
- When I need to do something (run a command, launch the game, test in-game), give me **exact copy-paste commands** and **numbered in-game steps**, and tell me what I should see if it worked.
- I prefer **free tools and software only**. No paid services or subscriptions.
- If something is unclear, ask me one clear question rather than guessing on anything that's hard to undo.
- **Passwords:** never ask for one, and never type one into a command. Give me the command and let me type the password myself.
- Before anything destructive (deleting a database, wiping characters, force-pushing), stop and ask.

---

## Inherited conventions (from WoW-Roguelike, `C:\Claude\Projects\WoW-Roguelike`)

That project is the Scholomance Survival server. We copy what works from it, but never share files or databases with it.

- **Server setup:** native Windows build, no Docker. MySQL 8.4 runs as the Windows service `MySQL84` (`C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe`, often not on PATH). Visual Studio 2022 Community, Boost 1.81 (`C:\local\boost_1_81_0`), OpenSSL 3.6. Servers run in Terminal-panel tabs so the owner can type GM commands into the worldserver console. Its own notes: `WoW-Roguelike\docs\DEV-ENVIRONMENT.md`.
- **Branches / modules / versions:** that server uses AzerothCore `master` + **mod-ale** (the current name of Eluna; mostly but **not 100% Eluna-compatible**, so check mod-ale's docs for API names). No playerbots. **Warband** uses the playerbots fork instead: `github.com/mod-playerbots/azerothcore-wotlk` branch `Playerbot`, plus `mod-playerbots` and `mod-ale`, in `C:\Claude\Projects\azerothcore-warband` (never committed here). AIO (`github.com/Rochet2/AIO`) works on mod-ale for custom windows.
- **Folder and naming conventions:** all tuning numbers in one config file; one system per file; SQL files numbered in order. mod-ale requires Lua file names to be **unique across all folders**, so every Warband Lua file starts with `wb_` (e.g. `wb_config.lua`, `wb_roster.lua`). Custom IDs (creatures, items, objects, gossip) start at **9100000** for Warband.
- **How to start, stop and rebuild:** start authserver first, then worldserver, each with the run folder as working directory (configs load from `configs\` relative to it). Stop worldserver with `server shutdown 1` at the `AC>` prompt; Ctrl+C stops authserver. Reload Lua without a restart with `.reload ale` (in game, GM) or `reload ale` (console). Rebuild only when C++ or modules change (20–60 min, run in the background, stop the servers first). Details for this server go in `docs/DEV-ENVIRONMENT.md`.
- **Bot test network summary:** `tools/rl_testbot.py` in WoW-Roguelike is a headless Python game client for `127.0.0.1` only. It logs in on throwaway GM accounts (logins in a git-ignored `*.local.json`), makes fresh characters, types chat and GM commands, reads replies and NPC menus, clicks menu options, and prints PASS/FAIL per check. A Lua "probe" script on the server prints state for it to read. It runs several tests in parallel lanes (one bot account per lane); a full run of ~380 checks takes a few minutes. **It can't see the screen, walk, or aim**, so Warband tests teleport the commander with GM commands and let the playerbots fight. Also: `ale_sim.lua` loads all Lua with a fake mod-ale for an offline smoke test, and `luajit -bl file.lua` checks syntax.
- **Habits:** in-game tests that need the owner are queued in a test list and done in batches (the owner is often away from the gaming PC). Every server config change made outside this repo is logged in `docs/DEV-ENVIRONMENT.md`. Commit after each working step.

---

## Technical setup

- **Server:** AzerothCore (WotLK 3.3.5a), playerbots branch, with **mod-playerbots** and **mod-ale** (Lua). Add **mod-autobalance** when raids are built (Phase 12), or earlier if dungeon levels don't fit the leveling pace.
- **Language:** Lua for game rules wherever possible, because it's easier for me to read and reloads without a rebuild. Use C++ only when Lua genuinely can't do the job, and tell me when and why before doing it.
- **State:** all Warband data lives in custom tables prefixed `warband_` (see the design doc for the first-pass list).
- **UI:** chat commands first (`.warband roster`, `.warband armory`, etc.). An addon using the **AIO** framework comes later.
- **Hardware:** built and tested first on the owner's Windows gaming PC; later moved to the home server (a Dell Optiplex running Linux). Warband only needs about 5–10 active bots, so random world bots are off.
- **Never touch the Scholomance Survival server's databases, characters or config.**

### Project layout

```
docs/            warband-design.md, PROGRESS.md, DEV-ENVIRONMENT.md
lua_scripts/
  warband/
    wb_config.lua   every tuning number in one place (XP, costs, stress, timers, drop rates)
    core/           shared helpers (database access, messaging, logging)
    systems/        one file per system: wb_roster, wb_missions, wb_stress, wb_deathsdoor, ...
sql/
  base/          creates warband_* tables (safe to re-run)
  updates/       numbered changes, applied in order
addon/           AIO client addon (later)
tests/           bot test network scenarios for Warband
tools/           helper scripts (reset test data, backups, packaging)
```

---

## Code rules

- **All tuning numbers go in `wb_config.lua`.** XP rates, costs, stress values, timers, drop chances. Balancing should never require hunting through logic.
- **One system per file**, small and readable. Comment the *why*, not just the *what*, in plain language I could follow.
- **SQL is safe to re-run** (`CREATE TABLE IF NOT EXISTS`, guarded updates). Every schema change gets a numbered file in `sql/updates/`.
- **Don't modify AzerothCore core files.** Use Lua hooks, modules and config. If a core change seems necessary, stop and explain the options first.
- **Keep Warband removable.** Disabling it should be as simple as turning off its scripts and leaving its tables alone.
- **Log important events** (hero downed, hero died, mission start/end, loot awarded) to a Warband log so bugs can be traced without me describing them perfectly.
- **Never use real accounts or passwords in code or tests.** Use generated test accounts and characters only.
- **Never put Blizzard files in this project** (no client, no extracted dbc/maps/vmaps/mmaps).

---

## How we work

- **Follow the 13 build phases in the design doc**, one at a time. Phases 1–6 produce a playable Act I; prioritize getting there.
- **Every phase ends with something I can test in-game.** Finish each phase with:
  1. A plain-language summary of what changed.
  2. Exact steps for me to test it in-game, and what I should see.
  3. What the automated tests checked (see below).
  4. Then **wait for my feedback** before starting the next phase.
- **Keep `docs/PROGRESS.md` up to date:** current phase, what works, what's broken, known issues, and decisions I've made. I should be able to read it and know exactly where we are.
- **If something in the design is impractical**, stop and explain the problem and the options. Don't quietly change the design.
- **If you're unsure how AzerothCore, playerbots or mod-ale handles something**, check the docs or source code instead of guessing, and tell me you were unsure.
- **Prefer small, working steps** over large changes. If a change touches more than a few systems, describe the plan first.

### Definition of done for a feature

- It works in-game in a real test.
- It survives a server restart (state saved and reloaded).
- Its numbers come from `wb_config.lua`.
- It's covered by at least one automated scenario where practical.
- `PROGRESS.md` is updated.

---

## Bot test network

We'll adapt the headless test bot from WoW-Roguelike (copied, not shared) to test Warband automatically so I only need to do the final in-game check.

**Use it for:**
- Running a hired party of bots through a short mission and checking it completes.
- Forcing deaths to test death's door, wounds and permadeath.
- Checking stress changes, loot going to the armory, XP grants and level-ups.
- Restart tests: create state, restart the worldserver, confirm everything reloads.

**Making testing faster (secondary priority).** When it's cheap to do, look for improvements and **propose them to me before making big changes**. Ideas: scenario setup with GM commands, database snapshots, hot reloading Lua (`.reload ale`), avoiding unnecessary rebuilds, short test dungeons, seeded randomness, readable pass/fail results with Warband log lines, parallel scenarios.

Keep a short "Testing improvements" list in `docs/PROGRESS.md` with what was tried, how much time it saved, and what's next.

---

## Glossary (for explaining things to me)

- **Worldserver / authserver:** the two server programs. Auth handles logins; world runs the game.
- **Realm:** one game world listed on the login screen.
- **mod-ale (Eluna):** lets the server run Lua scripts that react to game events.
- **Hook:** a point where our script gets told something happened (a kill, a level-up, a login).
- **Aura:** a buff or debuff. We use hidden auras to apply traits, stress effects and modifiers.
- **Gossip menu:** the clickable dialogue menu when you talk to an NPC.
- **Migration / update file:** a numbered SQL file that changes the database in a safe, repeatable way.
