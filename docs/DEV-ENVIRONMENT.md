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

Only one server (Warband or Scholomance) runs at a time: both use ports 3724 and 8085.

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

- (none yet)
