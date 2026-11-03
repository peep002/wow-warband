-- wb_traits.lua
-- What heroes' traits do (phase 7). Each hero has one good and one bad trait (veterans two good),
-- rolled in the tavern (wb_tavern). Numbers in Config.trait_effects.
--   * Number traits are hidden auras (no buff icon), kept on party heroes at all times:
--     Stalwart Shield (+10% threat), Glass Jaw (+8% damage from melee and ranged crits).
--   * Behaviour traits act on missions, checked once a second per commander. "Once per fight":
--     a fight lasts while anyone alive in the party is in combat.
--       Coward       below 20% health in a fight: panics and runs for a few seconds
--       Selfless     an ally under 25% health: the enemies hitting them turn on the Selfless hero
--       Field Medic  someone down for 15 seconds: gets them back up (wounded, like any save)
--       Clumsy       some fights: a few seconds in, stumbles into another pack nearby
--       Hothead      some fights: right after the fight, charges the next pack
--   * Greedy is in the armory (Traits.Pocket picks who pockets a drop).
--   * Brave, Night Owl, Quartermaster, Lucky, Restless and Hates the Dark need stress, darkness,
--     supplies or chests (later phases); Traits.Has lets those systems ask.
--
--   Traits.Has(h, key)               does this hero (a roster table) have the trait?
--   Traits.Pocket(commander)         a Greedy hero in the party who pockets this drop, or nil
--   Traits.Pull(commander, unit, range)  make the nearest idle pack attack unit (returns it, or nil)
--   Traits.State(guid)               "coward,selfless,..." used this fight (tests)
--   Traits.Panic(commander, unit, us, key, below, label)   run in a panic (Coward, Fearful)
--   Traits.OnFightEnd(fn) / Traits.OnHeroTick(fn)          per-fight hooks for other systems
--
-- Use from other files:  local Traits = require("wb_traits")

local Config   = require("wb_config")
local Company  = require("wb_company")
local Roster   = require("wb_roster")
local Missions = require("wb_missions")
local Death    = require("wb_death")
local Log      = require("wb_log")

local Traits = {}
local E = Config.trait_effects

local used = {}   -- [hero guid] = { coward = true, ... }: used up until the fight ends
local fights = {} -- [commander guid] = { on = in a fight?, clumsy = { guid, at }, hothead = { guid, at } }

-- Other systems that act per fight (wb_stress): fn(commander, heroes) when a fight ends, and
-- fn(commander, x, us, party) for every living party hero on every mission tick (x = { unit, h },
-- us = that hero's "used this fight" table).
local fightEndHandlers, tickHandlers = {}, {}
function Traits.OnFightEnd(fn) fightEndHandlers[#fightEndHandlers + 1] = fn end
function Traits.OnHeroTick(fn) tickHandlers[#tickHandlers + 1] = fn end

function Traits.Has(h, key)
    return h ~= nil and (h.trait_pos == key or h.trait_pos2 == key or h.trait_neg == key)
end

function Traits.State(guid)
    local list = {}
    for k in pairs(used[guid] or {}) do list[#list + 1] = k end
    table.sort(list)
    return #list > 0 and table.concat(list, ",") or "none"
end

local function Tell(commander, text) commander:SendBroadcastMessage(text) end

-- The commander's heroes that are online in the party and alive on the roster: { { unit, h } }
local function Heroes(commander)
    local list = {}
    for _, unit in ipairs(Roster.PartyHeroes(commander)) do
        local h = Roster.Get(commander, unit:GetGUIDLow())
        if h and h.status == "alive" then list[#list + 1] = { unit = unit, h = h } end
    end
    return list
end

-- Hidden auras -------------------------------------------------------------------------------------
-- Auras vanish on death and logout, so they're checked every tick, everywhere (also in the hamlet).
-- Afflictions and virtues with an aura (Hopeless, Focused; wb_stress) are kept the same way.
local function KeepAuras(commander)
    local S = Config.stress.auras
    for _, x in ipairs(Heroes(commander)) do
        if x.unit:IsAlive() then
            local wanted = {}
            for key, spell in pairs(E.auras) do wanted[spell] = Traits.Has(x.h, key) end
            for key, spell in pairs(S) do wanted[spell] = x.h.resolve == key end
            for spell, want in pairs(wanted) do
                local has = x.unit:HasAura(spell)
                if want and not has then
                    x.unit:AddAura(spell, x.unit)
                elseif has and not want then
                    x.unit:RemoveAura(spell)
                end
            end
        end
    end
end

-- Pulling another pack (Clumsy, Hothead) ----------------------------------------------------------
-- The nearest living hostile monster that isn't fighting, isn't a boss (pulling the mission's
-- target early would be too cruel) and can be seen from where the hero stands.
local function IdleMonsterNear(unit, range, bossEntry)
    local best, bestDist
    for _, c in ipairs(unit:GetCreaturesInRange(range, 0, 1, 1) or {}) do
        if not c:IsInCombat() and not c:IsDungeonBoss() and not c:IsWorldBoss() and c:GetEntry() ~= bossEntry
            and not c:IsCivilian() and not c:IsTrigger() and unit:IsWithinLoS(c) then
            local d = unit:GetDistance(c)
            if not best or d < bestDist then best, bestDist = c, d end
        end
    end
    return best
end

function Traits.Pull(commander, unit, range)
    local m = Missions.Active(commander)
    local c = IdleMonsterNear(unit, range, m and m.def.boss or 0)
    if not c then return nil end
    c:AttackStart(unit)
    c:CallAssistance() -- the rest of its pack comes along
    return c
end

local function RollFor(commander, key, chance, after)
    for _, x in ipairs(Heroes(commander)) do
        if Traits.Has(x.h, key) and x.unit:IsAlive() and math.random() < chance then
            return { guid = x.h.guid, at = os.time() + after }
        end
    end
end

local function DoPull(commander, roll, range, text, event)
    local unit = GetPlayerByGUID(GetPlayerGUID(roll.guid))
    if not unit or not unit:IsAlive() then return end
    local c = Traits.Pull(commander, unit, range)
    if c then
        Tell(commander, string.format(text, unit:GetName()))
        Log.Event(commander:GetGUIDLow(), event, unit:GetName() .. " -> " .. c:GetName())
    end
end

-- The per-fight traits ------------------------------------------------------------------------------

-- In a fight and below `below`% health: runs in a panic for a few seconds, once per fight (us[key]).
-- Used by Coward here and by the Fearful affliction (wb_stress).
function Traits.Panic(commander, unit, us, key, below, label)
    if us[key] or not unit:IsInCombat() or unit:GetHealthPct() >= below then return end
    us[key] = true
    unit:SetFeared(true)
    Tell(commander, string.format("|cffff8020[Warband] %s panics and runs!|r (%s)", unit:GetName(), label))
    Log.Event(commander:GetGUIDLow(), "panic_" .. key, unit:GetName())
    local guid = unit:GetGUID()
    CreateLuaEvent(function()
        local u = GetPlayerByGUID(guid)
        if u then u:SetFeared(false) end
    end, E.coward.seconds * 1000, 1)
end

local function Selfless(commander, unit, us, party)
    if us.selfless then return end
    for _, ally in ipairs(party) do
        if ally ~= unit and ally:IsAlive() and ally:IsInCombat() and ally:GetHealthPct() < E.selfless.below
            and unit:GetDistance(ally) <= E.selfless.range then
            local turned = 0
            for _, a in ipairs(ally:GetAttackers() or {}) do
                if a:ToCreature() and a:IsAlive() then
                    -- Enough threat to take the monster's attention for sure (it switches at 110-130%).
                    local need = a:GetThreat(ally) * 1.5 + 500 - a:GetThreat(unit)
                    if need > 0 then a:AddThreat(unit, need) end
                    turned = turned + 1
                end
            end
            if turned > 0 then
                us.selfless = true
                Tell(commander, string.format("|cff20ff20[Warband] %s throws themself between %s and the enemy!|r (Selfless)",
                    unit:GetName(), ally == commander and "you" or ally:GetName()))
                Log.Event(commander:GetGUIDLow(), "trait_selfless", unit:GetName() .. " for " .. ally:GetName())
                return
            end
        end
    end
end

local function FieldMedic(commander, unit, us)
    if us.field_medic then return end
    for _, d in ipairs(Death.DownedIn(commander)) do
        if d.guid ~= unit:GetGUIDLow() and d.seconds >= E.field_medic.after then
            local down = GetPlayerByGUID(GetPlayerGUID(d.guid))
            if down then
                Tell(commander, string.format("|cff20ff20[Warband] %s gets %s back on their feet!|r (Field Medic)",
                    unit:GetName(), down == commander and "you" or down:GetName()))
                if Death.Save(commander, down, "field medic") then
                    us.field_medic = true
                    Log.Event(commander:GetGUIDLow(), "trait_field_medic", unit:GetName() .. " for " .. down:GetName())
                    return
                end
            end
        end
    end
end

local function Check(commander)
    local cguid = commander:GetGUIDLow()
    local heroes = Heroes(commander)
    local party = { commander }
    for _, x in ipairs(heroes) do party[#party + 1] = x.unit end

    local fighting = false
    for _, u in ipairs(party) do fighting = fighting or (u:IsAlive() and u:IsInCombat()) end
    local f = fights[cguid] or { on = false }
    fights[cguid] = f
    if fighting and not f.on then        -- a fight starts
        f.on, f.hothead = true, nil
        f.clumsy = RollFor(commander, "clumsy", E.clumsy.chance, E.clumsy.after)
    elseif not fighting and f.on then    -- a fight is over: "once per fight" starts again
        f.on, f.clumsy = false, nil
        for _, x in ipairs(heroes) do used[x.h.guid] = nil end
        f.hothead = RollFor(commander, "hothead", E.hothead.chance, E.hothead.after)
        for _, fn in ipairs(fightEndHandlers) do fn(commander, heroes) end
    end

    local now = os.time()
    if f.on and f.clumsy and now >= f.clumsy.at then
        DoPull(commander, f.clumsy, E.clumsy.range,
            "|cffff8020[Warband] %s stumbles into another pack!|r (Clumsy)", "trait_clumsy")
        f.clumsy = nil
    end
    if not f.on and f.hothead and now >= f.hothead.at then
        DoPull(commander, f.hothead, E.hothead.range,
            "|cffff8020[Warband] %s charges the next pack before the healer is ready!|r (Hothead)", "trait_hothead")
        f.hothead = nil
    end

    for _, x in ipairs(heroes) do
        if x.unit:IsAlive() then
            local us = used[x.h.guid] or {}
            used[x.h.guid] = us
            if Traits.Has(x.h, "coward") then Traits.Panic(commander, x.unit, us, "coward", E.coward.below, "Coward") end
            if Traits.Has(x.h, "selfless") then Selfless(commander, x.unit, us, party) end
            if Traits.Has(x.h, "field_medic") then FieldMedic(commander, x.unit, us) end
            for _, fn in ipairs(tickHandlers) do fn(commander, x, us, party) end
        end
    end
end

-- Greedy (trait) and Selfish (affliction, wb_stress): called by the armory for each item it's about
-- to store. Returns the hero's guid, name and why ("Greedy"/"Selfish"), or nil.
function Traits.Pocket(commander)
    for _, x in ipairs(Heroes(commander)) do
        if x.unit:IsAlive() then
            if Traits.Has(x.h, "greedy") and math.random() < E.greedy.chance then
                return x.h.guid, x.unit:GetName(), "Greedy"
            end
            if x.h.resolve == "selfish" and math.random() < Config.stress.selfish_chance then
                return x.h.guid, x.unit:GetName(), "Selfish"
            end
        end
    end
end

CreateLuaEvent(Log.Safe("traits tick", function()
    for _, player in ipairs(GetPlayersInWorld() or {}) do
        if Company.Get(player) and player:IsInWorld() then
            KeepAuras(player)
            local m = Missions.Active(player)
            if m and not m.finishing then Check(player) end
        end
    end
end), E.check_ms, 0)

-- A mission's end closes any fight that was going on.
Missions.OnFinish(function(commander)
    fights[commander:GetGUIDLow()] = nil
    for _, h in ipairs(Roster.List(commander)) do used[h.guid] = nil end
end)

return Traits
