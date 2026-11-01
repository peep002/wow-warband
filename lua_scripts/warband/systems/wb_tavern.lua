-- wb_tavern.lua
-- The tavern: recruits waiting to be hired, saved in warband_recruits.
--   * A new company's first tavern shows Config.tavern.founding_offers recruits (always including
--     a tank, a healer and damage dealers); the first founding_free of them are free.
--   * After every mission the unhired recruits leave and a new batch arrives: Config.tavern.size
--     recruits (by tavern level), costing gold, arriving a few levels below the roster's average.
--   * Each recruit is a real character from the hero pool, with a class and spec, one good and one
--     bad trait, and a one-line backstory. Hiring puts it on the roster (wb_roster).
--
--   Tavern.Offers(player)          the recruits waiting, each a table
--   Tavern.FoundingLeft(player)    free founding hires still available (0 once founding is over)
--   Tavern.Hire(player, guid)      returns ok, message
--   Tavern.OnChange(fn)            fn(player) when the offers change
--
-- Use from other files:  local Tavern = require("wb_tavern")

local Config   = require("wb_config")
local Company  = require("wb_company")
local Missions = require("wb_missions")
local Roster   = require("wb_roster")
local Log      = require("wb_log")

local Tavern = {}

local T = Config.tavern
local changeHandlers = {}

function Tavern.OnChange(fn) changeHandlers[#changeHandlers + 1] = fn end
local function Changed(player) for _, fn in ipairs(changeHandlers) do fn(player) end end

local function Pick(list) return list[math.random(#list)] end

local function Keys(t, filter)
    local keys = {}
    for k, v in pairs(t) do
        if not filter or filter(v) then keys[#keys + 1] = k end
    end
    table.sort(keys) -- same order every time, so math.random alone decides
    return keys
end

-- Every (class, spec) a recruit can have for a role ("any" = all).
local function SpecsFor(role, act)
    local list = {}
    for class, specs in pairs(Config.specs) do
        if class ~= 6 or act >= Config.heroes.dk_from_act then
            for _, s in ipairs(specs) do
                if role == "any" or s.role == role then list[#list + 1] = { class = class, spec = s } end
            end
        end
    end
    table.sort(list, function(a, b) return a.class * 10 + a.spec.no < b.class * 10 + b.spec.no end)
    return list
end

-- A free character of that class from the hero pool (not hired, not offered anywhere).
local function FreeCharacter(class)
    local q = CharDBQuery(string.format(
        "SELECT c.`guid` FROM `characters` c WHERE c.`account` = %d AND c.`class` = %d AND c.`online` = 0 "
        .. "AND NOT EXISTS (SELECT 1 FROM `warband_heroes` h WHERE h.`guid` = c.`guid`) "
        .. "AND NOT EXISTS (SELECT 1 FROM `warband_recruits` r WHERE r.`guid` = c.`guid`) ORDER BY RAND() LIMIT 1",
        Roster.HeroAccount(), class))
    return q and q:GetUInt32(0)
end

local function RecruitLevel(player, founding)
    local total, n = 0, 0
    for _, h in ipairs(Roster.List(player)) do
        if h.status == "alive" then total, n = total + h.level, n + 1 end
    end
    if founding or n == 0 then return math.max(T.min_level, player:GetLevel()) end
    return math.max(T.min_level, math.floor(total / n) - T.level_gap)
end

local function Roll(player, c, role, founding)
    local options = SpecsFor(role, c.act)
    for _ = 1, 6 do -- a class can run out in the pool: try another
        local pick = Pick(options)
        local guid = FreeCharacter(pick.class)
        if guid then
            local level = RecruitLevel(player, founding)
            local pos = Pick(Keys(Config.traits.positive, function(t) return not t.only or t.only == pick.spec.role end))
            local neg = Pick(Keys(Config.traits.negative))
            CharDBQuery(string.format(
                "INSERT INTO `warband_recruits` (`company`, `guid`, `spec_no`, `role`, `trait_pos`, `trait_neg`, `backstory`, `level`, `cost`, `founding`) "
                .. "VALUES (%d, %d, %d, '%s', '%s', '%s', '%s', %d, %d, %d)",
                c.guid, guid, pick.spec.no, pick.spec.role, pos, neg, Pick(Config.backstories):gsub("'", "\\'"), level,
                founding and 0 or (T.cost_base + T.cost_per_level * level), founding and 1 or 0))
            return true
        end
    end
    Log.Event(c.guid, "tavern_pool_empty", role)
    return false
end

local function Fill(player, founding)
    local c = Company.Get(player)
    CharDBQuery("DELETE FROM `warband_recruits` WHERE `company` = " .. c.guid)
    if founding then
        for _, role in ipairs(T.founding_roles) do Roll(player, c, role, true) end
        for _ = #T.founding_roles + 1, T.founding_offers do Roll(player, c, "any", true) end
    else
        for _ = 1, T.size[0] do Roll(player, c, "any", false) end -- tavern upgrades come in phase 11
    end
    Log.Event(c.guid, founding and "tavern_founding" or "tavern_refresh", "")
    Changed(player)
end

function Tavern.Offers(player)
    local c = Company.Get(player)
    local list = {}
    if not c then return list end
    local q = CharDBQuery("SELECT r.`guid`, c.`name`, c.`class`, c.`race`, r.`spec_no`, r.`role`, r.`trait_pos`, "
        .. "r.`trait_neg`, r.`backstory`, r.`level`, r.`cost`, r.`founding` FROM `warband_recruits` r "
        .. "JOIN `characters` c ON c.`guid` = r.`guid` WHERE r.`company` = " .. c.guid .. " ORDER BY c.`name`")
    if q then
        repeat
            list[#list + 1] = { guid = q:GetUInt32(0), name = q:GetString(1), class = q:GetUInt32(2), race = q:GetUInt32(3),
                spec_no = q:GetUInt32(4), role = q:GetString(5), trait_pos = q:GetString(6), trait_neg = q:GetString(7),
                backstory = q:GetString(8), level = q:GetUInt32(9), cost = q:GetUInt32(10), founding = q:GetUInt32(11) == 1 }
        until not q:NextRow()
    end
    return list
end

function Tavern.FoundingLeft(player)
    for _, r in ipairs(Tavern.Offers(player)) do
        if r.founding then return math.max(0, T.founding_free - Roster.Alive(player)) end
    end
    return 0
end

function Tavern.Hire(player, guid)
    local c = Company.Get(player)
    if not c then return false, "Only a commander can hire." end
    local r
    for _, offer in ipairs(Tavern.Offers(player)) do
        if offer.guid == guid then r = offer end
    end
    if not r then return false, "That recruit isn't in your tavern any more." end
    if Roster.Alive(player) >= Config.heroes.roster_slots then
        return false, string.format("Your roster is full (%d heroes). The barracks can be expanded later.", Config.heroes.roster_slots)
    end
    if not r.founding then
        if c.gold < r.cost then return false, string.format("%s wants %d gold; the company has %d.", r.name, r.cost, c.gold) end
        c.gold = c.gold - r.cost
        Company.Save(player)
    end
    CharDBQuery(string.format("DELETE FROM `warband_recruits` WHERE `company` = %d AND `guid` = %d", c.guid, guid))
    Roster.Add(player, { guid = guid, spec_no = r.spec_no, role = r.role, trait_pos = r.trait_pos,
                         trait_neg = r.trait_neg, backstory = r.backstory, start_level = r.level })
    Log.Event(c.guid, "hero_hired", string.format("%s class %d spec %d level %d cost %d", r.name, r.class, r.spec_no, r.level,
        r.founding and 0 or r.cost))
    -- Founding is over once the free hires are used: the other founding recruits leave.
    if r.founding and Roster.Alive(player) >= T.founding_free then
        CharDBQuery("DELETE FROM `warband_recruits` WHERE `company` = " .. c.guid .. " AND `founding` = 1")
    end
    Changed(player)
    return true, r.name .. " signs with the company."
end

-- A new company gets its founding recruits; every finished mission brings a new batch.
Company.OnReady(function(player, c)
    if Roster.Alive(player) == 0 and #Tavern.Offers(player) == 0 then Fill(player, true) end
end)

Missions.OnFinish(function(player)
    Fill(player, false)
end)

return Tavern
