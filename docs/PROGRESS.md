# Warband progress

## Current phase

**Phase 8: stress — built 2026-11-01** (owner: "go ahead" before testing phase 7). Waiting for the
owner's in-game checks: the Act I playtest replay, test 7 (traits) and test 8 (stress) in
`docs/TEST-QUEUE.md`, all in `docs/TEST-SESSION.md`. **Next:** record and fix what the owner finds,
then phase 9 (marks). The bundle plan is settled (`docs/BUNDLE.md`), not built.

## Phase 8: Stress — built 2026-11-01

Automated tests passed: 179/179 with the restart test (2026-11-02).

- [x] `wb_stress.lua`: every hero has stress 0-200, saved (`warband_heroes.stress`, `sql/base/008_stress.sql`).
      The commander has none. All numbers in `Config.stress` (my first guesses, the design gives none):
      | Gain or relief | Stress |
      |---|---|
      | A heavy hit (one blow for 12%+ of max health; stands in for crits), at most every 3 s | +2 |
      | An ally goes down / the commander goes down / an ally dies for good | +8 / +10 / +20 |
      | End of a mission (everyone who went): Short / Medium / Long / gate | +4 / +8 / +12 / +15 |
      | ...abandoned / failed, on top | +10 / +20 |
      | Sat the mission out in the barracks (Restless: +8 instead) | -10 |
      | A drink at the tavern (10 gold + 1 per level) | -40 |
      | Brave | gains x0.75 |
- [x] At 100, a resolve check: 3 in 4 an affliction, 1 in 4 a virtue (stress drops to 50)
      | Affliction | Effect | Virtue | Effect |
      |---|---|---|---|
      | Paranoid | refuses half the heals from others | Stalwart | can't die for good (wounded down = a normal down; bleeding out just keeps them down) |
      | Hopeless | -15% damage (hidden aura) | Courageous | heavy hits don't stress the rest of the party |
      | Selfish | keeps 25% of looted gear; hands it back when cured | Focused | +10% crit (hidden aura) |
      | Fearful | panics below 50% health, once per fight | | |
      | Abusive | after every fight, the other heroes +3 | | |
      An affliction lasts until stress is relieved below 50; a virtue until the end of the mission
      (or of the next one, if it came from the mission's end stress).
- [x] At 200 on a mission: heart attack, straight to death's door (wounded = dies for good), stress 150.
      Off a mission stress stops at 199.
- [x] Hidden auras: `sql/updates/005_stress_spells.sql` (102010 Hopeless, 102011 Focused)
- [x] Brave and Restless work now (their "not active yet" note is gone)
- [x] Window: a stress bar on every hero card (green/yellow/orange/red), the affliction (red) or
      virtue (blue) beside it, a tooltip explaining both, and a **Drink** button. Cards are a bit
      taller; the backstory is one line and gets shorter when more buttons show
- [x] Chat: `.warband drink NAME`; `.warband roster` shows stress. Maude's plain menu offers drinks
- [x] Fixed (found by the tests): a hero who was down when the mission's boss died was carried home
      but got **no mission XP** (a dead character can't gain XP). They're now paid a few seconds after
      being revived at home ("Experience: NAME +... (carried home)"). Failed missions still pay only
      those left standing
- [ ] Owner: in-game test (test 8)

## Phase 7: Traits and personalities — built 2026-11-01

Automated tests passed (144/144 at the time; the restart test passed in the run before, 150/152,
whose two failures were test timing, fixed in the last run).

- [x] `wb_traits.lua`: eight traits work now, each announced in chat with its name in brackets:
      | Trait | What it does now |
      |---|---|
      | Stalwart Shield (tanks) | hidden aura: +10% threat |
      | Glass Jaw | hidden aura: +8% damage taken from melee and ranged crits |
      | Coward | below 20% health in a fight: feared (runs) for 4 s, once per fight |
      | Selfless | an ally under 25% health within 40 yd: the monsters hitting them get enough threat to turn on the Selfless hero, once per fight |
      | Field Medic | someone down for 15 s: back up (wounded, like any save), once per fight |
      | Greedy | 10% per looted weapon/armour: pocketed (kept hidden in the armory table); comes back when that hero dies for good |
      | Clumsy | 20% of fights: 4 s in, the nearest idle visible pack within 30 yd attacks them |
      | Hothead | 25% of fights: 2 s after the fight, the nearest idle visible pack within 40 yd attacks them |
- [x] Pulls never touch bosses, so the mission target can't be pulled early
- [x] Hidden auras are server-only spells in `spell_dbc` (`sql/updates/004_trait_spells.sql`, ids 102000+)
- [x] Six traits wait for later systems and say so in their tooltip ("Not active yet: starts working
      with stress (phase 8)" etc.): Brave, Restless, Hates the Dark, Night Owl, Quartermaster, Lucky
- [x] All numbers in `Config.trait_effects`
- [x] Also fixed: the board could deal three Short contracts (the picker now always mixes dungeons
      and lengths when it can); starter gear could pick items needing a reputation (Tranquillien),
      which can't be worn, so the commander got 5 pieces instead of 7
- [ ] Owner: in-game test (test 7)

- [x] Armory tooltips stuck on "Retrieving item information": items are now pre-fetched (a hidden
      tooltip makes the client ask the server) and the window redraws once they're known
- [x] Contract text ran past the window: wraps now
- [x] Board: only 2 identical contracts at level 10. Level gates lowered and contracts offered from
      one level below their gate (`Config.board.level_stretch`); the board picks different dungeons
      and lengths. At level 10: e.g. Ragefire Long, Deadmines Short, Wailing Caverns Short
- [x] Soft lock after deaths (no gold to hire): every batch now has **free recruits** a few levels
      below the roster and **paid veterans** at the roster's level with blue starting gear and a
      second good trait (`Config.tavern.veterans`, `sql/base/006_veterans.sql`)
- [x] "Was it the whole dungeon?": every contract shows its route ("Short: the start of the dungeon,
      up to Rhahk'Zor. The contract ends when the target dies...") on the board, in the window and
      when embarking
- [x] Found while testing: playerbots' heroes re-equipped spare gear from their bags by themselves,
      and its `autogear` / `maintenance` commands hand out free gear. Turned off (playerbots.conf);
      new heroes keep no spare gear; equipping checks the item really went on

## Phase 6: Shared armory and currencies — built 2026-11-01

Automated tests passed (132/132); first playtest done (see above).

- [x] Armory (`wb_armory.lua`, table `warband_armory`): every weapon and piece of armour the
      commander or a hero loots (or wins in a roll) leaves their bags and goes to the armory, keeping
      its random suffix ("of the Bear"); trade goods become materials; items nobody on the roster
      could ever use are salvaged into materials; quest items, consumables, shirts and tabards stay put
- [x] No coin from monsters: looted money is taken back (all gold comes from the campaign)
- [x] Equipping in the hamlet: you and the heroes in your party; what was worn goes back to the
      armory. Upgrade suggestions (item level x quality, lighter-than-best armour counts less) and
      **Equip all upgrades**. Grey junk is never suggested.
- [x] Selling (the only way items become gold: vendor price / 400) and salvaging (materials by
      quality and item level); **Sell junk**
- [x] A hero who dies for good leaves their green-or-better bag gear to the armory
- [x] Mission rewards: gold and renown (Short 60/4, Medium 90/6, Long 120/9, gate 200/20);
      abandoning pays a quarter of the gold, failing nothing
- [x] New commanders get starter gear: six green armour pieces in their class's armour type and a
      weapon (picked from the item database, level 6-10)
- [x] Window: **Armory** tab (item list with quality colours, item level, slot, upgrade marks and
      the real item tooltip; details with "Give to" buttons showing each person's gain, Sell, Salvage;
      Equip all upgrades, Sell junk). Contracts show their gold and renown.
- [x] Chat: `.warband armory`, `.warband equip ID NAME|me`, `.warband equipall`, `.warband sell ID`,
      `.warband salvage ID`, `.warband selljunk`
- [ ] Owner: in-game test (real looting and coin can't be tested by the bot)

## Phase 5: Death's door and permadeath — built 2026-11-01

Automated tests passed (117/117); the owner's in-game test (`docs/TEST-QUEUE.md`, test 5) is waiting.

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
- Real looting and coin pick-up go through hooks the test bot can't trigger (it can't open corpses);
  the same capture code is tested with simulated loot. Needs the owner's in-game check.
- The armory keeps an item's random suffix but not enchants or gems (dungeon drops rarely have them).
- Upgrade suggestions only look at item level, quality and armour type, not which stats suit the
  class (a warrior may be offered an intellect ring). You always confirm.
- Embarking still needs only 1 hero (`Config.heroes.min_party`); the design says 4.
- The wound aura's tooltip says "Wither Strike" (the spell it borrows); the window says "Wounded".
- Heroes who sit out a mission get no XP yet (the Training Yard's bench XP is phase 11).
- Shadowfang Keep's Medium and Long runs need the courtyard door opened by talking to the
  prisoner after Rethilgore (Sorcerer Ashcrombe / Deathstalker Adamant); the Deadmines' gate needs
  the cannon used on the big door. The commander has to do those by hand; bots won't.
- No food, water, ammo or reagents for the commander until the Provisioner and supplies (phase 10;
  owner's choice, no free stopgap). Only looted consumables. Hunter commanders start with no ammo;
  hunter heroes probably run dry too (playerbots' top-ups are off), not checked yet. Heroes eat and
  drink for free (playerbots' `food` cheat).
- Four traits do nothing yet (Hates the Dark, Night Owl, Quartermaster, Lucky: darkness, supplies,
  chests); their tooltips say so. Stress from darkness, torches and food comes with phase 10.
- Paranoid's refused heals give no message; the heal just does nothing (not checked how it looks in
  the combat log).
- Coward uses a plain "feared" state: the hero runs in a random direction, possibly into another pack.
- Clumsy and Hothead only pull monsters the hero can see; in twisty caves that's sometimes nobody.
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
| 2026-11-01 | **Tavern batches: free recruits + paid veterans** (owner's idea after the playtest). 4 per batch: 2 free, a few levels below the roster; 2 veterans at roster level, blue gear, two good traits, gold | A company that lost heroes was soft-locked with no gold to hire |
| 2026-11-01 | Contracts are offered from one level below their gate, and the board mixes dungeons and lengths | Playtest: 2 identical contracts at level 10 |
| 2026-11-01 | Playerbots' own gear help is off: `AutoEquipUpgradeLoot`, `MaintenanceCommand`, `AutoGearCommand(AltBots)` = 0 | Heroes re-equipped spare gear by themselves; autogear/maintenance hand out free gear and enchants outside the closed economy |
| 2026-11-01 | **One download for all the owner's games** (Scholomance Survival, Warband, future ones) for the friend | Owner's goal; plan in `docs/BUNDLE.md` |
| 2026-11-01 | Bundle: **two server builds** (master for Scholomance, playerbots fork for Warband), a **new repo `wow-games-bundle`**, **one update file** for all games | Owner's answers; nothing to re-test, each game repo stays about its game, the friend gets one file per update |
| 2026-11-01 | **Field Medic changed** (check with owner): "once per fight, gets a downed ally up after 15 s, even mid-fight" instead of "revives 30% faster" | After a fight everyone down is saved automatically within ~3 s, and most resurrection spells can't be cast in combat, so a faster revive would almost never matter |
| 2026-11-01 | **Selfless** acts on an ally *about to go down* (under 25% health), by turning the monsters onto the Selfless hero; no shield | "Downed" heroes are really dead in death's door v1, so nothing can taunt for them; a shield would need a custom spell per level |
| 2026-11-01 | **Stalwart Shield** = +10% threat only | "Never loses aggro to a single crit" is what extra threat does; there's no separate crit rule to hook |
| 2026-11-01 | **Greedy**'s pocketed items come back to the armory when that hero dies for good | Same as their bag gear; the loss stings but isn't forever |
| 2026-11-01 | Glass Jaw covers melee and ranged crits, not spell crits | The server has no working "spell crit damage taken" aura; most dungeon damage is melee |
| 2026-11-01 | **The commander has no stress**; heroes only (owner confirmed 2026-11-02) | The design gives stress to heroes; afflictions on the player's own character would take control away from them |
| 2026-11-01 | Stress numbers (table in phase 8) are first guesses, all in `Config.stress` | The design names the sources but not the amounts; tune after playing |
| 2026-11-01 | "Taking crits" counts as **heavy hits**: one blow for 12%+ of max health | The server doesn't tell scripts which hits were crits |
| 2026-11-01 | **Paranoid** refuses half the heals from others, not all | Refusing every heal would make a Paranoid tank certain to die for good |
| 2026-11-01 | **Selfish** = keeps a quarter of looted gear (like Greedy), returned when cured | "Takes the best armory drop" needs a choice the bot can't make; this reuses Greedy's pocket |
| 2026-11-01 | **Fearful** ("won't hold the gate") = panics below 50% health once per fight, like a stronger Coward | No "gate" to hold in a dungeon fight; running away is the readable version |
| 2026-11-01 | **Courageous** = heavy hits don't stress the rest of the party while they stand; **Stalwart** (virtue) = can't die for good while it lasts | Literal readings of "reduces party stress on crits" and "immune to death's door" in our death system |
| 2026-11-01 | Afflictions last until relieved below 50 stress; virtues last until the end of the mission | Darkest Dungeon's rule, roughly; the design doesn't say |
| 2026-11-01 | Stress relief for now = a drink at the tavern (Maude); the chapel and inn come with the buildings (phase 11) | The tavern is the only relief building that exists |
| 2026-11-01 | **No free rations before phase 10**: food, water, ammo and reagents wait for the Provisioner and mission supplies | Owner's choice; keeps the closed economy as designed |
| 2026-11-01 | Custom spell ids for Warband: 102000-102099 | Like the Scholomance project: a 9100000+ spell id would make the server reserve room for 9 million spells |
| 2026-11-01 | **Materials are one number for now**, not real trade-good items; looted trade goods add 1 each | The design wants real trade goods by tier for crafting; that only matters once the blacksmith exists (phase 11/12), where we'll revisit it |
| 2026-11-01 | Selling turns vendor price into company gold at 1/400 (a level-15 green ~15 gold) | Company gold is counted in whole "gold pieces" sized for mission rewards; real vendor prices would be tiny |
| 2026-11-01 | Only the commander and heroes in the party (online) can be equipped | Offline characters can't be changed safely while the server runs |
| 2026-11-01 | Commander starter gear comes from a database query, not playerbots' factory | The factory is written for bots and could crash the server on a real player |
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
| Phase 7: `.wbdev trait / traitset / aggro / calm / hp` set a trait, force its chance to 100%, start and end fights on demand (2026-11-01) | Every behaviour trait checked in about 3 minutes instead of waiting for random rolls | Lesson: wait for the fight to really start (a far monster walks for a while) before testing health triggers |
| Phase 3 scenario: tavern, hiring, calling heroes, a mission with a hero (2026-11-01) | Whole suite 48 checks in about 5 minutes | Switch on the parallel lanes from the Scholomance bot (already in `wb_testbot.py`) once a run passes ~8 minutes |
