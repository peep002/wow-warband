-- wb_missions.lua
-- Missions: embarking, finishing on the target boss's death, rewards, and coming home. The board's
-- offers come from wb_board. The active mission is saved in warband_missions (status 'active') and
-- the company's state says whether it's in the hamlet (0) or out on a mission (1), so both survive
-- a restart.
--   * Each embark starts a fresh copy of the dungeon (old saved copies are forgotten first).
--   * Rewards: experience for the commander and the heroes who went (wb_xp), act progress for main
--     missions, and beating the gate opens the next act.
--
--   Missions.Offers(player)       the list of mission keys the board offers right now
--   Missions.Active(player)       { id =, key =, def = } of the running mission, or nil
--   Missions.Embark(player, key)  returns ok, message
--   Missions.Abandon(player)      give up the running mission and go home
--   Missions.SendHome(player)     teleport the commander and their bots to the hamlet
--   Missions.PartyBots(player)    the bots in the commander's group
--   Missions.OnChange(fn)         fn(player) whenever the board or the mission state changes
--   Missions.OnFinish(fn)         fn(player, status) after a mission ends ("done" or "abandoned")
--
-- Use from other files:  local Missions = require("wb_missions")

local Config  = require("wb_config")
local Company = require("wb_company")
local Log     = require("wb_log")
local Roster  = require("wb_roster")
local Board   = require("wb_board")
local XP      = require("wb_xp")

local Missions = {}

local CREATURE_EVENT_ON_DIED = 4
local STATE_HAMLET, STATE_MISSION = 0, 1

local active = {}         -- [commander guid] = { id =, key =, def =, heroes = { guid, ... }, finishing = bool }
local changeHandlers, finishHandlers = {}, {}

function Missions.OnChange(fn) changeHandlers[#changeHandlers + 1] = fn end
local function Changed(player) for _, fn in ipairs(changeHandlers) do fn(player) end end
function Missions.OnFinish(fn) finishHandlers[#finishHandlers + 1] = fn end

function Missions.Offers(player)
    return Board.Get(player)
end

function Missions.Active(player)
    return player and active[player:GetGUIDLow()]
end

function Missions.PartyBots(player)
    local bots = {}
    local group = player:GetGroup()
    if not group then return bots end
    for _, m in ipairs(group:GetMembers()) do
        if m ~= player and m:IsBot() and m:IsInWorld() then bots[#bots + 1] = m end
    end
    return bots
end

-- [commander guid] = os.time() of the last party teleport. A teleport takes a few seconds,
-- so the lockdown's leash waits instead of teleporting the party a second time.
Missions.lastTeleport = {}

-- Moves the commander first, then each bot a moment later: inside a dungeon the leader's
-- arrival creates the group's instance, which the bots then join.
local function TeleportParty(player, map, spot)
    Missions.lastTeleport[player:GetGUIDLow()] = os.time()
    player:Teleport(map, spot.x, spot.y, spot.z, spot.o)
    local bots = Missions.PartyBots(player)
    for i, bot in ipairs(bots) do
        local guid = bot:GetGUID()
        CreateLuaEvent(function()
            local b = GetPlayerByGUID(guid)
            if b then b:Teleport(map, spot.x + i * 0.8, spot.y, spot.z, spot.o) end
        end, 1500 + i * 300, 1)
    end
end

function Missions.SendHome(player)
    TeleportParty(player, Config.hub.map, Config.hub)
end

-- Ending a mission (done or abandoned): history row, company back in the hamlet, party home.
local function Finish(player, status)
    local guid = player:GetGUIDLow()
    local m = active[guid]
    if not m then return end
    active[guid] = nil
    CharDBExecute(string.format(
        "UPDATE `warband_missions` SET `status` = '%s', `ended` = NOW() WHERE `id` = %d", status, m.id))
    local c = Company.Get(player)
    if c then
        c.state = STATE_HAMLET
        Company.Save(player)
    end
    -- Experience for everyone who went; heroes who came home from a completed mission count it.
    local worth = m.def.xp * (status == "done" and 1 or Config.xp.abandoned)
    local gained = { player:GetName() .. " +" .. XP.Grant(player, worth) }
    for _, hero in ipairs(Roster.PartyHeroes(player)) do
        gained[#gained + 1] = hero:GetName() .. " +" .. XP.Grant(hero, worth)
        if status == "done" then
            CharDBExecute("UPDATE `warband_heroes` SET `missions` = `missions` + 1 WHERE `guid` = " .. hero:GetGUIDLow())
            local h = Roster.Get(player, hero:GetGUIDLow())
            if h then h.missions = h.missions + 1 end
        end
    end
    player:SendBroadcastMessage(string.format("|cffffd100[Warband]|r Experience: about %.1f levels' worth each (%s).",
        worth, table.concat(gained, ", ")))
    if c and status == "done" then
        if m.def.kind == "main" then
            c.progress = c.progress + 1
        elseif m.def.kind == "gate" then
            if Config.acts[c.act + 1] then
                c.act, c.progress, c.threat = c.act + 1, 0, 0
                player:SendBroadcastMessage(string.format("|cff20ff20[Warband] The gate falls! Act %d: %s begins.|r",
                    c.act, Config.acts[c.act].name))
            else
                player:SendBroadcastMessage("|cff20ff20[Warband] The gate falls!|r The next act isn't built yet "
                    .. "(phase 12); until then the board keeps offering this act's contracts.")
            end
            Log.Event(guid, "act_gate_beaten", m.key)
        end
        Company.Save(player)
    end
    Log.Event(guid, "mission_" .. status, m.key)
    Board.Refresh(player)
    Missions.SendHome(player)
    for _, fn in ipairs(finishHandlers) do fn(player, status) end
    Changed(player)
end

function Missions.Embark(player, key)
    local c = Company.Get(player)
    if not c then return false, "Only a commander can take contracts." end
    if c.state ~= STATE_HAMLET or active[c.guid] then return false, "Your warband is already on a mission." end
    local offered = false
    for _, k in ipairs(Missions.Offers(player)) do offered = offered or k == key end
    local def = Config.missions[key]
    if not offered or not def then return false, "That contract isn't on the board." end
    if player:IsInCombat() then return false, "You can't march out in the middle of a fight." end
    if player:IsDead() then return false, "You can't lead a march while dead." end
    local heroes = Roster.PartyHeroes(player)
    if #heroes < Config.heroes.min_party then
        return false, string.format("Call at least %d hero%s from your roster first.", Config.heroes.min_party,
            Config.heroes.min_party == 1 and "" or "es")
    end
    if #Missions.PartyBots(player) > #heroes then
        return false, "Only your company's heroes can march. Send other bots away first (.playerbots bot remove NAME)."
    end

    -- A fresh copy of the dungeon: forget any saved copy the party still has from before.
    player:UnbindInstance(def.map, 0)
    for _, hero in ipairs(heroes) do hero:UnbindInstance(def.map, 0) end

    -- Synchronous, so the new row's id can be read straight back.
    CharDBQuery(string.format("INSERT INTO `warband_missions` (`company`, `mission_key`) VALUES (%d, '%s')", c.guid, key))
    local q = CharDBQuery(string.format(
        "SELECT MAX(`id`) FROM `warband_missions` WHERE `company` = %d AND `status` = 'active'", c.guid))
    active[c.guid] = { id = q and q:GetUInt32(0) or 0, key = key, def = def }
    c.state = STATE_MISSION
    Company.Save(player)
    Log.Event(c.guid, "mission_start", string.format("%s heroes=%d", key, #heroes))
    TeleportParty(player, def.map, def.entrance)
    player:SendBroadcastMessage(string.format("|cffffd100[Warband]|r Contract: %s. Objective: %s.", def.name, def.objective))
    Changed(player)
    return true
end

function Missions.Abandon(player)
    if not Missions.Active(player) then return false, "You're not on a mission." end
    player:SendBroadcastMessage("|cffffd100[Warband]|r Mission abandoned. The warband falls back to " .. Config.hub.name .. ".")
    Finish(player, "abandoned")
    return true
end

-- The target boss dies: whichever commander is on that mission in that same dungeon copy wins.
local function OnBossDied(event, creature, killer)
    local map, instance = creature:GetMapId(), creature:GetInstanceId()
    for guid, m in pairs(active) do
        local player = GetPlayerByGUID(GetPlayerGUID(guid))
        if player and not m.finishing and m.def.boss == creature:GetEntry()
            and player:GetMapId() == map and player:GetInstanceId() == instance then
            m.finishing = true
            Log.Event(guid, "mission_boss_killed", m.key)
            player:SendBroadcastMessage(string.format("|cff20ff20[Warband] Mission complete!|r Returning to %s in %d seconds.",
                Config.hub.name, Config.mission.return_seconds))
            local pguid = player:GetGUID()
            CreateLuaEvent(function()
                local p = GetPlayerByGUID(pguid)
                if p then Finish(p, "done") end
            end, Config.mission.return_seconds * 1000, 1)
        end
    end
end

local bossesHooked = {}
for _, def in pairs(Config.missions) do
    if not bossesHooked[def.boss] then
        bossesHooked[def.boss] = true
        RegisterCreatureEvent(def.boss, CREATURE_EVENT_ON_DIED, OnBossDied)
    end
end

-- Loading a commander's running mission at login (or after ".reload ale") ---------------------

local function LoadActive(player, c)
    local q = CharDBQuery(string.format(
        "SELECT `id`, `mission_key` FROM `warband_missions` WHERE `company` = %d AND `status` = 'active' ORDER BY `id` DESC LIMIT 1",
        c.guid))
    local def = q and Config.missions[q:GetString(1)]
    if def then
        active[c.guid] = { id = q:GetUInt32(0), key = q:GetString(1), def = def }
        if c.state ~= STATE_MISSION then c.state = STATE_MISSION; Company.Save(player) end
    else
        active[c.guid] = nil
        if q then -- a mission that no longer exists in the config
            CharDBExecute("UPDATE `warband_missions` SET `status` = 'abandoned', `ended` = NOW() WHERE `id` = " .. q:GetUInt32(0))
        end
        if c.state ~= STATE_HAMLET then c.state = STATE_HAMLET; Company.Save(player) end
    end
end

Company.OnReady(LoadActive)

for _, player in ipairs(GetPlayersInWorld()) do
    local c = Company.Get(player)
    if c then LoadActive(player, c) end
end

return Missions
