-- wb_death.lua
-- Death's door and permadeath, on missions. (First version, as decided: the hero really dies, and
-- "Downed" is the time their body can still be saved. A true kneeling-at-1-health state would
-- need C++.)
--   * Someone in the party dies -> Downed: the party is told, and the bleed-out clock starts.
--   * Saved if, before Config.death.bleed_seconds: a resurrection spell brings them back (a bot
--     healer, a battle-res, a soulstone...), or the fight ends (nobody alive in the party in combat
--     for safe_seconds), which brings everyone down back at revive_health.
--   * A saved hero is wounded (-10% max health until treated, or after sitting out a mission).
--   * A hero dies for good if they bleed out, or go down while already wounded: memorial wall.
--   * The commander can't die for good: if they bleed out the mission fails, they wake up in the
--     hamlet wounded, and heroes still down are carried home (wounded). If the whole party is down
--     at once it's a wipe: the mission fails and every downed hero is lost.
--   * While Downed, a released ghost can't reclaim its corpse or use a spirit healer.
-- Checked once a second for every commander out on a mission.
--
--   Death.State(player)   "alive", "downed" (with seconds left) for tests and the window

local Config   = require("wb_config")
local Company  = require("wb_company")
local Roster   = require("wb_roster")
local Missions = require("wb_missions")
local Log      = require("wb_log")

local Death = {}

local PLAYER_EVENT_ON_CAN_RESURRECT = 59
local GHOST_AURA = 8326
local D = Config.death

local downed = {}    -- [guid] = { at = os.time(), commander = commander guid, hold = bool (tests) }
local allowNow = {}  -- [guid] = true during our own revive
local calmSince = {} -- [commander guid] = os.time() the party was last seen with nobody in combat

function Death.State(player)
    local d = downed[player:GetGUIDLow()]
    if not d then return "alive" end
    return "downed", math.max(0, D.bleed_seconds - (os.time() - d.at))
end

-- Tests: stop the fight-is-over rescue for someone, or make their clock run out.
function Death.Hold(guid) if downed[guid] then downed[guid].hold = true end end
function Death.Expire(guid) if downed[guid] then downed[guid].at = os.time() - D.bleed_seconds end end

-- Who is down in this commander's party: { { guid = , seconds = time down }, ... }
function Death.DownedIn(commander)
    local list, now = {}, os.time()
    for guid, d in pairs(downed) do
        if d.commander == commander:GetGUIDLow() then list[#list + 1] = { guid = guid, seconds = now - d.at } end
    end
    return list
end

local function Revive(unit, health)
    allowNow[unit:GetGUIDLow()] = true
    unit:ResurrectPlayer(health)
    allowNow[unit:GetGUIDLow()] = nil
end

-- Everyone who counts for this commander's mission: the commander and the heroes in the group.
local function Party(commander)
    local list = { commander }
    for _, hero in ipairs(Roster.PartyHeroes(commander)) do
        local h = Roster.Get(commander, hero:GetGUIDLow())
        if h and h.status == "alive" then list[#list + 1] = hero end
    end
    return list
end

local function Tell(commander, text)
    commander:SendBroadcastMessage(text)
end

local function MissionPlace(commander)
    local m = Missions.Active(commander)
    return m and m.def.dungeon or "the field", m and m.key or ""
end

-- Someone just went down.
local function OnDown(commander, unit)
    local guid = unit:GetGUIDLow()
    local isCommander = unit == commander
    local h = not isCommander and Roster.Get(commander, guid)
    local place, key = MissionPlace(commander)
    if h and h.wounded then
        downed[guid] = nil
        Roster.Kill(commander, guid, string.format("Fell again in %s while still wounded.", place), key)
        return
    end
    downed[guid] = { at = os.time(), commander = commander:GetGUIDLow() }
    Log.Event(commander:GetGUIDLow(), "downed", unit:GetName())
    Tell(commander, string.format("|cffff8020[Warband] %s is down!|r %d seconds to save %s: a resurrection, or end the fight.",
        isCommander and "You are" or unit:GetName(), D.bleed_seconds, isCommander and "you" or "them"))
end

-- Someone down is back on their feet (a spell, or the fight ended).
local function OnSaved(commander, unit, how)
    local guid = unit:GetGUIDLow()
    downed[guid] = nil
    Log.Event(commander:GetGUIDLow(), "saved", unit:GetName() .. " " .. how)
    if unit == commander then
        Tell(commander, "|cff20ff20[Warband] You're back on your feet.|r")
        return
    end
    local h = Roster.Get(commander, guid)
    if h then
        Roster.SetWounded(commander, h, true)
        Tell(commander, string.format("|cff20ff20[Warband] %s is saved,|r but wounded (-10%% health) until treated or rested.",
            unit:GetName()))
    end
end

-- Another system saves someone who is down (a Field Medic, wb_traits): back up at revive_health,
-- and wounded like any saved hero. Returns true if they were down.
function Death.Save(commander, unit, how)
    if not downed[unit:GetGUIDLow()] or not unit:IsDead() then return false end
    Revive(unit, D.revive_health)
    OnSaved(commander, unit, how)
    return true
end

-- A revive done just before the trip home doesn't always survive the teleport (people arrived
-- dead in testing), so a few seconds after arriving, anyone in the party still dead is revived
-- for sure, and wounds are shown again (dying removes the aura).
local function AfterArrival(commanderGuid)
    CreateLuaEvent(function()
        local commander = GetPlayerByGUID(commanderGuid)
        if not commander then return end
        local c = Company.Get(commander)
        for _, unit in ipairs(Party(commander)) do
            if unit:IsDead() then Revive(unit, D.revive_health) end
            if unit == commander then
                Roster.ShowWound(unit, c and c.wounded == 1)
            else
                local h = Roster.Get(commander, unit:GetGUIDLow())
                Roster.ShowWound(unit, h and h.wounded)
            end
        end
    end, 4000, 1)
end

-- The mission is lost: the commander wakes up at home, wounded.
local function FailMission(commander, wipe)
    local place, key = MissionPlace(commander)
    for guid, d in pairs(downed) do
        if d.commander == commander:GetGUIDLow() and guid ~= commander:GetGUIDLow() then
            downed[guid] = nil
            local hero = GetPlayerByGUID(GetPlayerGUID(guid))
            if wipe then
                Roster.Kill(commander, guid, string.format("Lost when the warband was wiped out in %s.", place), key)
            elseif hero then
                Revive(hero, D.revive_health) -- carried home by the survivors
                local h = Roster.Get(commander, guid)
                if h then Roster.SetWounded(commander, h, true) end
            end
        end
    end
    downed[commander:GetGUIDLow()] = nil
    calmSince[commander:GetGUIDLow()] = nil
    if commander:IsDead() then Revive(commander, D.revive_health) end
    Log.Event(commander:GetGUIDLow(), wipe and "mission_wipe" or "commander_bled_out", key)
    Missions.Fail(commander)
    -- After Fail (whose end-of-mission handlers heal the commander's old wound).
    local c = Company.Get(commander)
    if c then
        c.wounded = 1
        Company.Save(commander)
    end
    Tell(commander, "|cffff2020[Warband] You wake up in " .. Config.hub.name .. ", wounded.|r Treat it from the Roster tab.")
    AfterArrival(commander:GetGUID())
end

local function Check(commander)
    local cguid = commander:GetGUIDLow()
    local party = Party(commander)

    -- New deaths, and people back on their feet.
    local anyAlive, anyFighting = false, false
    for _, unit in ipairs(party) do
        local guid = unit:GetGUIDLow()
        if unit:IsDead() then
            if not downed[guid] then OnDown(commander, unit) end
        else
            if downed[guid] then OnSaved(commander, unit, "resurrected") end
            anyAlive = true
            anyFighting = anyFighting or unit:IsInCombat()
        end
    end

    -- Everyone down at once: a wipe.
    if not anyAlive then return FailMission(commander, true) end

    -- Bleeding out.
    local now = os.time()
    for guid, d in pairs(downed) do
        if d.commander == cguid and now - d.at >= D.bleed_seconds then
            if guid == cguid then return FailMission(commander, false) end
            downed[guid] = nil
            local place, key = MissionPlace(commander)
            Roster.Kill(commander, guid, string.format("Bled out in %s.", place), key)
        end
    end

    -- The fight is over: everyone still down is pulled back up.
    if anyFighting then
        calmSince[cguid] = nil
    else
        calmSince[cguid] = calmSince[cguid] or now
        if now - calmSince[cguid] >= D.safe_seconds then
            for guid, d in pairs(downed) do
                if d.commander == cguid and not d.hold and now - d.at >= D.safe_seconds then
                    local unit = GetPlayerByGUID(GetPlayerGUID(guid))
                    if unit then
                        Revive(unit, D.revive_health)
                        OnSaved(commander, unit, "fight over")
                    end
                end
            end
        end
    end
end

CreateLuaEvent(Log.Safe("death tick", function()
    for _, guid in ipairs(Missions.ActiveCommanders()) do
        local commander = GetPlayerByGUID(GetPlayerGUID(guid))
        if commander and commander:IsInWorld() and not Missions.Active(commander).finishing then Check(commander) end
    end
end), 1000, 0)

-- No ghost tricks while Downed, and no coming back at all once dead for good.
RegisterPlayerEvent(PLAYER_EVENT_ON_CAN_RESURRECT, Log.Safe("can resurrect", function(event, player)
    local guid = player:GetGUIDLow()
    if allowNow[guid] then return true end
    local commanderGuid = Roster.OwnerOf(guid)
    if commanderGuid then
        local commander = GetPlayerByGUID(GetPlayerGUID(commanderGuid))
        local h = commander and Roster.Get(commander, guid)
        if h and h.status ~= "alive" then return false end
    end
    if downed[guid] and player:HasAura(GHOST_AURA) then
        player:SendBroadcastMessage("|cffff2020[Warband]|r You can't walk back from death on a mission: someone has to save you.")
        return false
    end
    return true -- mod-ale treats "no answer" as no, which would block everyone
end))

-- After a mission: heroes who sat it out in the barracks rest off their wounds, and a commander
-- who came home (not from a failure) is healed too.
Missions.OnFinish(function(commander, status)
    for _, h in ipairs(Roster.List(commander)) do
        if h.status == "alive" and h.wounded and not h.in_party then Roster.SetWounded(commander, h, false) end
    end
    local c = Company.Get(commander)
    if c and c.wounded == 1 and status ~= "failed" then
        c.wounded = 0
        Company.Save(commander)
        Roster.ShowWound(commander, false)
        Tell(commander, "|cff20ff20[Warband] Your wound has healed.|r")
    end
    -- Anyone still down when a mission ends well (the boss died, or a retreat) is carried home:
    -- back on their feet, and wounded if they're a hero.
    for guid, d in pairs(downed) do
        if d.commander == commander:GetGUIDLow() then
            downed[guid] = nil
            local unit = GetPlayerByGUID(GetPlayerGUID(guid))
            if unit and unit:IsDead() then
                Revive(unit, D.revive_health)
                OnSaved(commander, unit, "carried home")
            end
        end
    end
    calmSince[commander:GetGUIDLow()] = nil
    if status ~= "failed" then AfterArrival(commander:GetGUID()) end -- (a failure calls it itself)
end)

return Death
