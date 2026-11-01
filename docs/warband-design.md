# Warband: The Last Ward — Design Document

*Original: Nov 1, 2026, @JT (PDF). Converted to Markdown on 2026-11-01. The open decisions at
the end have been answered; changes from the PDF are marked **(decided 2026-11-01)**. This file
is the source of truth for what the game does.*

## Vision and pillars

Warband is a Darkest Dungeon and XCOM-style roguelite inside a WotLK private server: you
command a roster of bot heroes on missions across Azeroth, from level 10 to 80, and any of them
can die for good. The campaign is the only way characters touch the world.

**Premise.** A shadow is creeping across Azeroth, and the kingdoms are stretched too thin to stop
it. You are the commander of a mercenary company rebuilding a ruined hamlet as its base, taking
the contracts no army will. Hub: **Raven Hill, Duskwood**, a ruined village with the right gloomy
mood and no faction guards **(decided 2026-11-01)**.

**Design pillars**
- **Every hero is a person.** Names, traits, quirks, stress and history. Permadeath has to hurt,
  and the memorial wall remembers them.
- **Missions are commitments.** You pick risk and reward before you go in: length, darkness,
  modifiers, supplies, who you bring. Once inside, you live with it.
- **Builds, not just levels.** Level-up marks, relics, affixed gear and traits combine, so two
  level-40 priests can play very differently.
- **The hamlet grows with you.** Every building upgrade is visible in the world and changes what
  you can do between missions.
- **A closed world.** Every item, coin and level comes from the campaign. No auction house, no
  trading, no open-world farming.
- **Losing hurts, but it isn't the end.** Heroes die, missions fail, gear is lost, but the company
  endures and legacy carries forward.

## Campaign structure

A full campaign is **seven acts of 10 levels each**, taking heroes from level 10 to 80. **Each
act has 5 main missions, the fifth being the act's gate mission (35 main missions in total),
plus optional side missions** **(decided 2026-11-01; the PDF had five acts and about 36 main
missions)**. The gate must be beaten to unlock the next act's dungeons. Ten-level acts line up
with WoW's own dungeon level brackets, so dungeons fit the party's level without scaling.

| Act | Name | Levels | Dungeons on the board | Gate mission |
|---|---|---|---|---|
| I | The Hamlet | 10–20 | Ragefire Chasm, Wailing Caverns, Deadmines, Shadowfang Keep | The Brotherhood's Last Stand: a hardened Deadmines run ending at Edwin VanCleef |
| II | The Spreading Dark | 20–30 | Blackfathom Deeps, the Stockade, Gnomeregan, Razorfen Kraul, Scarlet Monastery Graveyard and Library | Gnomeregan, ending at Mekgineer Thermaplugg |
| III | The Crimson Crusade | 30–40 | Scarlet Monastery Armory and Cathedral, Razorfen Downs, Uldaman | The Crimson Throne: Scarlet Cathedral, Mograine and Whitemane |
| IV | The Old Kingdoms | 40–50 | Zul'Farrak, Maraudon, Sunken Temple | The Sunken Temple, ending at Eranikus |
| V | The Black Mountain | 50–60 | Blackrock Depths, Lower and Upper Blackrock Spire, Dire Maul, Scholomance, Stratholme | The Baron's Hour: Stratholme's undead side, ending at Baron Rivendare |
| VI | Beyond the Portal | 60–70 | Hellfire Citadel wings, Auchindoun wings, Coilfang wings, Tempest Keep wings, Caverns of Time | The Shadow Labyrinth: ending at Murmur |
| VII | The Frozen Throne | 70–80 | Utgarde Keep, Nexus, Azjol-Nerub, Ahn'kahet, Drak'Tharon, Violet Hold, Gundrak, Halls of Stone and Lightning, Oculus, Utgarde Pinnacle | The finale: Icecrown Citadel and the Lich King, a 10-person raid with your whole roster |

*(Act names for II–V and the Act II and IV gates are first suggestions, open to change.)*

**Pacing.** Missions are the main XP source; regular kill XP is cut to about 10%. Each act is 10
levels over 5 main missions, so **a completed main mission is worth about 2 levels**, a visible
step without feeling cheesy **(decided 2026-11-01)**. Main missions and side missions together
should land the roster at the act's top level by the gate; the exact split is a config number.

**Side missions give a little XP (about 10% of a main mission)** **(decided 2026-11-01)**: enough
that a side mission isn't wasted time, not enough to level by. They exist mainly for gear,
materials, relics, recruits and renown. Failed main missions give 25%.

**Threat clock (decided 2026-11-01).** Every side mission raises the act's threat. Higher threat
adds darkness and modifiers to the act's remaining main missions (and pays a bit more loot and
renown). When threat reaches its maximum, a harder **crisis mission** appears and must be done
next. Beating the act's gate resets threat to zero. This stops endless side-mission farming
without forbidding it.

**Keeping the bench relevant.** Heroes who sit out a mission earn 40% of its XP through the
Training Yard (60% when upgraded). Otherwise the roster splits into a strong four and a useless
bench, and the finale needs ten.

**Run length.** 35 main missions plus side missions at 30–45 minutes each: roughly 30–35 hours.
Everything is saved continuously in the database. Chronicles (below) let later campaigns start at
an act already reached.

**The finale.** Act VII ends with a 10-person raid: you plus nine heroes, bench included. Every hero
you kept alive and leveled matters here.

## Side missions and raids

Only main missions move the campaign forward. Side missions are optional detours for gear and
resources, and each one you take is a mission's worth of stress, risk and supplies spent without
progress, and raises the threat clock. That tradeoff is the point. The board shows the next main
mission plus 2–4 side missions (more with Mission Board upgrades), refreshed after every mission
**(decided 2026-11-01)**.

Raids are the biggest side missions. They need a 10-person warband (commander plus nine heroes),
so they only appear once your roster is deep enough. Larger raids are scaled down to 10 people
with mod-autobalance. Long raids are split into wings, and each wing is its own mission.

| Act | Raids on the board | Original size | Appears when |
|---|---|---|---|
| I–IV | None (WoW's first raids are level 60) | — | Side missions here are bounties, plunders, rescues and recoveries |
| V | Zul'Gurub, Ruins of Ahn'Qiraj | 20 | Roster average level 58+ |
| V+ | Molten Core, Blackwing Lair, Temple of Ahn'Qiraj | 40 | Roster average 60, Act V gate beaten |
| VI | Karazhan, Zul'Aman | 10 | Roster average 68+ |
| VI | Gruul's Lair, Magtheridon's Lair, Serpentshrine Cavern, Tempest Keep: The Eye | 25 | Roster average 70 |
| VI+ | Mount Hyjal, Black Temple, Sunwell Plateau | 25 | Act VI gate beaten |
| VII | Naxxramas, Obsidian Sanctum, Eye of Eternity, Vault of Archavon, Onyxia's Lair | 10/25 | Roster average 80 |
| VII | Ulduar, Trial of the Crusader, Ruby Sanctum | 10/25 | After the first Act VII raid is cleared |
| VII | Icecrown Citadel | 10/25 | The finale (the Act VII gate) |

Raid rewards: raid-tier gear, a guaranteed relic from each final boss, double materials and big
renown. Raid risk: ten heroes exposed at once, and a wipe can gut the roster. Raids from earlier
acts stay on the board, so you can go back for gear on an easier, lower-risk run.

## The core loop

Every cycle is one trip out from the hamlet and back: prepare, commit, survive, recover. A cycle
takes 30–45 minutes, most of it inside the mission.

1. **Town.** Heal wounds, relieve stress, buy supplies, craft, upgrade buildings, hire recruits,
   equip from the armory. Every service costs gold, so you can't fix everyone every time.
2. **Mission board.** Pick one of 3–5 offered missions. Each shows its dungeon, length, darkness,
   modifiers, recommended level and rewards.
3. **Embark.** Choose 4 heroes and your supplies (food, torches, bandages, special items). Check
   their stress and wounds before committing.
4. **The mission.** The warband is teleported in. Fight through, manage stress and supplies, camp
   once on long missions, and decide whether to push on or retreat.
5. **Return.** Success pays full XP, loot and renown. Retreat keeps survivors and what you carried
   but pays little. A wipe loses the gear of everyone who died.
6. **Aftermath.** Level-up marks are chosen, quirks are rolled, the dead go on the memorial wall,
   the board refreshes and new recruits arrive at the tavern.

The only exits from this loop are the mission teleport and the return. Anyone who wanders out of
a mission area is returned to the entrance; anyone outside the hamlet between missions is
returned to it.

## Heroes

Heroes are mod-playerbots characters with a generated identity, rolled traits, a level-up build,
and a stress meter. The roster starts at 4 slots and grows to 10 with tavern upgrades. Four go on
each mission; the rest rest, train, or recover.

### Recruitment

- The tavern shows 3 recruits after each mission (5 at max tavern level). Unhired recruits leave
  when the next mission ends.
- Each recruit has a class and spec, a name and a one-line backstory, 2 traits (1 positive, 1
  negative), and a hire cost in gold.
- Recruits arrive 4 levels below the roster's average level; tavern upgrades shrink the gap to 1.
- Rarer specs and three-trait recruits appear at higher tavern levels.
- **Starting pool: all 9 non-death-knight classes and all races of both factions, mixed in one
  company** (it's a mercenary band) **(decided 2026-11-01)**.
- **Death knights are recruitable from the Outland act** (Act VI in the seven-act structure; the
  owner picked "Act IV" when Outland was Act IV) (a legacy unlock can bring them earlier in later
  campaigns) **(decided 2026-11-01)**.

### Traits

Traits are hidden auras plus changes to the bot's playerbots strategies, so they change real
behavior.

| Trait | Type | Effect |
|---|---|---|
| Brave | Positive | 25% less stress gain |
| Stalwart Shield | Positive | Tanks only: 10% more threat, never loses aggro to a single crit |
| Selfless | Positive | Taunts or shields a downed ally once per fight |
| Night Owl | Positive | +8% damage on high-darkness missions |
| Quartermaster | Positive | Expedition supplies last 25% longer |
| Lucky | Positive | Better odds on rare affixes from chests they open |
| Field Medic | Positive | Revives downed allies 30% faster |
| Coward | Negative | Flees combat below 20% health |
| Greedy | Negative | 10% chance to pocket a drop from the armory |
| Clumsy | Negative | Occasionally pulls an extra pack on expeditions |
| Glass Jaw | Negative | Takes 8% more damage from crits |
| Restless | Negative | Gains stress each time they're benched for a mission |
| Hates the Dark | Negative | Double stress gain when torches run low |
| Hothead | Negative | Sometimes charges the next pack before the healer is ready |

### Leveling and marks

WoW talents are auto-assigned for the hero's spec. On top of that, every level-up offers a mark:
pick 1 of 3 random options, like The Last Spell's level-up choices.

- **Minor marks** (most levels): +3% max health, +4% healing done, +5% crit damage, +stamina,
  +spirit, and so on.
- **Major marks** (every 10th level): build-defining picks, for example Executioner (+25% damage to
  targets under 30%), Bulwark (blocking restores 1% health), Last Light (heals on a downed ally
  are doubled).
- **Callings** (level 40 and 70): a capstone choice per role. Tanks choose Warden (guards a downed
  ally, taking their hits) or Vanguard (charges into elites); healers choose Sanctifier (big
  single-target saves) or Beacon (group healing aura).
- One free reroll of the three options per hero per act; the Infirmary sells more.

### Stress, afflictions and virtues

Stress runs 0–200.

- **Gains:** taking crits, an ally downed or killed, long missions, high darkness, running out of
  torches or food, retreating, and certain enemy abilities.
- **At 100:** a resolve check. Usually an affliction: Paranoid (refuses heals from others),
  Hopeless (-15% damage), Selfish (takes the best armory drop), Fearful (won't hold the gate),
  Abusive (adds stress to allies). About 1 in 4 times a virtue: Stalwart (immune to death's door),
  Courageous (reduces party stress on crits), Focused (+10% crit).
- **At 200:** a heart attack sends them straight to death's door.
- **Relief:** in the hamlet between missions, for gold, at the inn, chapel or tavern. Benched
  heroes (not on the current mission) also lose a little stress each mission they sit out.

### Death's door and permadeath

- At 0 health a hero is **Downed** and bleeds out for 45 seconds. A battle-res, a Field Medic
  revive, or the fight ending in time saves them.
- Survivors get a **wound**: -10% max health until healed at the Infirmary, **or for free by
  sitting out one mission** **(decided 2026-11-01)**, so the roster doesn't snowball into
  half-wounded parties.
- A hero dies permanently if they bleed out, or go down again while wounded.
- Their **equipped gear and relics** are lost unless recovered by a Recover the Fallen mission;
  anything in their bags goes back to the armory **(decided 2026-11-01)**.
- **First version (decided 2026-11-01):** the hero really dies, the body stays where it fell, and
  they can be revived within the 45-second bleed-out window; otherwise the death is permanent.
  This is buildable in Lua. A true "kneeling at 1 health" Downed state likely needs C++ and is only
  revisited if the first version feels wrong in play. Their name goes on the
  memorial wall with level, class, missions survived, and how they died.

### Quirks

Permanent quirks earned from experience: Spider-phobic after surviving Azjol-Nerub, Undead Slayer
after enough Scourge kills, Unbroken after tanking five boss kills without going down. The
Infirmary removes bad quirks for gold and can lock good ones.

## Missions

Missions are real WoW dungeons, cut to a chosen length and layered with darkness, modifiers and
events. The board offers 3–5 at a time, always including at least one main mission for the
current act.

### Mission types

| Type | Kind | Goal | XP | Main rewards |
|---|---|---|---|---|
| Main | Main | Clear to the mission's final boss | Full | XP, gear, renown; counts toward the act gate |
| Act gate | Main | The act's final challenge | Full + bonus | Unlocks the next act, a guaranteed relic |
| Bounty | Side | Kill a named elite or rare in a dungeon, then leave | None | A guaranteed rare or better, gold |
| Plunder | Side | Open as many treasure caches as possible before time runs out | None | Materials and gold |
| Rescue | Side | Escort a captive NPC out alive | None | A free recruit at the tavern |
| Recover the Fallen | Side | Reach a dead hero's body and bring it home | None | Their gear back, plus a funeral (big stress relief) |
| Raid wing | Side | Clear one wing of a raid with 10 people | None | Raid-tier gear, relics, double materials |

*(Side-mission XP changed from 10% to none, 2026-11-01.)*

### Length

- **Short:** the dungeon's first wing or first 1–2 bosses. About 15–20 minutes. Low stress, low
  rewards.
- **Medium:** about half the dungeon. 25–35 minutes. One supply check.
- **Long:** a full clear. 40–60 minutes. One camp allowed, the best rewards, the most stress.

### Darkness and torches

Each mission starts at a darkness level from 0 (well lit) to 3 (pitch black). Torches lower it by
one step for a while.

- Darkness 0: no stress penalty, normal loot.
- Darkness 1: +10% stress gain, +10% loot quality.
- Darkness 2: +25% stress, +25% loot, ambush chance on pulls.
- Darkness 3: +50% stress, +50% loot, elites can appear in place of normal packs.

### Modifiers

Missions roll 0–2 modifiers; harder ones pay more renown.

- **Plagued:** enemies apply a stacking disease that stops passive healing.
- **Infested:** extra spider or insect packs that add stress on hit.
- **Fortified:** non-boss enemies have 30% more health.
- **Frenzied:** enemies under 30% health gain 25% attack speed.
- **Cursed Ground:** standing still for 3 seconds adds stress.
- **Hunted:** a roaming elite stalks the party and attacks mid-fight.
- **Rich Veins:** double materials, but packs are larger.

### Champions

At darkness 2–3, some packs are led by a champion: an elite with 1–2 affixes such as Vampiric
(heals on hit), Shielding (protects allies), Explosive (bursts on death), or Dread (big stress
damage on crits). Champions always drop a chest with a guaranteed rare or better.

### Curios

Each mission spawns 3–6 interactable objects: risk-and-reward choices made on the spot.

- **Shrine:** pray for a buff, or desecrate it for gold and stress.
- **Corpse of a lost adventurer:** search for loot, risk a disease.
- **Locked chest:** use a key or a rogue to open safely, or force it and risk a trap.
- **Strange altar:** sacrifice health for a relic roll.
- **Discarded journal:** lowers stress for whoever reads it, or reveals a hidden cache.

The right supply item (holy water on a shrine, a key on a chest) always gives the best result,
which makes packing supplies a real decision.

### Supplies

Bought in town before embarking, carried in a shared mission pack with limited slots (8, up to 12
with upgrades).

- **Food:** needed at camp and on long missions; running out adds stress and stops health regen.
- **Torches:** lower darkness.
- **Bandages:** stop bleeding, add a small heal out of combat.
- **Holy water, keys, antivenom, shovels:** curio and modifier counters.

### Camping

Long missions allow one camp. Each hero gets 2 camp skills (by class): a priest can Sermon (party
stress relief), a warrior can Drill (party damage buff for the next fight), a rogue can Keep Watch
(prevents a camp ambush). The commander gets 4 skill points to spend on the camp, plus food is
consumed.

### Retreat and failure

- **Retreat:** possible any time out of combat. Survivors and carried loot return home; the mission
  pays 25% XP and stress rises for everyone.
- **Wipe:** every hero who dies is gone with their gear. The commander returns alone. The mission
  can be re-offered later as a Recover the Fallen.

## The hamlet

The hamlet starts as ruins with a campfire, a tent and a mission board, and is rebuilt one
building at a time with renown and materials. Each upgrade spawns new objects and NPCs in the
world, so progress is something you can walk around and see.

| Building | What it does | Upgrades (3 levels each) |
|---|---|---|
| Mission Board | Offers missions | More missions offered; reroll the board once per return; preview modifiers |
| Tavern | Recruits; drinking relieves stress | More recruits; smaller level gap; three-trait and rare-spec recruits |
| Barracks | Roster housing | Roster slots 4 → 6 → 8 → 10 |
| Chapel | Prayer relieves stress | Cheaper relief; more heroes at once; removes religious afflictions |
| Infirmary | Heals wounds, treats quirks, cures diseases | Cheaper treatment; lock good quirks; sells mark rerolls |
| Blacksmith | Crafts and upgrades gear | Higher crafting tiers; affix rerolling; socket gems |
| Provisioner | Sells supplies | Bigger mission pack; cheaper supplies; rare supplies (holy water, antivenom) |
| Training Yard | Bench XP | Bench earns 40% → 50% → 60% of mission XP |
| Reliquary | Stores and identifies relics | More relic slots per hero; reveal relic effects before equipping |
| Memorial Wall | Remembers the dead | Funerals relieve stress for the whole roster; fallen heroes' names grant small morale bonuses |
| Hall of Veterans | Retired heroes | Retire a level 60+ hero for a permanent roster bonus and an heirloom |

Buildings are gated by act. Level 2 upgrades unlock in Act III and level 3 in Act V (moved from
Acts II and IV to fit seven acts), so the hamlet grows alongside the campaign instead of being
maxed by Act I.

**Town events.** After some missions, a random event fires: a traveling merchant with rare relics,
a plague that closes the infirmary for a mission, a festival that halves stress costs, or a
stranger offering a dangerous bonus mission. These keep returns from feeling identical.

## The commander

You play a real character who fights in the party as the fifth member, and who also runs the
company. The commander levels with the roster, using the same mark system as heroes.

**Making a commander (decided 2026-11-01):** create a fresh character of any race and class
except death knight. Its first login sets it to level 10, gives starter gear, and starts a new
campaign at Raven Hill. **One company per commander character**: a second character runs a
second, separate campaign.

**Commander death (decided 2026-11-01):** the commander can't die permanently by default. If you go
down and the mission wipes, you wake up in the hamlet, wounded, with your carried loot lost. The
campaign only ends if you can't field four heroes and can't afford to hire more. An optional
**Ironman** mode makes commander death end the campaign.

**Orders.** The commander can give the warband simple orders through playerbots' existing
commands, mapped to short chat commands or addon buttons:

- Focus my target
- Hold here / follow me
- Pull back to me
- Save cooldowns for the boss / burn everything now
- Healers: prioritize the tank / prioritize the downed

**Commander skills.** Earned with renown, used once per mission each:

- **Rally:** instantly relieve 15 stress from the whole party.
- **Second Wind:** revive a Downed hero without a battle-res.
- **Inspire:** +10% party damage for one fight.
- **Scout Ahead:** reveal the next room's pack, curios and any ambush.
- **Call the Retreat:** retreat without the stress penalty.

**Party size.** Four heroes plus the commander makes a standard 5-person dungeon group, so dungeons
need no rebalancing. The finale is a 10-person raid: commander plus nine heroes.

## Loot and economy

Everything comes from missions, so the economy is tuned so you can fully restore only 2–3 heroes
per return. That scarcity is what forces rotation, tough calls and a deep bench.

### Currencies

| Currency | Earned from | Spent on |
|---|---|---|
| Gold | Mission rewards, curios, selling junk to the hamlet vendor (the only place items can be sold; monsters drop no coin) | Healing, stress relief, recruits, supplies, crafting fees |
| Materials | Boss chests, Plunder missions, salvaging gear | Crafting and upgrading gear |
| Renown | Completing missions (more for harder modifiers and darkness) | Building upgrades, commander skills |
| Relics | Champion chests, altars, gate bosses, rare drops | Equipped in trinket slots |

Materials are real WoW trade goods by tier (copper and linen in Act I up to saronite and
frostweave in Act VII), so no custom material items are needed.

### Where gear comes from

1. **Boss drops:** real dungeon loot tables, with drop rates raised and items filtered to classes
   on your roster.
2. **Champion chests:** a guaranteed rare or better, with a warband affix.
3. **Curios:** occasional gear, mostly gold and materials.
4. **The blacksmith:** crafted gear at the current act's tier, for filling slots drops never cover.

### Warband affixes

On top of WoW's built-in random suffixes ("of the Bear", "of the Eagle"), rare and epic items can
roll one warband affix that interacts with the roguelite systems:

- **Steadfast:** -10% stress gain
- **Lifeline:** bleed-out timer +15 seconds while Downed
- **Torchbearer:** darkness counts as one step lower for this hero
- **Bloodthirsty:** heal 2% on killing blow
- **Gravewarden:** +20% damage while an ally is Downed
- **Packmule:** +1 mission pack slot

### The shared armory

- Every drop goes to a shared armory instead of being rolled for. You equip heroes from it in town.
- After each mission the armory window highlights upgrades for each hero, with one "equip all
  upgrades" button; nothing changes without your click **(decided 2026-11-01)**.
- Items no roster class can use are auto-salvaged into materials.
- Greedy heroes occasionally pocket an item; it shows up in their bags, and you can confiscate it
  (+15 stress for them).

### Keeping gear relevant at speed

Heroes gain about 2 levels per main mission, so gear goes stale fast. Three answers:

- **Act-tiered crafting** keeps a reliable baseline available.
- **Tempering:** the blacksmith can move a warband affix from an old item to a new one for
  materials, so a great affix isn't lost to level.
- **Heirlooms** scale with level natively in WotLK and are the long-term legacy items (below).

### Relics

Relics are trinkets (two slots, plus a third from the Reliquary) with build-defining effects:

- **Martyr's Locket:** when this hero is Downed, the party heals for 20% of their max health.
- **Lantern of the Lost:** this hero ignores darkness stress.
- **Bone Dice:** each fight, randomly +15% damage or -10% damage.
- **Mourner's Veil:** +5% damage per fallen hero on the memorial wall (max 25%).
- **Oathstone:** bonded to another hero; both gain 10% stats while alive, and one loses 50 stress
  if the other dies.
- **Coward's Charm:** this hero never flees, but gains stress whenever they're hit.
- **Shard of the Gate:** gate bosses take 10% more damage from this hero.

### Death, gear and legacy

- A dead hero's equipped gear and relics are lost with them.
- Recover the Fallen missions bring the body home: gear returns to the armory, and a funeral at
  the memorial wall relieves roster-wide stress.
- **Heirlooms:** when a level 60+ hero dies or retires, their weapon can become an heirloom named
  for them (for example "Brenna's Oath, heirloom of the Third Company"). It scales with the new
  bearer's level.

## Meta-progression

Within a campaign, progress lives in the roster and the hamlet. Between campaigns, the company
keeps a legacy: points earned when a campaign ends, win or lose, spent on permanent unlocks for
future campaigns.

### Legacy points

Earned per campaign for acts cleared, gate bosses killed, heroes who reached level 60 or 80, and
heroes retired. A campaign that dies in Act II still earns something.

### Unlocks

- **Tavern pool:** new races and rarer specs appear among recruits (for example death knights
  before Act VI, after first clearing Act VI).
- **Trait pool:** new positive traits, and the option to ban one negative trait from rolling.
- **Starting kit:** begin with a level 1 building, extra gold, or a starting relic.
- **Heirloom vault:** carry up to 3 named heirlooms into a new campaign.
- **Chronicles:** after reaching an act for the first time, a new campaign can start there with a
  generated roster at the right level and a partly built hamlet.

### Difficulty tiers

Beating the campaign unlocks the next tier. Each tier keeps everything from the one before.

| Tier | Name | Change |
|---|---|---|
| 1 | Contract | The standard campaign |
| 2 | Hard Times | Gold rewards -20%; healing and stress relief cost more |
| 3 | Long Night | Every mission starts one darkness step higher |
| 4 | No Quarter | Bleed-out timer cut to 30 seconds; wounds take two treatments |
| 5 | Last Company | The commander is Ironman; one fewer recruit at the tavern |

### The company record

A persistent record in the hamlet lists every campaign: how far it got, who died, who retired, and
the finale roster of any campaign that won. Fallen heroes from past campaigns stay on the memorial
wall.

## Co-op

**Decided 2026-11-01: separate companies.** Each player runs their own company (own hamlet,
roster and armory) on the same server, and players can visit each other's hamlets.

*(The PDF's alternative, kept for reference: two commanders share one company, each brings 2
heroes per mission, shared decisions need both to confirm, and the finale is 2 commanders + 8
heroes.)*

## Technical architecture

The mode runs on AzerothCore (WotLK 3.3.5a) with mod-playerbots for heroes, Lua scripts (mod-ale,
the current name of Eluna) for the game rules, custom database tables for all state, and an addon
for the UI. Only 5–10 bots are active at once, so performance isn't a concern.

**Decided 2026-11-01: Warband is its own server**, separate from the Scholomance Survival
(WoW-Roguelike) server: its own AzerothCore build, its own databases, its own project folder.

### Stack

- **Server:** AzerothCore, playerbots branch. Built first on the owner's Windows PC; the Dell
  Optiplex home server later.
- **Heroes:** mod-playerbots characters from a pre-generated pool, added to the commander's group
  when hired.
- **Rules:** Lua scripts (C++ only where Lua can't reach, flagged when it happens).
- **State:** custom `warband_*` database tables.
- **UI (decided 2026-11-01):** real windows, not text menus. Every main screen (mission board,
  embark, tavern, roster, armory, hamlet buildings, level-up marks, memorial wall) gets a proper
  window built with the AIO framework **in the same phase as its system**, not saved for the end.
  Style: **classic WoW panels** (like the game's own Character and Quest Log windows), laid out
  for clarity. Windows open three ways: talking to the hamlet NPC (tavern keeper opens the Tavern),
  a **Warband button** near the minimap with a tabbed main menu, and chat commands
  (`.warband roster`). A plain NPC text menu stays only as a backup if the addon is missing.

### How each system is built

| System | Implementation | Difficulty |
|---|---|---|
| Hamlet lockdown | Teleport-back on leaving the hub or a mission area; disable flight paths, hearthstone, AH, trading | Easy |
| Mission teleport | Board NPC gossip menu; teleport the group to the entrance; track the mission in a table | Easy |
| Mission length | End trigger on the chosen boss's death; teleport home | Easy |
| Mission XP | Kill XP rate lowered; scripted XP grant on completion | Easy |
| Tavern hiring | Pool of pre-made bot characters; gossip menu to hire; playerbots add-to-group | Medium |
| Traits and personality | Hidden auras plus per-bot playerbots strategy toggles | Medium |
| Stress | Number in the database, changed by combat event hooks; afflictions applied as auras | Medium |
| Death's door | Intercept lethal damage, apply a Downed state with a timer, resolve save or death | Hard |
| Permadeath | Mark dead in the database, remove from pool, strip gear, memorial entry | Medium |
| Marks on level-up | Level-up hook offers 3 options through the addon or a gossip menu; picks applied as auras | Medium |
| Darkness, modifiers, champions | Auras on the party and on spawned creatures; champion affixes as scripted auras | Medium |
| Curios | Spawned game objects with gossip choices | Medium |
| Supplies | Custom items in a restricted mission pack | Medium |
| Camping | Camp object + gossip menu of class camp skills | Medium |
| Shared armory | Database-backed storage; NPC menu or addon to equip heroes | Hard |
| Warband affixes and relics | Custom item entries with proc spells | Medium–hard |
| Hamlet buildings | Pre-placed objects and NPCs spawned per upgrade level | Medium |
| Heirlooms | Custom heirloom items generated from templates, named per hero | Hard |
| Raids and the finale | Raid group of commander plus nine bots; mod-autobalance scales 20-, 25- and 40-person raids to 10 | Hard |

### Database tables (first pass)

- `warband_company` (gold, renown, materials, act, difficulty tier)
- `warband_heroes` (bot character, traits, stress, wounds, quirks, marks, status alive/dead/retired)
- `warband_buildings` (building, level)
- `warband_armory` (stored items)
- `warband_missions` (board offers, active mission, history)
- `warband_memorial` (fallen heroes and how they died)
- `warband_legacy` (points, unlocks, heirloom vault, company record)

## Build phases

Thirteen phases, each ending with something testable in-game. Phases 1–6 make a playable (if
bare) Act I; everything after deepens it.

1. **Server foundation:** AzerothCore + playerbots + Lua running; you can group with bots and run a
   dungeon.
2. **Hamlet lockdown and mission teleport:** hub at Raven Hill, teleport-back, mission board with
   one hardcoded mission, return on boss kill.
3. **Tavern and roster:** pre-made bot pool, hiring, roster saved in the database, `.warband roster`.
4. **Mission XP and Act I:** kill XP reduced, completion XP, the Act I dungeon list, mission lengths.
5. **Death's door and permadeath:** Downed state, bleed-out, wounds, permanent death, memorial wall.
6. **Shared armory and currencies:** loot goes to the armory, gold, materials, renown, equipping
   heroes. Act I is now playable.
7. **Traits and personalities:** trait auras and strategy tweaks.
8. **Stress:** stress meter, afflictions, virtues, heart attacks, town stress relief.
9. **Marks:** level-up choices, major marks, callings, rerolls.
10. **Mission depth:** darkness and torches, modifiers, champions, curios, supplies, camping,
    retreat, mission types.
11. **The hamlet:** buildings and upgrades, town events, Training Yard bench XP, quirks.
12. **Loot depth and Acts II–VII:** warband affixes, relics, tempering, heirlooms, all act dungeon
    lists and gate missions, raid side missions with mod-autobalance scaling, the Icecrown Citadel
    finale.
13. **Meta and release:** legacy unlocks, difficulty tiers, the addon UI, co-op, balance pass, and
    the packaged release for your friend.

## Risks

The biggest risk is bots dying to their own AI mistakes, which can make permadeath feel unfair
instead of dramatic. Death's door, commander orders and the Second Wind skill exist mainly to
answer that.

- **Unfair deaths:** if testing shows bots die to avoidable mechanics, lengthen bleed-out, make some
  boss mechanics less lethal, or add a per-mission "miracle" save.
- **Leveling outpacing gear:** watch for heroes entering Act III in Act I gear. Fix with better
  crafting tiers or more champion chests.
- **Death's door is hard to build:** intercepting lethal damage may need C++. Fallback: let death
  happen, then allow a 45-second resurrection window before permadeath.
- **Shared armory UI:** managing items through gossip menus is clunky. The addon solves it, but it
  comes late.
- **Long campaigns:** 35 main missions in 7 acts, about 30–35 hours (2026-11-01). Chronicles and the save system
  soften it further.
- **Old dungeon tuning:** some classic dungeons are long and maze-like. Short and Medium lengths
  help, and any dungeon that plays badly can be dropped from the board.

## Open decisions (all answered 2026-11-01)

| Question | Answer |
|---|---|
| Hub location | Raven Hill, Duskwood |
| Commander permadeath | Off by default, with an optional Ironman mode |
| Co-op model | Separate companies (can visit each other's hamlets) |
| Starting tavern pool | All 9 non-DK classes, all races of both factions |
| Death knights | Recruitable from the Outland act (Act VI) |
| Campaign length | 7 acts of 10 levels, 5 main missions each (gate is the 5th, 35 total), plus side missions with a little XP and a threat clock |
| Same server as Scholomance Survival? | No: Warband is its own server |
| Gate mission | The 5th of each act's 5 main missions |
| Side missions | About 10% of a main mission's XP; each raises the act's threat clock (harder main missions, a forced crisis at max, reset by the gate) |
| Board | Next main mission + 2–4 side missions, refreshed after every mission |
| Wounds | Healed at the Infirmary, or free by sitting out one mission |
| Death's door | First version: real death + 45-second revive window, in Lua |
| Lost on permadeath | Equipped gear and relics; bag items go back to the armory |
| Commander | New character, any race/class except death knight, set to level 10 on first login; one company per commander |
| Gold | Monsters drop no coin; items sell only at the hamlet vendor |
| Armory | Suggests upgrades, "equip all upgrades" button, nothing automatic |
| UI | Real AIO windows built with each system, classic WoW panel style; opened by hamlet NPCs, a minimap Warband button, and chat commands; NPC text menus only as a backup |
