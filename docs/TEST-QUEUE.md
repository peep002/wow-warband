# In-game tests waiting for the owner

Tests the bot can't do (it can't see windows, walk or fight). Do them in one sitting when you're at
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
