-- wb_company.lua
-- Commanders and their companies. One company per commander character, saved in the
-- warband_company table and cached in memory while the commander is online.
--   * A brand-new character's first login makes it a commander: level 10, no hearthstone,
--     sent to the hamlet, and a fresh company row. Death knights can't be commanders.
--   * Bots (mod-playerbots characters) are never commanders.
--   * Older characters that were never made commanders are left alone.
--
--   Company.Get(player)          the company table, or nil if not a commander
--   Company.GetByGuid(guid)      the same by commander guid (online commanders only)
--   Company.IsCommander(player)
--   Company.Save(player)         write the cached company back to the database
--   Company.OnReady(fn)          fn(player, company) after a commander logs in (or is created)
--
-- Use from other files:  local Company = require("wb_company")

local Config = require("wb_config")
local Log    = require("wb_log")

local Company = {}

local PLAYER_EVENT_ON_CHARACTER_DELETE = 2
local PLAYER_EVENT_ON_LOGIN            = 3
local PLAYER_EVENT_ON_LOGOUT           = 4
local PLAYER_EVENT_ON_FIRST_LOGIN      = 30
local CLASS_DEATH_KNIGHT = 6

local cache = {}   -- [guid] = company table
local readyHandlers = {}

local FIELDS = { "act", "progress", "gold", "renown", "materials", "threat", "tier", "ironman", "state", "wounded" }

local function Load(guid)
    local q = CharDBQuery("SELECT `" .. table.concat(FIELDS, "`, `") .. "` FROM `warband_company` WHERE `guid` = " .. guid)
    if not q then
        cache[guid] = nil
        return nil
    end
    local c = { guid = guid }
    for i, field in ipairs(FIELDS) do c[field] = q:GetUInt32(i - 1) end
    cache[guid] = c
    return c
end

function Company.Get(player)
    return player and cache[player:GetGUIDLow()]
end

-- By commander guid; only commanders who are online (their company is cached).
function Company.GetByGuid(guid)
    return cache[guid]
end

function Company.IsCommander(player)
    return Company.Get(player) ~= nil
end

function Company.Save(player)
    local c = Company.Get(player)
    if not c then return end
    local sets = {}
    for _, field in ipairs(FIELDS) do sets[#sets + 1] = string.format("`%s` = %d", field, c[field]) end
    CharDBExecute("UPDATE `warband_company` SET " .. table.concat(sets, ", ") .. " WHERE `guid` = " .. c.guid)
end

function Company.OnReady(fn)
    readyHandlers[#readyHandlers + 1] = fn
end

local function Ready(player)
    local c = Company.Get(player)
    if not c then return end
    for _, fn in ipairs(readyHandlers) do fn(player, c) end
end

-- Making a commander ----------------------------------------------------------------------

local function MakeCommander(player)
    local guid = player:GetGUIDLow()
    if player:GetClass() == CLASS_DEATH_KNIGHT then
        player:SendBroadcastMessage("|cffff2020[Warband]|r Death knights can't be commanders. Make a character of any other class.")
        return
    end
    -- Synchronous, so the row exists before anything else asks for it.
    CharDBQuery(string.format(
        "INSERT IGNORE INTO `warband_company` (`guid`, `account`, `gold`) VALUES (%d, %d, %d)",
        guid, player:GetAccountId(), Config.commander.start_gold))
    Load(guid)
    player:SetLevel(Config.commander.start_level)
    player:RemoveItem(Config.lockdown.hearthstone, player:GetItemCount(Config.lockdown.hearthstone))
    Log.Event(guid, "company_created", player:GetName())
    -- Wait a moment: teleporting in the middle of a first login can fail.
    player:RegisterEvent(function(_, _, _, p)
        p:Teleport(Config.hub.map, Config.hub.x, Config.hub.y, Config.hub.z, Config.hub.o)
        p:SendBroadcastMessage("|cffffd100[Warband]|r Welcome to " .. Config.hub.name
            .. ", Commander. Your company starts here. Talk to Sergeant Marlow, or type |cffffffff.warband|r, to see the contracts.")
        Ready(p)
    end, 1500, 1)
end

-- Hooks ------------------------------------------------------------------------------------

RegisterPlayerEvent(PLAYER_EVENT_ON_FIRST_LOGIN, function(event, player)
    if player:IsBot() then return end
    MakeCommander(player)
end)

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, function(event, player)
    if player:IsBot() then return end
    if Load(player:GetGUIDLow()) then Ready(player) end
end)

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, function(event, player)
    cache[player:GetGUIDLow()] = nil
end)

RegisterPlayerEvent(PLAYER_EVENT_ON_CHARACTER_DELETE, function(event, guid)
    -- The company's heroes and recruits go back to the hero pool for other companies.
    CharDBExecute("DELETE FROM `warband_heroes` WHERE `company` = " .. guid)
    CharDBExecute("DELETE FROM `warband_recruits` WHERE `company` = " .. guid)
    CharDBExecute("DELETE FROM `warband_missions` WHERE `company` = " .. guid)
    CharDBExecute("DELETE FROM `warband_company` WHERE `guid` = " .. guid)
    cache[guid] = nil
end)

-- After ".reload ale" nobody logs in again, so load everyone already online.
for _, player in ipairs(GetPlayersInWorld()) do
    if not player:IsBot() then Load(player:GetGUIDLow()) end
end

return Company
