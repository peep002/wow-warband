# Dev environment (the owner's Windows PC)

Where Warband's server lives and how to run it. Set up starting 2026-11-01.
Shared with the Scholomance Survival project: MySQL 8.4, Visual Studio 2022, Boost, OpenSSL and
the WoW client (see `C:\Claude\Projects\WoW-Roguelike\docs\DEV-ENVIRONMENT.md`). Nothing else is
shared.

## Where things are

| What | Path |
|---|---|
| This project | `C:\Claude\Projects\Warband` |
| AzerothCore, playerbots fork (+ `modules\mod-playerbots`, `modules\mod-ale`) | `C:\Claude\Projects\azerothcore-warband` |
| Server programs (the "run folder") | `C:\Claude\Projects\azerothcore-warband\build\bin\Release` (after the build) |
| Databases | `warband_auth`, `warband_characters`, `warband_world`, `warband_playerbots` (MySQL user `acore`) |
| WoW 3.3.5a client | `C:\Claude\Downloads\ChromieCraft_3.3.5a` (shared) |

Both servers can run at once (2026-11-01): Warband uses ports 3724 / 8085, the Scholomance server
was moved to 3725 / 8086. The WoW client's realmlist decides which one you log in to
(`127.0.0.1` = Warband, `127.0.0.1:3725` = Scholomance); the launcher's Play buttons set it.

## Source versions

| Repo | Branch | Commit |
|---|---|---|
| github.com/mod-playerbots/azerothcore-wotlk | Playerbot | 93333d6 (downloaded 2026-11-01) |
| github.com/mod-playerbots/mod-playerbots | master | 05a1f6f |
| github.com/azerothcore/mod-ale | master | 84b85cc |

Build logs: `build-configure.log`, `build-compile.log` in the AzerothCore folder.

## Building

```powershell
$env:BOOST_ROOT = 'C:/local/boost_1_81_0'
Set-Location C:\Claude\Projects\azerothcore-warband
cmake -S . -B build -G "Visual Studio 17 2022" -A x64 -DTOOLS_BUILD=all `
  -DMYSQL_INCLUDE_DIR="C:/Program Files/MySQL/MySQL Server 8.4/include" `
  -DMYSQL_LIBRARY="C:/Program Files/MySQL/MySQL Server 8.4/lib/libmysql.lib"
cmake --build build --config Release --parallel
```

20–60 minutes. Only needed when C++ or modules change, not for Lua or SQL.

## Creating the databases (once)

`tools/create-databases.sql` makes the four empty databases. It needs the MySQL root password,
which only the owner types.

## Changes made to server files (outside this repo)

Keep this list current. These are lost if the run folder is wiped.

- Copied next to the .exe files from the Scholomance run folder: `libmysql.dll`, `libssl-3-x64.dll`,
  `libcrypto-3-x64.dll`, `legacy.dll` (the servers refuse to start without `legacy.dll`).
- `configs\*.conf` made from the `.conf.dist` files (2026-11-01):
  - `worldserver.conf`, `authserver.conf`, `dbimport.conf`: databases `warband_auth`,
    `warband_world`, `warband_characters`; `SourceDirectory` = `C:/Claude/Projects/azerothcore-warband`;
    `MySQLExecutable` = full path to `mysql.exe`.
  - `worldserver.conf`: `DataDir` = `C:/Claude/Projects/azerothcore/build/bin/Release/data`
    (**reuses the Scholomance server's extracted client data**, read only; same AzerothCore base).
    `AccountInstancesPerHour` = 1000, `CharacterCreating.MinLevelForHeroicCharacter` = 0.
  - `modules\playerbots.conf`: `PlayerbotsDatabaseInfo` → `warband_playerbots`;
    `Playerbots.RandomBotAutologin` = 0, `Playerbots.MinRandomBots` = 0, `Playerbots.MaxRandomBots` = 0
    (no random world bots; heroes only).
  - `modules\mod_ale.conf`: `ALE.TraceBack = true` (Lua errors show the line).
- `lua_scripts\AIO_Server` is AIO's server half (custom windows), copied from
  `C:\Claude\Projects\thirdparty\AIO\AIO_Server` (commit 087e279, same as the Scholomance server).
  The client half (`Interface\AddOns\AIO_Client`) is already in the shared WoW client.
- `worldserver.conf`: added `Logger.ALE=4,Console Server` so Lua engine messages reach Server.log.
  Note: `.reload config` empties Server.log and it stays empty until the next restart, so restart
  instead of reloading the config when you need the log.
- `lua_scripts\warband` is a **junction** (folder link) to `C:\Claude\Projects\Warband\lua_scripts\warband`,
  so edits in the repo are live after `.reload ale`. Recreate with:
  `New-Item -ItemType Junction -Path '<run folder>\lua_scripts\warband' -Target 'C:\Claude\Projects\Warband\lua_scripts\warband'`

## Starting and stopping

**Easiest: `ServerLauncher.exe` on the Desktop** (source: `tools/server-launcher/`, rebuild with
`tools/server-launcher/build.ps1`). Start/Stop and Play buttons for both servers (Play points
the WoW client at that server, then launches it).
Stopping = Ctrl+C in the server's console, which saves every
player before exiting. The servers open in their own console windows (type GM commands there).
From a script: `ServerLauncher.exe --status`, `--start warband`, `--stop scholomance`.
(Don't call it with PowerShell's `Start-Process -Wait`: that waits for the servers to exit too.)

By hand: authserver, then worldserver, each in its own
Terminal tab, working directory = the run folder:

```powershell
Set-Location 'C:\Claude\Projects\azerothcore-warband\build\bin\Release'; .\authserver.exe
Set-Location 'C:\Claude\Projects\azerothcore-warband\build\bin\Release'; .\worldserver.exe
```

Stop worldserver with `server shutdown 1` at `AC>`; Ctrl+C stops authserver.

## Our SQL applied to this PC's databases

| File | Database | Applied | Undo |
|---|---|---|---|
| `sql/base/001_warband_tables.sql` | warband_characters | 2026-11-01 | `DROP TABLE warband_company, warband_missions, warband_log` (forgets every company) |
| `sql/updates/001_hamlet.sql` | warband_world | 2026-11-01 | `sql/undo/001_hamlet_undo.sql` |

Apply with: `& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u acore -pacore <database> -e "source sql/...sql"`
(from this project folder). Creature changes need a worldserver restart.

## Testing

- `python tools/wb_testbot.py run` (servers running, from this folder): makes a fresh commander on
  the WBTESTBOT account and plays `tools/wb_testbot_scenario.py`, printing PASS/FAIL. About 4 minutes.
  Add `restart` to also restart the worldserver mid-mission (about 2 minutes more). `-v` shows chat.
- Test accounts WBTESTBOT, WBTESTBOT2-4 (GM 3), logins in `tools/wb_testbot.local.json` (git-ignored).
  Made by `python tools/wb_testbot.py make-account`.
- `.wbdev ...` read-outs for the bot: `lua_scripts/warband/dev/wb_dev_probe.lua`.
- Lua errors in hook handlers wrapped with `Log.Safe` land in `warband_log` as `lua_error`.
- Gotchas: a level-10 test commander dies fast, and dead players can't talk to NPCs, so the bot
  uses `.cheat god on`. Talking to an NPC needs about 5 yards; `.wbdev gonpc ENTRY` jumps next to
  it. After reconnecting, list characters before entering the world.
