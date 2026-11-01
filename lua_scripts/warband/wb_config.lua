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
    start_gold  = 0,      -- company gold at the start (gold pieces); the economy comes in phase 6
}

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
