# In-game tests waiting for the owner

Tests the bot can't do (it can't see windows, walk or fight). `docs/TEST-SESSION.md` has tests 2-6 as one
ordered walkthrough for a sitting; keep both in step when adding tests. Do them in one sitting when you're at
the gaming PC, then report back what you saw. Results get recorded at the bottom of each test.

## Test 2: the hamlet and the first mission (phase 2)

Before you start: Warband server running (Desktop `ServerLauncher.exe`, Warband **Start**), then
Warband **Play** (it points WoW at Warband and launches it). Log in with your GM account.

1. Create a **new character**, any race and class except death knight, and enter the world.
   - **Expect:** you arrive in Raven Hill (a ruined village in Duskwood) at **level 10**, with a gold
     `[Warband] Welcome to Raven Hill, Commander...` line in chat, and a small **banner button** on the
     edge of the minimap.
2. Type `.gm off` (GM mode switches the hamlet lockdown off for testing).
3. Click the **minimap banner button**.
   - **Expect:** a "Warband" window in the style of WoW's own windows: a title plate on top, a line
     with your company (Commander name, Act 1, gold, renown, materials), the contract
     **Into the Deadmines** on the left, its details on the right (objective, story, rewards, your
     party), an **Embark** button, and four tabs at the bottom (Missions, Roster, Armory, Hamlet).
   - Click **Roster**: a greyed message says it opens in phase 3. Click **Missions** to go back.
   - Press **Escape**: the window closes. Drag its edge: it moves.
4. Type `.warband`: the same window opens. Close it, then talk to **Sergeant Marlow** (the guard in
   the middle of the village): the window opens again, without a text menu.
5. Walk out of the village in any direction (about 110 yards).
   - **Expect:** you're teleported back with "Between missions, the company stays in Raven Hill."
6. Add four bots: `.playerbots bot addclass warrior`, then `priest`, `mage`, `rogue`.
   Optional, for a fairer fight: `.levelup 6` first (level 16), and add the bots after.
   Reopen the window: **Your party** lists them in class colours with their levels.
7. Click **Embark**.
   - **Expect:** you and your bots arrive inside the Deadmines. The window (reopen it) says
     **ON MISSION** and has an **Abandon mission** button instead of Embark.
8. Fight to **Rhahk'Zor**, the first boss (a big ogre, not far in), and kill him.
   - **Expect:** `[Warband] Mission complete! Returning to Raven Hill in 10 seconds.` Then you and
     your bots are back in Raven Hill.
9. Embark again, open the window and click **Abandon mission**.
   - **Expect:** "Mission abandoned..." and everyone is back in Raven Hill.
10. Optional: embark, then **Stop** and **Start** Warband in the launcher, log back in.
    - **Expect:** you're still on the mission, at the Deadmines entrance.

Tell me anything that looks wrong or unclear in the window (a screenshot helps a lot).

Known gaps (not bugs yet): dying isn't handled (phase 5), no starter gear (phase 6), no XP for
missions (phase 4).

**Result:** (waiting)

## Test 3: the tavern and your heroes (phase 3)

Since phase 3, embarking needs heroes from your roster: in test 2, skip the `.playerbots bot addclass`
step and use your heroes instead (steps below). Start with a **new character** so the company is fresh.

1. Open the window (minimap button) and click the **Tavern** tab.
   - **Expect:** "Founding recruits: hire 4 for free" and 6 cards. Each card shows a class icon, the
     name in class colour, "Tank" / "Healer" / "Damage", level, race, spec and class, a green **+** trait
     and a red **-** trait (hover them for what they'll do), a one-line backstory, "Free", and a
     **Hire** button. At least one tank and one healer are among them, and races of both factions.
2. Hire 4 of them. Each disappears from the tavern; after the 4th, the other two leave.
3. Click the **Roster** tab.
   - **Expect:** "Roster: 4 of 4 heroes", your 4 heroes as cards, all "In the barracks", 0 missions.
4. Click **Call to party** on two or three of them.
   - **Expect:** each appears next to you within a few seconds (says hello), at level 10, wearing
     gear, and joins your group, even a Horde hero with an Alliance commander or the other way round.
     The card changes to "In your party" and the button to "Send to barracks".
5. Send one back with **Send to barracks**: they disappear.
6. Talk to **Maude Ashby** (west side of the village): the window opens on the Tavern tab.
7. **Missions** tab: "Your party" lists your heroes. **Embark**, kill Rhahk'Zor (heroes fight with
   you), and come home.
   - **Expect:** the Roster shows "1 missions" for the heroes who went. The Tavern now has **4 new
     recruits** with gold prices (your company starts with 150 gold; with a full roster of 4 the
     Hire buttons are greyed out).
8. Log out and back in: the heroes who were in your party come back by themselves.

Typed backups (also work without the window): `.warband roster`, `.warband tavern`,
`.warband hire NAME`, `.warband call NAME`, `.warband send NAME`.

Tell me if the cards are hard to read, too cramped, or missing something you'd want to see.

**Result:** (waiting)

## Test 4: Act I and experience (phase 4)

Use the company from test 3 (or a new one with 4 heroes hired).

1. Open the **Missions** tab.
   - **Expect:** top right says "Act 1: The Hamlet - main missions 0 of 4, then the gate (level cap 20)".
     The list shows up to 3 contracts; at level 10 those are Ragefire Chasm's and the Deadmines'
     short runs. Each contract's Rewards says how many levels of experience it's worth.
2. Call your heroes, **Embark** on one, and fight through to the target boss (the Objective line
   names it). Watch your XP bar while you fight: monsters give very little (a tenth).
   - **Expect:** after the boss, "Mission complete!", then a line with everyone's experience. You and
     every hero who went gain about 1.5 levels (Short), 2 (Medium) or 2.5 (Long). Heroes who stayed
     home gain nothing yet.
3. Back home, open the window again.
   - **Expect:** "main missions 1 of 4"; a fresh set of contracts (new ones appear as you level:
     Wailing Caverns from 12, Shadowfang Keep from 14); a new batch of 4 recruits in the Tavern.
4. Take the **same dungeon** again if it's offered: the bosses are back (a fresh copy every time).
5. Optional, for the gate without playing 4 missions: there's no shortcut for players yet, so this
   one is for later, once you've played four. After 4 main missions the board shows
   **The Brotherhood's Last Stand** (orange "Gate"): the full Deadmines to Edwin VanCleef. You need
   to use the cannon on the big door yourself; bots won't.
6. Check a hero's talents after they level up (inspect them): the new points are spent.

Tell me how the pace feels: too fast, too slow, too hard at level 10?

**Result:** (waiting)

## Test 5: death's door (phase 5)

Heroes can now die for good. Use a company you don't mind losing heroes from.

1. Embark with two or three heroes and fight. When a hero dies:
   - **Expect:** an orange "`NAME` is down! 45 seconds to save them" line. Their body stays.
2. Finish the fight (or let a bot healer resurrect them).
   - **Expect:** a few seconds after the fighting stops, the downed hero stands up at about a third
     of their health: "`NAME` is saved, but wounded". They have a "Wither Strike" debuff (that's the
     wound: -10% max health), and their Roster card says **Wounded** with a **Treat** button.
3. If a wounded hero goes down again, or someone stays down for 45 seconds during a long fight:
   - **Expect:** a red "`NAME` has fallen." line; they disappear a few seconds later. The **Memorial**
     tab shows them with their level, class, missions survived, and how they died.
4. If you die and nobody saves you within 45 seconds, or the whole party goes down:
   - **Expect:** "The mission has failed", and you wake up in Raven Hill, wounded (the Roster header
     says "You are wounded" with a Treat button). In a wipe, every hero who was down is lost.
5. Treat a wound from the Roster tab (costs 20 gold + 2 per level).
6. Leave a wounded hero in the barracks for one mission: their wound is gone afterwards.
7. While dead on a mission, try releasing your spirit and running back: you can't revive at your
   corpse or at the spirit healer.

Tell me if dying feels fair, and whether 45 seconds and the "fight is over" rescue feel right.

**Result:** (waiting)

## Test 6: the armory and gold (phase 6) — Act I playable

The bot can't open corpses, so real looting is only tested here. Start with a **new character**.

1. Look at your commander right away.
   - **Expect:** green starter gear: chest, legs, feet, hands, waist, wrists in your class's armour,
     and a weapon (instead of the level-1 clothes).
2. Embark with heroes and fight. Loot a monster's corpse.
   - **Expect:** coins vanish straight away (no monster gold in Warband). A looted weapon or piece of
     armour shows "[Warband] ... goes to the armory" and isn't in your bags; cloth or ore shows
     "becomes materials". Your heroes loot too: same messages.
3. Finish the mission.
   - **Expect:** "The company earns 60 gold and 4 renown" (for a Short contract); the window's top
     line shows the new totals.
4. Open the **Armory** tab.
   - **Expect:** the looted items with quality colours, item level and slot; hovering one shows WoW's
     own tooltip (with its "of the ..." suffix). Items that would help someone are marked "Upgrade".
5. Click an item: the right side lists you and your party heroes with how much better it would be
   (or "not an upgrade"). Click a name: they wear it, and what they wore comes back to the armory.
6. Try **Equip all upgrades**, **Sell junk**, **Sell** and **Salvage** on an item.
7. Let a hero die for good while carrying a green item in their bags (rare): it lands in the armory.

Tell me if the Armory tab is clear, and whether gold feels too tight or too loose after a few missions.

**Result:** (waiting)
