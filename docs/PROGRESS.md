# Warband progress

## Current phase

**Phase 1: Server foundation** (started 2026-11-01). Goal: AzerothCore + playerbots + Lua
running; you can group with bots and run a dungeon.

- [x] Project folder and git repo (`C:\Claude\Projects\Warband`)
- [x] Design converted to `docs/warband-design.md`, open decisions answered
- [x] Download the playerbots AzerothCore fork + mod-playerbots + mod-ale
      (`C:\Claude\Projects\azerothcore-warband`)
- [x] Build it (2026-11-01)
- [x] Create Warband's own databases (owner, 2026-11-01)
- [x] Configs: own databases, random bots off, Lua on, client data (reused from the Scholomance server)
- [x] First start (2026-11-01): databases filled, `[Warband] Lua scripts loaded.`, playerbots
      initialized, no random bots online. Ready in about 1 minute.
- [ ] Owner: GM account, log in, add bots with `.playerbots bot addclass`, run a dungeon

## Notes from the first start

- Playerbots made **50 "AddClass" accounts with 500 offline characters** on first start
  (`Playerbots.AddClassAccountPoolSize`). `.playerbots bot addclass <class>` pulls one of them into
  your group and sets it to your level if it's more than 3 levels off. This is a ready-made pool
  for heroes (phase 3).
- AddClass picks bots of **your own faction**. The design wants both factions' races in one
  company, so phase 3 has to check playerbots' cross-faction grouping options.
- Playerbots also opens a "command server" on port 8888 (local only, unused by us).
- [x] Private GitHub repo: github.com/peep002/wow-warband

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
| 2026-11-01 | Tavern: all 9 non-DK classes, all races of both factions; death knights from the Outland act (Act VI since the switch to seven acts) | Mercenary band; DKs start at 55 |
| 2026-11-01 | **7 acts of 10 levels**, 5 main missions each (gate is the 5th; 35 total), ~2 levels per main mission, ~30–35 hours | 3–4 levels per mission felt cheesy; 10-level acts match WoW's dungeon brackets, so no monster scaling is needed |
| 2026-11-01 | Side missions give ~10% XP and raise a **threat clock** (harder main missions, forced crisis at max, reset by the gate); board = next main + 2–4 sides | A little XP so they're not wasted time; the clock stops endless farming |
| 2026-11-01 | Wounds heal at the Infirmary or free after sitting out one mission | Stops half the roster being one mistake from permadeath |
| 2026-11-01 | Death's door v1 = real death + 45 s revive window (Lua); permadeath loses equipped gear + relics, bags go to the armory | Buildable without C++; revisit if it feels wrong |
| 2026-11-01 | Commander: new non-DK character set to 10 on first login; one company per commander | |
| 2026-11-01 | No monster coin; items sell only at the hamlet vendor | Closed economy, easy to balance |
| 2026-11-01 | Armory suggests upgrades with an "equip all" button; nothing automatic | |
| 2026-11-01 | **Real windows (AIO), classic WoW panel style, built in each system's phase.** Opened by hamlet NPCs, a minimap Warband button, and chat commands; NPC text menus only as a backup | The owner wants clear, good-looking menus, unlike the text menus in the Scholomance project |

## Design problems to settle (raised, not yet decided)

- **Gear goes stale in a few missions.** Option: a blacksmith tier every 5 levels.
- **Names for Acts II–V and the Act II and IV gate missions** are first suggestions.
- **Moved to fit seven acts (check with owner):** death knights from Act VI (Outland); building
  level 2 upgrades in Act III and level 3 in Act V.

## Testing improvements

Nothing tried yet.
