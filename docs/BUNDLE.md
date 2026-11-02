# One download for all the games (plan agreed, not built)

Goal (owner, 2026-11-01): the friend gets **one installer** with every game: Scholomance Survival
(`C:\Claude\Projects\WoW-Roguelike`), Warband (this repo) and future ones, and one launcher that
lists them. Later, **one small update file** keeps everything current.

Starting point: `WoW-Roguelike/docs/PACKAGE.md` (Inno Setup installer, C# launcher, portable MySQL,
prebuilt clean database, client-data extraction from the friend's own client, small update files,
licences). This plan extends it to several games.

## Decisions (owner, 2026-11-01)
1. **Two server builds.** Scholomance keeps AzerothCore `master` + mod-ale; Warband keeps the
   playerbots fork + mod-playerbots + mod-ale. About 45 MB more, but nothing has to be re-tested.
2. **A new private repo**, `wow-games-bundle`. It holds the launcher, the installer script and the
   build scripts, and pulls each game's files from its own repo. Each game repo stays about its own
   game. A future game is one new entry in a list (`games.json`).
3. **One update file for everything**: `WoWGames-Update-<version>.exe`, carrying only what changed
   in any game.
4. Proposed (not asked): **one game at a time.** The launcher starts the game you pick and stops it
   when WoW closes. The ports are already separate (Warband 3724/8085, Scholomance 3725/8086), so
   running two at once stays possible later; it just uses more memory.

## What the friend gets
- `WoWGames-Setup.exe`. Setup asks for the install folder, their WoW 3.3.5a folder, and one account
  name and password (made in **every** game's login database).
- One extraction of their client's map data, shared by all games. One `AIO_Client` addon.
- One portable MySQL on 127.0.0.1:3310. Each game has its own databases (`acore_*` for Scholomance,
  `warband_*` for Warband, a new prefix per future game).
- The **WoW Games** launcher: a list of the games with their version and a Play button each. Play
  starts that game's servers, sets `realmlist.wtf` to that game's port, opens WoW, and stops the
  servers when WoW closes.

```
WoWGames\
  WoWGames.exe            launcher, also does --setup and --update
  mysql\                  one MySQL, all games' databases
  data\                   the friend's extracted dbc/maps/vmaps/mmaps (shared)
  games\
    scholomance\  server\ (master build)     configs\  lua_scripts\  sql\  version.txt
    warband\      server\ (playerbots build) configs\  lua_scripts\  sql\  version.txt
  addon\AIO_Client\
  licenses\  SOURCE.txt
```

## Updates (the easy pathway)
1. The owner runs one build command in the bundle repo. It compares each game with the version the
   friend has (the last release, kept in the repo) and packs only what changed into
   `WoWGames-Update-<version>.exe`. Usually a few MB: scripts, configs, SQL, the addon. A server
   program is only included when that game's C++ changed.
2. The friend double-clicks it (from anywhere; it finds the install). It stops any running server,
   replaces the changed files, and runs only the **new** SQL files for each game. Each game's
   database has a small table listing the SQL files already applied, so characters, companies,
   heroes and meta-progression all stay.
3. An update can also add a **whole new game**: its server folder, its databases (made empty, then
   filled), and its entry in the launcher list.
4. The full installer also works as an update for big changes (same install id).
5. If an update fails halfway, it puts the old files back from a backup it made at the start, and the
   launcher shows what went wrong.

## Build order (each step testable)
1. Make the `wow-games-bundle` repo; `build-bundle.ps1` stages both games (servers, configs,
   scripts, trimmed MySQL, clean prebuilt databases). Test: start each game by hand from the staging
   folder and log in.
2. The launcher's game list and Play button. Test: play each game from it.
3. `--setup`: shared extraction, addon, account in every game. Test on a fresh folder.
4. The installer (Inno Setup). Test on a fresh Windows user.
5. `--update` and the update builder. Test: install the previous version, update, check characters
   and progress in both games survived.

Licences as in PACKAGE.md, plus mod-playerbots (check its licence in its repo when building) and
the playerbots fork's commit in `SOURCE.txt`.
