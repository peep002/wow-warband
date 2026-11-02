-- wb_board.lua
-- The mission board: which contracts a company is offered right now, saved in warband_board so
-- they stay put until the next mission ends (and through restarts).
--   * Config.board.offers main missions from the current act, picked at random among those
--     whose min_level the commander has reached, different dungeons where possible.
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
        if m.kind == "main" and m.act == actNo and m.min_level <= player:GetLevel() then fits[#fits + 1] = key end
    end
    table.sort(fits) -- a fixed order first, so only the shuffle decides
    Shuffle(fits)

    -- First pass: one per dungeon. Second pass: fill up with the rest.
    local used = {}
    for pass = 1, 2 do
        for _, key in ipairs(fits) do
            if #keys >= Config.board.offers then break end
            local d = Config.missions[key].dungeon
            local taken = false
            for _, k in ipairs(keys) do taken = taken or k == key end
            if not taken and (pass == 2 or not used[d]) then
                keys[#keys + 1] = key
                used[d] = true
            end
        end
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
