-- wb_stress.lua
-- Stress, afflictions and virtues (phase 8). Heroes only: the commander has no stress.
--   * Every hero has stress 0-200 (warband_heroes.stress). Numbers in Config.stress.
--   * Gains on a mission: a heavy hit, an ally downed or killed for good; at the end, by the
--     mission's length, plus more for abandoning or failing. Brave heroes gain 25% less.
--   * Sitting a mission out in the barracks relieves a little (a Restless hero gains instead).
--   * At 100, a resolve check: an affliction (Paranoid, Hopeless, Selfish, Fearful, Abusive), or
--     sometimes a virtue (Stalwart, Courageous, Focused), which also drops stress to 50. A virtue
--     lasts until the end of the mission (or the next one, if it came at a mission's end); an
--     affliction lasts until stress is relieved below 50.
--   * At 200, on a mission: a heart attack, straight to death's door (stress back to 150).
--   * Relief in the hamlet: a drink at the tavern, for gold.
--
--   Stress.Add(commander, h, amount, why)   change a hero's stress (h = a roster table)
--   Stress.SetResolve(commander, h, key)    give an affliction or virtue ("" clears) (tests)
--   Stress.Resolve(h)                       the hero's resolve entry from Config.resolves, or nil
--   Stress.DrinkCost(level) / Stress.Drink(player, guid)   relief at the tavern: ok, message
--   Stress.OnHeavyHit(target, damage)       the heavy-hit check (the damage hook and tests use it)
--
-- Use from other files:  local Stress = require("wb_stress")

local Config   = require("wb_config")
local Company  = require("wb_company")
local Roster   = require("wb_roster")
local Missions = require("wb_missions")
local Death    = require("wb_death")
local Traits   = require("wb_traits")
local Armory   = require("wb_armory")
local Log      = require("wb_log")

local Stress = {}
local S = Config.stress

local PLAYER_EVENT_ON_HEAL = 65
local ALL_CREATURE_EVENT_ON_DEAL_DAMAGE = 13

local lastHit = {}  -- [hero guid] = os.time() of the last heavy hit that counted

local function Tell(commander, text) commander:SendBroadcastMessage(text) end

function Stress.Resolve(h)
    return h and h.resolve ~= "" and Config.resolves[h.resolve] or nil
end

local function OnMission(commander)
    local m = Missions.Active(commander)
    return m ~= nil and not m.finishing
end

-- Living heroes online in the commander's party: { { h = roster table, unit = character }, ... }
local function PartyHeroes(commander)
    local list = {}
    for _, unit in ipairs(Roster.PartyHeroes(commander)) do
        local h = Roster.Get(commander, unit:GetGUIDLow())
        if h and h.status == "alive" then list[#list + 1] = { h = h, unit = unit } end
    end
    return list
end

function Stress.SetResolve(commander, h, key)
    local before = Stress.Resolve(h)
    h.resolve = key or ""
    local r = Stress.Resolve(h)
    h.resolve_left = (r and r.kind == "virtue") and 1 or 0
    Roster.Save(h, { "resolve", "resolve_left" })
    -- A Selfish hero who is cured hands back what they kept.
    if before and before.name == "Selfish" and h.resolve ~= "selfish" then
        Armory.Unpocket(commander, h.guid, h.name, "%s comes to their senses and returns")
    end
    Roster.Touch(commander)
end

local function Save(commander, h)
    Roster.Save(h, { "stress" })
    Roster.Touch(commander)
end

-- The resolve check at 100: an affliction, or (virtue_chance) a virtue.
local function ResolveCheck(commander, h)
    local kind = math.random() < S.virtue_chance and "virtue" or "affliction"
    local keys = {}
    for key, r in pairs(Config.resolves) do
        if r.kind == kind then keys[#keys + 1] = key end
    end
    table.sort(keys)
    local key = keys[math.random(#keys)]
    Stress.SetResolve(commander, h, key)
    local r = Config.resolves[key]
    if kind == "virtue" then
        h.stress = math.min(h.stress, S.virtue_sets)
        Save(commander, h)
        Tell(commander, string.format("|cff40c0ff[Warband] %s's resolve is tested... %s!|r %s", h.name, r.name:upper(), r.text))
    else
        Tell(commander, string.format("|cffff4040[Warband] %s's resolve is tested... %s.|r %s", h.name, r.name:upper(), r.text))
    end
    Log.Event(commander:GetGUIDLow(), "resolve_" .. kind, h.name .. " " .. key)
end

local function HeartAttack(commander, h)
    local unit = GetPlayerByGUID(GetPlayerGUID(h.guid))
    h.stress = S.after_heart_attack
    Save(commander, h)
    Log.Event(commander:GetGUIDLow(), "heart_attack", h.name)
    Tell(commander, string.format("|cffff2020[Warband] %s's heart gives out under the strain!|r", h.name))
    if unit and unit:IsAlive() then
        unit:SetHealth(1)
        commander:Kill(unit, false) -- death's door takes it from here (wb_death)
    end
end

-- The one way stress changes. amount > 0 is a gain (Brave heroes gain less), < 0 relief.
function Stress.Add(commander, h, amount, why)
    if not h or h.status ~= "alive" or amount == 0 then return end
    if amount > 0 and Traits.Has(h, "brave") then amount = amount * S.brave end
    amount = amount > 0 and math.max(1, math.floor(amount + 0.5)) or math.floor(amount + 0.5)
    local before = h.stress
    h.stress = math.max(0, math.min(S.max, before + amount))
    -- A heart attack only happens on a mission; elsewhere stress stops just short of it.
    local mission = OnMission(commander)
    if not mission and h.stress >= S.heart_attack_at then h.stress = S.heart_attack_at - 1 end
    if h.stress == before then return end
    Save(commander, h)
    Log.Event(commander:GetGUIDLow(), "stress", string.format("%s %+d (%s) = %d", h.name, h.stress - before, why or "?", h.stress))

    local r = Stress.Resolve(h)
    if before < S.resolve_at and h.stress >= S.resolve_at and not r then
        ResolveCheck(commander, h)
    elseif r and r.kind == "affliction" and h.stress < S.cure_below then
        Tell(commander, string.format("|cff20ff20[Warband] %s is no longer %s.|r", h.name, r.name))
        Log.Event(commander:GetGUIDLow(), "resolve_cured", h.name .. " " .. h.resolve)
        Stress.SetResolve(commander, h, "")
    end
    if mission and h.stress >= S.heart_attack_at then HeartAttack(commander, h) end
end

-- Gains on a mission --------------------------------------------------------------------------------

-- A heavy hit on a hero (one blow for at least S.heavy_hit of their max health). Courageous heroes
-- standing in the party keep everyone else calm.
function Stress.OnHeavyHit(target, damage)
    if not target or not target:IsPlayer() or damage <= 0 then return end
    local guid = target:GetGUIDLow()
    local cguid = Roster.OwnerOf(guid)
    if not cguid or damage < target:GetMaxHealth() * S.heavy_hit then return end
    local commander = GetPlayerByGUID(GetPlayerGUID(cguid))
    if not commander or not OnMission(commander) then return end
    local now = os.time()
    if lastHit[guid] and now - lastHit[guid] < S.heavy_hit_cooldown then return end
    local h = Roster.Get(commander, guid)
    if not h or h.status ~= "alive" then return end
    for _, x in ipairs(PartyHeroes(commander)) do
        if x.h.guid ~= guid and x.h.resolve == "courageous" and x.unit:IsAlive() then return end
    end
    lastHit[guid] = now
    Stress.Add(commander, h, S.heavy_hit_stress, "heavy hit")
    return true
end

RegisterAllCreatureEvent(ALL_CREATURE_EVENT_ON_DEAL_DAMAGE, Log.Safe("stress hit", function(event, creature, target, damage)
    Stress.OnHeavyHit(target, damage) -- returns nothing to the server: the damage stays as it is
end))

-- Someone in the party goes down: everyone else standing feels it.
Death.OnDown(function(commander, unit)
    if not OnMission(commander) then return end
    local amount = unit == commander and S.commander_downed or S.ally_downed
    for _, x in ipairs(PartyHeroes(commander)) do
        if x.h.guid ~= unit:GetGUIDLow() and x.unit:IsAlive() then
            Stress.Add(commander, x.h, amount, (unit == commander and "commander" or unit:GetName()) .. " down")
        end
    end
end)

-- A hero dies for good: the rest of the party.
Roster.OnKilled(function(commander, bot)
    for _, x in ipairs(PartyHeroes(commander)) do
        if x.h.guid ~= bot:GetGUIDLow() then Stress.Add(commander, x.h, S.ally_died, bot:GetName() .. " died") end
    end
end)

-- Afflictions in a fight -----------------------------------------------------------------------------

-- Fearful: panics like a Coward, at higher health.
Traits.OnHeroTick(function(commander, x, us)
    if x.h.resolve == "fearful" then
        Traits.Panic(commander, x.unit, us, "fearful", S.fearful_below, "Fearful")
    end
end)

-- Abusive: after every fight, the others gain stress.
Traits.OnFightEnd(function(commander, heroes)
    for _, x in ipairs(heroes) do
        if x.h.resolve == "abusive" and x.unit:IsAlive() then
            Tell(commander, string.format("|cffff8020[Warband] %s lashes out at the others.|r (Abusive)", x.h.name))
            for _, y in ipairs(heroes) do
                if y.h.guid ~= x.h.guid then Stress.Add(commander, y.h, S.abusive, x.h.name .. " abusive") end
            end
        end
    end
end)

-- Paranoid: refuses some of the heals others cast on them.
RegisterPlayerEvent(PLAYER_EVENT_ON_HEAL, Log.Safe("stress heal", function(event, healer, target, gain)
    if not target or not target:IsPlayer() or target == healer then return end
    local cguid = Roster.OwnerOf(target:GetGUIDLow())
    if not cguid then return end
    local commander = GetPlayerByGUID(GetPlayerGUID(cguid))
    local h = commander and Roster.Get(commander, target:GetGUIDLow())
    if h and h.resolve == "paranoid" and math.random() < S.paranoid_refuse then return 0 end
end))

-- Stalwart: can't die for good while the virtue lasts.
Death.Guard(function(commander, h) return h.resolve == "stalwart" end)

-- The end of a mission -------------------------------------------------------------------------------

Missions.OnFinish(function(commander, status, def)
    for _, h in ipairs(Roster.List(commander)) do
        if h.status == "alive" then
            if h.in_party then
                -- Virtues gained before this point end now; one gained just below lasts the next mission.
                local r = Stress.Resolve(h)
                if r and r.kind == "virtue" then
                    Tell(commander, string.format("|cffa0a0a0[Warband] %s is no longer %s.|r", h.name, r.name))
                    Stress.SetResolve(commander, h, "")
                end
                local gain = S.mission[def.kind == "gate" and "gate" or def.length] or 0
                if status == "abandoned" then gain = gain + S.abandoned end
                if status == "failed" then gain = gain + S.failed end
                Stress.Add(commander, h, gain, "mission " .. status)
            elseif Traits.Has(h, "restless") then
                Stress.Add(commander, h, S.restless_bench, "benched, restless")
            else
                Stress.Add(commander, h, S.bench, "rested")
            end
        end
    end
end)

-- Relief in the hamlet -------------------------------------------------------------------------------

function Stress.DrinkCost(level)
    return S.drink.cost_base + S.drink.cost_per_level * level
end

function Stress.Drink(player, guid)
    local c = Company.Get(player)
    local h = c and Roster.Get(player, guid)
    if not h or h.status ~= "alive" then return false, "That hero isn't on your roster." end
    if c.state ~= 0 then return false, "Drinks are had in the hamlet, between missions." end
    if h.stress == 0 then return false, h.name .. " isn't stressed." end
    local cost = Stress.DrinkCost(h.level)
    if c.gold < cost then return false, string.format("A round costs %d gold; the company has %d.", cost, c.gold) end
    c.gold = c.gold - cost
    Company.Save(player)
    local before = h.stress
    Stress.Add(player, h, -S.drink.amount, "tavern")
    return true, string.format("%s drinks at the tavern: stress %d -> %d (%d gold).", h.name, before, h.stress, cost)
end

return Stress
