# One download for all the games (plan, not built)

Goal (owner, 2026-11-01): the friend gets **one installer** with every game: Scholomance Survival
(`C:\Claude\Projects\WoW-Roguelike`), Warband (this repo) and future ones, and one launcher that
lists them.

Starting point: `WoW-Roguelike/docs/PACKAGE.md` (Inno Setup installer, C# launcher, portable MySQL,
prebuilt clean database, client-data extraction from the friend's own client, small update files,
licences). Extend it rather than start over.

Open questions for the next session (ask the owner):
1. **One server build or two?** Scholomance runs on AzerothCore `master`; Warband needs the
   playerbots fork. Recommended: build once from the playerbots fork (with mod-ale) and run each game
   as its own worldserver with its own configs and databases (Scholomance with
   `Playerbots.Enabled = 0`). Needs Scholomance's bot suite (~380 checks) to pass on the fork first.
   Alternative: ship both builds (~45 MB more, nothing to re-test).
2. **Where the bundle lives**: a new repo (e.g. `wow-games-bundle`) that pulls each game's files, or
   inside WoW-Roguelike's `launcher/`.
3. Can two games run at once for the friend (separate ports, as on the dev PC), or one at a time?

Shared by all games: one portable MySQL (each game its own databases), one client-data extraction,
the AIO_Client addon, one launcher (pick a game; it sets the realmlist and starts that game's servers).
Per game: its Lua scripts, configs, SQL, and database name prefix.
