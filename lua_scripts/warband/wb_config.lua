-- wb_config.lua
-- Every Warband tuning number and place in one file, so balancing never means hunting
-- through logic. Other files read it with:  local Config = require("wb_config")

local Config = {}

-- The hamlet (hub) ---------------------------------------------------------------------------
Config.hub = {
    name   = "Raven Hill",
    map    = 0,                                   -- Eastern Kingdoms
    x = -10742.2, y = 330.574, z = 38.25, o = 0.55, -- where commanders arrive (".tele RavenHill")
    radius = 110,   -- yards from the arrival spot; further out between missions = sent back
}

-- New commanders -----------------------------------------------------------------------------
Config.commander = {
    start_level = 10,
    start_gold  = 150,    -- company gold at the start (gold pieces); the full economy comes in phase 6
}

-- Databases that Lua reaches by name (mod-ale only has the auth, characters and world ones).
Config.db = {
    playerbots = "warband_playerbots",
}

-- Heroes -------------------------------------------------------------------------------------
-- Hero characters live on one account (sql/updates/002_hero_pool.sql moves playerbots' ready-made
-- characters there). Nobody can log in to it; commanders are linked to it so they may command them.
Config.heroes = {
    account      = "WBHEROES",
    roster_slots = 4,     -- alive heroes a company can have (barracks upgrades raise it, phase 11)
    max_party    = 4,     -- heroes in the commander's group at once
    min_party    = 1,     -- heroes needed to embark (the design says 4; 1 while testing)
    gear_quality = 2,     -- quality of a new hero's starting gear: 1 white, 2 green, 3 blue
    dk_from_act  = 6,     -- death knights appear in the tavern from this act on
}

-- Tavern -------------------------------------------------------------------------------------
Config.tavern = {
    size        = { [0] = 4, 5, 6, 7 }, -- recruits shown after each mission, by tavern level
    level_gap   = 4,      -- recruits arrive this many levels below the roster's average level
    min_level   = 10,
    cost_base   = 40,     -- hire cost in gold: cost_base + cost_per_level * level
    cost_per_level = 4,
    founding_offers = 6,  -- a new company's first tavern: this many recruits...
    founding_free   = 4,  -- ...of which this many can be hired for free
    founding_roles  = { "tank", "healer", "dps", "dps" }, -- guaranteed among the founding offers
}

-- Class specs: playerbots' premade spec numbers (playerbots.conf, PremadeSpecName.<class>.<no>),
-- with the name shown to players and the spec's role.
Config.specs = {
    [1]  = { { no = 0, name = "Arms", role = "dps" }, { no = 1, name = "Fury", role = "dps" },
             { no = 2, name = "Protection", role = "tank" } },
    [2]  = { { no = 0, name = "Holy", role = "healer" }, { no = 1, name = "Protection", role = "tank" },
             { no = 2, name = "Retribution", role = "dps" } },
    [3]  = { { no = 0, name = "Beast Mastery", role = "dps" }, { no = 1, name = "Marksmanship", role = "dps" },
             { no = 2, name = "Survival", role = "dps" } },
    [4]  = { { no = 0, name = "Assassination", role = "dps" }, { no = 1, name = "Combat", role = "dps" },
             { no = 2, name = "Subtlety", role = "dps" } },
    [5]  = { { no = 0, name = "Discipline", role = "healer" }, { no = 1, name = "Holy", role = "healer" },
             { no = 2, name = "Shadow", role = "dps" } },
    [6]  = { { no = 0, name = "Blood", role = "tank" }, { no = 1, name = "Frost", role = "dps" },
             { no = 2, name = "Unholy", role = "dps" } },
    [7]  = { { no = 0, name = "Elemental", role = "dps" }, { no = 1, name = "Enhancement", role = "dps" },
             { no = 2, name = "Restoration", role = "healer" } },
    [8]  = { { no = 0, name = "Arcane", role = "dps" }, { no = 1, name = "Fire", role = "dps" },
             { no = 2, name = "Frost", role = "dps" } },
    [9]  = { { no = 0, name = "Affliction", role = "dps" }, { no = 1, name = "Demonology", role = "dps" },
             { no = 2, name = "Destruction", role = "dps" } },
    [11] = { { no = 0, name = "Balance", role = "dps" }, { no = 1, name = "Feral (bear)", role = "tank" },
             { no = 2, name = "Restoration", role = "healer" }, { no = 3, name = "Feral (cat)", role = "dps" } },
}

-- Traits: rolled now (one good, one bad), their effects come in phase 7.
-- only = a role the trait is limited to.
Config.traits = {
    positive = {
        brave         = { name = "Brave", text = "25% less stress gain." },
        stalwart      = { name = "Stalwart Shield", text = "10% more threat; never loses aggro to a single crit.", only = "tank" },
        selfless      = { name = "Selfless", text = "Taunts or shields a downed ally once per fight." },
        night_owl     = { name = "Night Owl", text = "+8% damage on high-darkness missions." },
        quartermaster = { name = "Quartermaster", text = "Expedition supplies last 25% longer." },
        lucky         = { name = "Lucky", text = "Better odds on rare affixes from chests they open." },
        field_medic   = { name = "Field Medic", text = "Revives downed allies 30% faster." },
    },
    negative = {
        coward        = { name = "Coward", text = "Flees combat below 20% health." },
        greedy        = { name = "Greedy", text = "10% chance to pocket a drop from the armory." },
        clumsy        = { name = "Clumsy", text = "Occasionally pulls an extra pack on expeditions." },
        glass_jaw     = { name = "Glass Jaw", text = "Takes 8% more damage from crits." },
        restless      = { name = "Restless", text = "Gains stress each time they're benched for a mission." },
        hates_dark    = { name = "Hates the Dark", text = "Double stress gain when torches run low." },
        hothead       = { name = "Hothead", text = "Sometimes charges the next pack before the healer is ready." },
    },
}

-- One-line backstories for recruits, picked at random.
Config.backstories = {
    "Walked out of a burning village with nothing but a sword and a grudge.",
    "Owes money to three different goblin cartels and needs the work.",
    "Was the only survivor of the last company that took a contract like this.",
    "Left a quiet temple life after the dead started walking.",
    "Claims to have killed a dragon. Nobody believes it.",
    "Signed on to pay for a sister's healing; writes home after every job.",
    "A former prisoner who learned to fight in the Stockade.",
    "Hunted bandits for bounties until the bounties dried up.",
    "Deserted an army that stopped paying, and a war that stopped making sense.",
    "Quiet, careful, and very good at staying alive.",
    "Wants a song written about them. Any song will do.",
    "Lost a whole party in Shadowfang Keep and still hears the wolves.",
    "Grew up on the road with a band of travelling mercenaries.",
    "Came for the gold, stays for the company. Mostly the gold.",
    "Swore an oath to a dying captain to see the job through.",
    "Was a scholar once. The books didn't fight back enough.",
}

Config.race_names = { [1] = "Human", [2] = "Orc", [3] = "Dwarf", [4] = "Night Elf", [5] = "Undead",
    [6] = "Tauren", [7] = "Gnome", [8] = "Troll", [10] = "Blood Elf", [11] = "Draenei" }
Config.class_names = { [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue", [5] = "Priest",
    [6] = "Death Knight", [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [11] = "Druid" }

-- Lockdown -----------------------------------------------------------------------------------
Config.lockdown = {
    check_seconds = 2,    -- how often everyone's position is checked
    teleport_grace = 10,  -- seconds after a party teleport before the position is checked again
    hearthstone   = 6948, -- item removed from new commanders
}

-- Acts ---------------------------------------------------------------------------------------
-- Each act is 10 levels. Its main missions count towards the gate; after mains_before_gate of
-- them the gate mission is offered, and beating it opens the next act.
Config.acts = {
    [1] = { name = "The Hamlet", min_level = 10, max_level = 20, mains_before_gate = 4, gate = "act1_gate" },
}

-- Experience -------------------------------------------------------------------------------------
-- Mission XP is counted in "levels": 2.0 = as much XP as two level-ups at the hero's level.
-- Nobody can level past the current act's max_level until the gate is beaten.
Config.xp = {
    kill_rate = 0.10,     -- monsters give 10% of their normal XP to commanders and heroes
    by_length = { Short = 1.5, Medium = 2.0, Long = 2.5 }, -- a completed main mission
    gate      = 3.0,      -- a completed gate mission
    side      = 0.10,     -- side missions (phase 10) give this share of a main mission's XP
    abandoned = 0.25,     -- an abandoned (retreated) mission gives this share
}

-- Missions -----------------------------------------------------------------------------------
-- The board offers Config.board.offers contracts from the current act. Each dungeon has up to
-- three lengths; a mission ends when its target boss dies:
--   Short = the first boss or two, Medium = about half the dungeon, Long = a full clear.
-- entrance: where the warband arrives inside. min_level: offered once the party's average level
-- (commander included) is at least this.
Config.board = {
    offers = 3,
}

Config.dungeons = {
    ragefire = {
        name = "Ragefire Chasm", act = 1, map = 389, level = "13-18",
        entrance = { x = 3.81, y = -14.82, z = -17.84, o = 4.39 },
        icon = "Interface\\Icons\\Spell_Fire_Fire",
        text = "Under Orgrimmar, the Burning Blade cult and a pack of troggs have dug into the fire caves. "
            .. "Someone is paying well to see them gone.",
        missions = {
            Short  = { name = "Smoke in the Chasm", boss = 11517, boss_name = "Oggleflint", min_level = 10 },
            Medium = { name = "The Hungerer", boss = 11520, boss_name = "Taragaman the Hungerer", min_level = 11 },
            Long   = { name = "Burning Blades", boss = 11519, boss_name = "Bazzalan", min_level = 12 },
        },
    },
    wailing = {
        name = "Wailing Caverns", act = 1, map = 43, level = "15-21",
        entrance = { x = -163.49, y = 132.9, z = -73.66, o = 5.83 },
        icon = "Interface\\Icons\\Ability_Hunter_Pet_WindSerpent",
        text = "The druids of the Fang have twisted the caverns' dream into a nightmare. "
            .. "Their lords are dangerous, and the deviate beasts worse.",
        missions = {
            Short  = { name = "Fangs in the Dark", boss = 3671, boss_name = "Lady Anacondra", min_level = 12 },
            Medium = { name = "Lord of the Fang", boss = 3670, boss_name = "Lord Pythas", min_level = 13 },
            Long   = { name = "The Everliving", boss = 5775, boss_name = "Verdan the Everliving", min_level = 14 },
        },
    },
    deadmines = {
        name = "The Deadmines", act = 1, map = 36, level = "15-21",
        entrance = { x = -16.4, y = -383.07, z = 61.78, o = 1.86 },
        icon = "Interface\\Icons\\INV_Misc_Bomb_05",
        text = "The Defias Brotherhood is digging under Moonbrook, building something big in the dark.",
        missions = {
            Short  = { key = "deadmines_short", name = "Into the Deadmines", boss = 644, boss_name = "Rhahk'Zor", min_level = 10 },
            Medium = { name = "The Goblin Foundry", boss = 1763, boss_name = "Gilnid", min_level = 13 },
            -- The Long run is the act's gate (below).
        },
    },
    shadowfang = {
        name = "Shadowfang Keep", act = 1, map = 33, level = "18-25",
        entrance = { x = -229.135, y = 2109.18, z = 76.8898, o = 1.267 },
        icon = "Interface\\Icons\\Ability_Mount_WhiteDireWolf",
        text = "Archmage Arugal's worgen hold the old keep above Pyrewood. Nobody who goes in at night comes out.",
        missions = {
            Short  = { name = "Gates of Shadowfang", boss = 3914, boss_name = "Rethilgore", min_level = 14 },
            Medium = { name = "The Baron's Hall", boss = 3887, boss_name = "Baron Silverlaine", min_level = 16 },
            Long   = { name = "Arugal's End", boss = 4275, boss_name = "Archmage Arugal", min_level = 17 },
        },
    },
}

-- Gate missions: one per act, offered once enough main missions are done.
Config.gates = {
    act1_gate = {
        name = "The Brotherhood's Last Stand", dungeon = "deadmines", length = "Long",
        boss = 639, boss_name = "Edwin VanCleef",
        text = "This is it: the Brotherhood's whole strength, and Edwin VanCleef on his ship at the end. "
            .. "Win, and the roads past the hamlet open. (Harder 'hardened' versions come with darkness and modifiers.)",
    },
}

Config.mission = {
    return_seconds = 10,  -- after the target boss dies, seconds before everyone is sent home
}

-- Turns the dungeons and gates above into one Config.missions list, keyed by mission key
-- ("ragefire_short", "act1_gate"...). Logic code only reads Config.missions.
Config.missions = {}
for dkey, d in pairs(Config.dungeons) do
    for length, m in pairs(d.missions) do
        local key = m.key or (dkey .. "_" .. length:lower())
        Config.missions[key] = { key = key, name = m.name, dungeon = d.name, kind = "main", length = length,
            act = d.act, level = d.level, min_level = m.min_level, icon = d.icon, text = d.text,
            objective = "Kill " .. m.boss_name, map = d.map, entrance = d.entrance, boss = m.boss,
            xp = Config.xp.by_length[length] }
    end
end
for key, g in pairs(Config.gates) do
    local d = Config.dungeons[g.dungeon]
    Config.missions[key] = { key = key, name = g.name, dungeon = d.name, kind = "gate", length = g.length,
        act = d.act, level = d.level, min_level = 0, icon = "Interface\\Icons\\INV_Misc_Head_Human_01",
        text = g.text, objective = "Kill " .. g.boss_name, map = d.map, entrance = d.entrance, boss = g.boss,
        xp = Config.xp.gate }
end

return Config
