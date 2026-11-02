# Warband progress

## Current phase

**Phase 5: Death's door and permadeath** — built 2026-11-01, automated tests 117/117 (with the
restart test), **waiting for the owner's in-game test** (`docs/TEST-QUEUE.md`, test 5). In-game
tests 2-4 are also still queued.

- [x] Death's door (`wb_death.lua`), first version as decided: on a mission, someone at 0 health is
      Downed; their body can be saved for 45 s by a resurrection spell, or by the fight ending
      (nobody in the party in combat for 3 s, and down at least 3 s), which brings them back at 30%
- [x] A saved hero is **wounded** (-10% max health, shown as an aura) until treated for gold or
      after sitting out a mission
- [x] **Permadeath**: a hero who bleeds out, or goes down while wounded, dies for good: off the
      roster, onto the **memorial wall** (`warband_memorial`: name, level, class, missions survived,
      how they died), bot sent away. Their gear stays on the body for a future Recover the Fallen
- [x] **Commander**: can't die for good. Bleeds out = the mission fails, they wake up in the hamlet
      wounded, heroes still down are carried home wounded. **Wipe** (everyone down at once) = the
      mission fails and every downed hero is lost. A failed mission gives survivors 25% XP
- [x] A downed ghost can't reclaim its corpse or use a spirit healer; dead heroes can't come back
- [x] Anyone still down when a mission ends well is carried home (revived, wounded)
- [x] Treatment: `.warband treat NAME|me`, and Treat buttons in the window (20 + 2 gold per level)
- [x] Window: wounds on hero cards with a Treat button, your own wound in the Roster header,
      new **Memorial** tab
- [x] **Fixed a bug from phase 4**: the 10% kill-XP cut never actually applied (the error wrapper
      `Log.Safe` crashed on Lua 5.2's missing `unpack` and lost every handler's answer). Tests now
      check the XP really gained.
- [ ] Owner: in-game test

## Phase 4: Mission XP and Act I — built 2026-11-01

Automated tests passed (82/82; the kill-XP check was too weak, see phase 5); the owner's in-game
test (`docs/TEST-QUEUE.md`, test 4) is waiting.

- [x] Act I contracts (`Config.dungeons`): Ragefire Chasm, Wailing Caverns, the Deadmines,
      Shadowfang Keep, each in Short / Medium / Long (the Deadmines' Long run is the gate):
      | Dungeon | Short | Medium | Long |
      |---|---|---|---|
      | Ragefire Chasm | Oggleflint | Taragaman the Hungerer | Bazzalan |
      | Wailing Caverns | Lady Anacondra | Lord Pythas | Verdan the Everliving |
      | The Deadmines | Rhahk'Zor | Gilnid | (gate: Edwin VanCleef) |
      | Shadowfang Keep | Rethilgore | Baron Silverlaine | Archmage Arugal |
- [x] Board (`wb_board.lua`, table `warband_board`): 3 contracts that fit the commander's level,
      different dungeons where possible, kept until the next mission ends (and through restarts)
- [x] Act progress (`warband_company.progress`): 4 main missions, then the gate is offered; beating
      it opens the next act (Act II isn't built yet, so the board keeps offering Act I)
- [x] XP (`wb_xp.lua`): kills give 10%; a completed mission gives the commander and every hero who
      went about Short 1.5 / Medium 2 / Long 2.5 / gate 3 levels' worth; abandoning gives a quarter;
      nobody passes the act's level cap (20 in Act I)
- [x] Heroes level up properly: new class spells and talent points spent along their spec
- [x] Every embark is a fresh copy of the dungeon (old saved copies are forgotten)
- [x] Window: act line ("Act 1: The Hamlet - main missions 1 of 4, then the gate (level cap 20)"),
      gate contracts marked, XP explained under Rewards
- [ ] Owner: in-game test

## Phase 3: Tavern and roster — built 2026-11-01

Automated tests passed (48/48); the owner's in-game test (`docs/TEST-QUEUE.md`, test 3) is waiting.

- [x] Hero pool: 500 playerbots characters (all classes, both factions) moved to the WBHEROES
      account (`sql/updates/002_hero_pool.sql`); commander accounts are linked to it so they can
      command its characters as bots
- [x] Mixed-faction groups allowed (`AllowTwoSide.Interaction.Group/Chat = 1`): tested with an
      Undead warrior in a Human commander's party
- [x] Tavern (`wb_tavern.lua`, table `warband_recruits`): founding batch of 6 (a tank and a healer
      guaranteed), first 4 free; after every mission 4 new recruits for gold, 4 levels under the
      roster average (minimum 10); each with class, spec, role, one good and one bad trait, backstory
- [x] Roster (`wb_roster.lua`, table `warband_heroes`): 4 slots; call heroes to the party / send them
      to the barracks; a hero's first login sets it up (level, spells, gear, the recruited spec);
      party heroes come back when the commander logs in, also after a restart; missions counted
- [x] Embark needs at least `Config.heroes.min_party` heroes (1 for now, the design says 4) and no
      bots from outside the company
- [x] Maude Ashby (9100001), tavern keeper in Raven Hill (`sql/updates/003_tavern_npc.sql`)
- [x] Window: new Roster and Tavern tabs with hero cards (class icon, level, race, spec, role,
      traits with tooltips, backstory, status, Call/Send/Hire buttons)
- [x] Chat: `.warband roster`, `.warband tavern`, `.warband hire/call/send NAME`
- [ ] Owner: in-game test (window look, hiring, calling heroes, a mission with heroes)

## Phase 2: Hamlet lockdown and mission teleport — built 2026-11-01

Automated tests passed (34/34); the owner's in-game test (`docs/TEST-QUEUE.md`, test 2) is still
waiting.

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

- Death outside missions (e.g. in the hamlet) isn't special: release and resurrect the normal way.
- Ironman (commander death ends the campaign) isn't built yet (difficulty tiers, phase 13).
- A dead hero's bag items should go to the armory: comes with the armory (phase 6).
- The wound aura's tooltip says "Wither Strike" (the spell it borrows); the window says "Wounded".
- Monsters still drop coin (the closed economy's "no monster coin" comes with the economy, phase 6).
- Starter gear for new commanders isn't given yet: they keep their level-1 clothes (phase 6, armory).
- Heroes who sit out a mission get no XP yet (the Training Yard's bench XP is phase 11).
- Heroes keep the gear they were set up with; it goes stale as they level (armory, phase 6).
- Shadowfang Keep's Medium and Long runs need the courtyard door opened by talking to the
  prisoner after Rethilgore (Sorcerer Ashcrombe / Deathstalker Adamant); the Deadmines' gate needs
  the cannon used on the big door. The commander has to do those by hand; bots won't.
- Company gold only changes by hiring (start 150, recruits cost 40 + 4 per level); missions pay
  nothing yet (phase 6). Traits are rolled and shown but do nothing yet (phase 7).
- The hero pool shrinks by every hero who dies or retires. 500 is plenty for now; re-running
  `sql/updates/002_hero_pool.sql` (server stopped) tops it up from playerbots' new characters.
- Act I dungeons are tuned for levels 13-25 and a commander starts at 10, so the first missions are
  hard: the board only offers what the commander's level is ready for (Ragefire and the Deadmines'
  Short at 10). Balance comes once we've played it.

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
| 2026-11-01 | Tavern shows 4 recruits (more with upgrades); a new company picks 4 of 6 founding recruits for free | Owner's choice |
| 2026-11-01 | Heroes are playerbots' ready-made characters, moved to the WBHEROES account | On playerbots' own AddClass accounts a bot is re-rolled (level, gear) whenever it logs in more than 3 levels from its master, which would wipe heroes |
| 2026-11-01 | Mixed Alliance/Horde groups allowed in worldserver.conf | The design's tavern has all races of both factions |
| 2026-11-01 | Embarking needs 1 hero for now (`min_party`), not 4 | Easier testing while the tavern is new; raise to 4 when Act I is playable |
| 2026-11-01 | New heroes get playerbots' auto-gear (green quality) when first set up | Until the armory (phase 6) decides how heroes get gear |
| 2026-11-01 | Mission XP counted in "levels at your current level": Short 1.5, Medium 2, Long 2.5, gate 3 | Averages the design's ~2 levels per main mission; longer runs pay more, as the design says (my numbers, all in `Config.xp`) |
| 2026-11-01 | **Level cap per act** (Act I: 20) until the gate is beaten | My addition: stops side missions and repeats from over-levelling an act (one line in `Config.acts` to change) |
| 2026-11-01 | Mission ends at a target boss per length (table above); Wailing Caverns' Long ends at Verdan, not Mutanus | Mutanus only appears after an escort event bots can't be relied on for |
| 2026-11-01 | The board offers 3 main missions for now | Side missions (the other 2-4 slots) come with mission types in phase 10 |
| 2026-11-01 | "The fight ending saves them" = nobody alive in the party in combat for 3 s (and down at least 3 s) | The design names the rule but not how to detect it; numbers in `Config.death` |
| 2026-11-01 | A commander who bleeds out fails the mission (wakes up home, wounded); the commander isn't wounded by being downed and saved | The design only covers the wipe case for the commander |
| 2026-11-01 | The commander's wound heals after the next mission that doesn't fail, or with treatment | A commander can't "sit out" a mission like a hero |
| 2026-11-01 | Wound = the client's "Wither Strike" aura (-10% max health) made permanent | A ready-made spell the client can show; a custom "Wounded" spell would need client patches |
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
| Phase 5: death tests with `.wbdev down / bleed / clear / revive` (2026-11-01) | Deaths, saves, wipes in seconds instead of real fights | Lesson: check the real effect (XP gained, alive), not just what the script computed: a weak check hid the kill-XP bug for a phase |
| Phase 3 scenario: tavern, hiring, calling heroes, a mission with a hero (2026-11-01) | Whole suite 48 checks in about 5 minutes | Switch on the parallel lanes from the Scholomance bot (already in `wb_testbot.py`) once a run passes ~8 minutes |
