-- wb_board.lua
-- The mission board: which contracts a company is offered right now, saved in warband_board so
-- they stay put until the next mission ends (and through restarts).
--   * Config.board.offers main missions from the current act, picked at random among those the
--     commander is nearly ready for (min_level - level_stretch), different dungeons and different
--     lengths where possible (so the offers differ in risk and reward).
--   * Once the act's mains_before_gate main missions are done, the gate mission is offered first.
--
--   Board.Get(player)        the mission keys on the board (filled the first time it's asked)
--   Board.Refresh(player)    deal a new set of contracts (after every mission)
--   Board.Set(player, keys)  put exactly these contracts up (for tests)
--
-- Use from other files:  local Board = require("wb_board")

local Config  = require("wb_config")
local Company = require("wb_company")
local Log     = require("wb_log")

local Board = {}

local cache = {} -- [commander guid] = { key, ... }

local function Save(c, keys)
    CharDBQuery("DELETE FROM `warband_board` WHERE `company` = " .. c.guid)
    for i, key in ipairs(keys) do
        CharDBQuery(string.format("INSERT INTO `warband_board` (`company`, `slot`, `mission_key`) VALUES (%d, %d, '%s')",
            c.guid, i, key))
    end
    cache[c.guid] = keys
end

local function Shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function Deal(player, c)
    local act = Config.acts[c.act] or Config.acts[#Config.acts]
    local actNo = Config.acts[c.act] and c.act or #Config.acts
    local keys = {}
    if c.progress >= act.mains_before_gate then keys[1] = act.gate end

    -- Main missions of this act the commander is ready for, in random order.
    local fits = {}
    for key, m in pairs(Config.missions) do
        if m.kind == "main" and m.act == actNo and m.min_level - Config.board.level_stretch <= player:GetLevel() then
            fits[#fits + 1] = key
        end
    end
    table.sort(fits) -- a fixed order first, so only the shuffle decides
    Shuffle(fits)

    -- One at a time, the contract that adds the most variety: +1 for a new dungeon, +1 for a new
    -- length, and +0.5 more for whichever of the two the board still has only one of (otherwise
    -- "Ragefire Short" then two other dungeons' Shorts could fill the board with three Shorts).
    -- Ties go to the shuffled order.
    local usedDungeon, usedLength = {}, {}
    local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
    while #keys < Config.board.offers do
        local best, bestScore
        for _, key in ipairs(fits) do
            local taken = false
            for _, k in ipairs(keys) do taken = taken or k == key end
            if not taken then
                local m = Config.missions[key]
                local score = 0
                if not usedDungeon[m.dungeon] then score = score + 1 + (Count(usedDungeon) == 1 and 0.5 or 0) end
                if not usedLength[m.length] then score = score + 1 + (Count(usedLength) == 1 and 0.5 or 0) end
                if not best or score > bestScore then best, bestScore = key, score end
            end
        end
        if not best then break end
        keys[#keys + 1] = best
        local m = Config.missions[best]
        usedDungeon[m.dungeon], usedLength[m.length] = true, true
    end
    Save(c, keys)
    Log.Event(c.guid, "board_dealt", table.concat(keys, ","))
    return keys
end

function Board.Get(player)
    local c = Company.Get(player)
    if not c then return {} end
    if cache[c.guid] then return cache[c.guid] end
    local keys = {}
    local q = CharDBQuery("SELECT `mission_key` FROM `warband_board` WHERE `company` = " .. c.guid .. " ORDER BY `slot`")
    if q then
        repeat
            if Config.missions[q:GetString(0)] then keys[#keys + 1] = q:GetString(0) end
        until not q:NextRow()
    end
    if #keys == 0 then return Deal(player, c) end
    cache[c.guid] = keys
    return keys
end

function Board.Refresh(player)
    local c = Company.Get(player)
    if c then Deal(player, c) end
end

function Board.Set(player, keys)
    local c = Company.Get(player)
    if c then Save(c, keys) end
end

return Board
