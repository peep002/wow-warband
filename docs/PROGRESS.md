# Warband progress

## Current phase

**Phase 2: Hamlet lockdown and mission teleport** — built 2026-11-01, automated tests 34/34,
**waiting for the owner's in-game test** (`docs/TEST-QUEUE.md`, test 2).

- [x] Commanders: a new character's first login → level 10, class spells, no hearthstone, sent to
      Raven Hill, company row in `warband_company` (`wb_company.lua`). Not death knights, never bots.
- [x] Class spells learned automatically on every level-up, from the class trainers' lists (`wb_spells.lua`)
- [x] Raven Hill cleared of its own NPCs (reversible, `sql/updates/001_hamlet.sql`); Sergeant Marlow
      (9100000) keeps the mission board
- [x] Lockdown: back to the hamlet when you leave it, back to the entrance when you leave the
      mission's dungeon; no AH, mail, guild bank, trading, flight paths, hearthstone, selling (`wb_lockdown.lua`)
- [x] Missions: one fixed contract (Deadmines, Short, ends at Rhahk'Zor); Embark takes you and the
      bots in your group; boss death → "Mission complete" → home after 10 s; `.warband abandon`;
      saved in `warband_missions`, survives a restart (`wb_missions.lua`)
- [x] Warband window (AIO, classic WoW panel style): Missions tab with contract list, details,
      your party and Embark/Abandon; Roster/Armory/Hamlet tabs shown greyed out for later.
      Opens from Marlow, a minimap button, and `.warband` (`wb_ui.lua`, `wb_ui_client.lua`)
- [x] Event log (`warband_log`), including Lua errors from wrapped handlers (`wb_log.lua`)
- [x] Test bot copied and adapted (`tools/wb_testbot.py`, `tools/wb_testbot_scenario.py`)
- [ ] Owner: in-game test of the window and the whole loop

## Phase 1: Server foundation — DONE (2026-11-01)

AzerothCore + playerbots + Lua running; the owner grouped with four AddClass bots and ran a
dungeon (in-game test passed 2026-11-01).

- [x] Project folder and git repo (`C:\Claude\Projects\Warband`)
- [x] Design converted to `docs/warband-design.md`, open decisions answered
- [x] Download the playerbots AzerothCore fork + mod-playerbots + mod-ale
      (`C:\Claude\Projects\azerothcore-warband`)
- [x] Build it (2026-11-01)
- [x] Create Warband's own databases (owner, 2026-11-01)
- [x] Configs: own databases, random bots off, Lua on, client data (reused from the Scholomance server)
- [x] First start (2026-11-01): databases filled, `[Warband] Lua scripts loaded.`, playerbots
      initialized, no random bots online. Ready in about 1 minute.
- [x] Owner: GM account, log in, add bots with `.playerbots bot addclass`, run a dungeon (passed)

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

- The Warband server starts in about a minute with its own databases, Lua scripts and playerbots.
- Bots join your group with `.playerbots bot addclass <class>`, match your level, and fight and
  heal in dungeons.
- New characters become level-10 commanders at Raven Hill; the hamlet and mission leash work;
  the Deadmines contract can be taken, finished or abandoned, and survives a restart
  (automated, 34/34 on 2026-11-01). The window itself is not tested yet (the bot can't see it).

## Known issues

- **Commander death isn't handled yet** (phase 5, death's door). For now a dead commander
  releases and resurrects the normal way; the leash leaves dead players alone.
- Monsters still drop coin (the closed economy's "no monster coin" comes with the economy, phase 6).
- Starter gear for new commanders isn't given yet: they keep their level-1 clothes (phase 6, armory).
- Recommended level for the Deadmines contract is 15–20, but commanders start at 10 and there's
  no mission XP yet (phase 4). Bring bots and expect it to be hard, or use `.levelup` for testing.

## Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-11-01 | Warband is its **own server**, not a mode on the Scholomance Survival server | Owner doesn't want to mix them. Also: playerbots needs its own AzerothCore fork, which would have forced the Scholomance server to switch |
| 2026-11-01 | Built first on the owner's Windows PC, moved to the Optiplex later | The PC already has MySQL, Visual Studio and the WoW client; faster to build and test |
| 2026-11-01 | Lua engine is **mod-ale** (the current name of Eluna) | Same as the other project; has recent playerbots compatibility fixes |
| 2026-11-01 | Lua files start with `wb_`; custom IDs start at 9100000; tables start with `warband_` | mod-ale needs unique file names; IDs kept apart from the other project's 90xxxxx to avoid confusion |
| 2026-11-01 | Databases: `warband_auth`, `warband_characters`, `warband_world`, `warband_playerbots` | Fully separate from the Scholomance server's `acore_*` databases |
| 2026-11-01 | Ports: Warband 3724 / 8085; the Scholomance server moved to 3725 / 8086, so **both can run at once** (changed later the same day, from the Scholomance project) | The launcher's Play button sets the client's realmlist for whichever server you pick |
| 2026-11-01 | Commander spells are taught automatically from the class trainers' lists | Closed world: no trainers to visit |
| 2026-11-01 | Raven Hill's own NPCs (Jitters, Bliztik, the invisible Unseen) are hidden | Jitters is Alliance and would attack Horde commanders; Bliztik is a vendor (closed economy) |
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

| Tried | Saved | Next |
|---|---|---|
| Copied the Scholomance test bot, pointed at Warband's databases (2026-11-01) | Phase 2's whole loop is checked in about 4 minutes, 6 with a real restart | Phase 3: hire from the tavern by menu |
| `.wbdev` probe: state read-out, jump next to an NPC, kill the mission boss, wander off | No walking or fighting needed in tests | |
| Lua errors in hooks go to `warband_log` (`Log.Safe`) | Errors readable without the worldserver console | Wrap more handlers as they're written |
| Restart test drives `ServerLauncher.exe --stop/--start` and waits for "ready..." | Restart persistence checked automatically | |
