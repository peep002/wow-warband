# Warband progress

## Current phase

**Phase 1: Server foundation** (started 2026-11-01). Goal: AzerothCore + playerbots + Lua
running; you can group with bots and run a dungeon.

- [x] Project folder and git repo (`C:\Claude\Projects\Warband`)
- [x] Design converted to `docs/warband-design.md`, open decisions answered
- [ ] Download the playerbots AzerothCore fork + mod-playerbots + mod-ale
      (`C:\Claude\Projects\azerothcore-warband`)
- [ ] Build it (background, 20–60 min)
- [ ] Create Warband's own databases (owner runs one command with the MySQL root password)
- [ ] Configs: own databases, random bots off, Lua on, client data
- [ ] First start; log in, add a bot to the group, run a dungeon
- [ ] Private GitHub repo for this project (owner creates it on github.com)

## What works

Nothing yet.

## Known issues

None yet.

## Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-11-01 | Warband is its **own server**, not a mode on the Scholomance Survival server | Owner doesn't want to mix them. Also: playerbots needs its own AzerothCore fork, which would have forced the Scholomance server to switch |
| 2026-11-01 | Built first on the owner's Windows PC, moved to the Optiplex later | The PC already has MySQL, Visual Studio and the WoW client; faster to build and test |
| 2026-11-01 | Lua engine is **mod-ale** (the current name of Eluna) | Same as the other project; has recent playerbots compatibility fixes |
| 2026-11-01 | Lua files start with `wb_`; custom IDs start at 9100000; tables start with `warband_` | mod-ale needs unique file names; IDs kept apart from the other project's 90xxxxx to avoid confusion |
| 2026-11-01 | Databases: `warband_auth`, `warband_characters`, `warband_world`, `warband_playerbots` | Fully separate from the Scholomance server's `acore_*` databases |
| 2026-11-01 | Same network ports as the Scholomance server (3724 / 8085), so **only one of the two servers runs at a time** | The WoW client then needs no realmlist change between them |
| 2026-11-01 | Hub: Raven Hill, Duskwood | Design's proposal |
| 2026-11-01 | Commander can't die for good; optional Ironman mode | Design's recommendation |
| 2026-11-01 | Co-op: separate companies that can visit each other's hamlets | Simpler than a shared company |
| 2026-11-01 | Tavern: all 9 non-DK classes, all races of both factions; death knights from Act IV | Mercenary band; DKs start at 55 |
| 2026-11-01 | 5 main missions per act (25 total) + many optional side missions with **no XP** | Owner wants it "grand-ish" but with a clear spine |

## Design problems to settle (raised, not yet decided)

- **Fast leveling vs fixed dungeon levels.** About 3–4 levels per main mission in Acts I–III means
  each dungeon is the right level for roughly one mission. Option: add mod-autobalance early so
  dungeons scale to the party's level.
- **Gear goes stale in 1–2 missions.** Option: a blacksmith tier every 5 levels.
- **Wounds can snowball.** "Down again while wounded = permadeath" plus gold for only 2–3 heals
  per return. Option: a wound also heals after sitting out one mission.
- **Is the gate mission one of the 5 main missions per act, or a 6th?** Assumed: it's the 5th.
- **Real WoW gold leaks in** (mob coin, vendoring loot). Option: only the hamlet vendor buys items.

## Testing improvements

Nothing tried yet.
