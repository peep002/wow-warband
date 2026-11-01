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

-- Missions -----------------------------------------------------------------------------------
-- kind: "main" or "side". length: "Short", "Medium" or "Long".
-- entrance: where the warband arrives inside the dungeon. boss: creature entry whose death
-- completes the mission.
Config.missions = {
    deadmines_short = {
        name     = "Into the Deadmines",
        dungeon  = "The Deadmines",
        kind     = "main",
        length   = "Short",
        level    = "15-20",
        icon     = "Interface\\Icons\\INV_Misc_Bomb_05",
        text     = "The Defias Brotherhood is digging under Moonbrook. Go in, find the ogre "
                .. "foreman Rhahk'Zor, and put him down. Come straight back after.",
        objective = "Kill Rhahk'Zor",
        map      = 36,
        entrance = { x = -16.4, y = -383.07, z = 61.78, o = 1.86 },
        boss     = 644,       -- Rhahk'Zor
        rewards  = "Experience, gear, renown (from phase 4 on)",
    },
}

-- The board offers these for now (phase 2: one fixed mission).
Config.board = { "deadmines_short" }

Config.mission = {
    return_seconds = 10,  -- after the target boss dies, seconds before everyone is sent home
}

return Config
