-- wb_xp.lua
-- Experience for commanders and their heroes.
--   * Monsters give only Config.xp.kill_rate (10%) of their normal XP: missions are the real source.
--   * Mission XP is counted in "levels": Grant(player, 2.0) gives as much XP as two level-ups at the
--     player's current level (a level-10 and a level-14 hero both gain about two levels).
--   * Nobody levels past the current act's max level until its gate is beaten.
-- Characters outside Warband (no company, not a hero) are never touched.
--
--   XP.Cap(player)            the level this player can't pass right now (nil = not in Warband)
--   XP.Grant(player, levels)  returns the XP given
--
-- Use from other files:  local XP = require("wb_xp")

local Config  = require("wb_config")
local Company = require("wb_company")
local Roster  = require("wb_roster")
local Log     = require("wb_log")

local XP = {}

local PLAYER_EVENT_ON_GIVE_XP = 12
local PLAYER_NEXT_LEVEL_XP = 635 -- update field: XP needed for the next level (UpdateFields.h)

local granting = {} -- [guid] = true while Grant is handing out XP, so the kill-XP cut skips it
XP.lastCut = {}     -- [guid] = { normal XP, XP given } of the last cut kill, for tests

-- The company this player belongs to: their own as a commander, or their commander's as a hero.
local function CompanyOf(player)
    local c = Company.Get(player)
    if c then return c end
    local commander = Roster.OwnerOf(player:GetGUIDLow())
    return commander and Company.GetByGuid(commander)
end

function XP.Cap(player)
    local c = CompanyOf(player)
    if not c then return nil end
    local act = Config.acts[c.act] or Config.acts[#Config.acts]
    return act.max_level
end

function XP.Grant(player, levels)
    local cap = XP.Cap(player)
    if not cap or levels <= 0 then return 0 end
    local guid, given = player:GetGUIDLow(), 0
    granting[guid] = true
    -- One level at a time: each step is priced at the level the player is at then.
    while levels > 0 and player:GetLevel() < cap do
        local need = player:GetUInt32Value(PLAYER_NEXT_LEVEL_XP)
        local left = need - player:GetXP()
        if need <= 0 or left <= 0 then break end
        local step = math.min(left, math.floor(levels * need + 0.5))
        if step <= 0 then break end
        player:GiveXP(step)
        given = given + step
        levels = levels - step / need
    end
    granting[guid] = nil
    return given
end

RegisterPlayerEvent(PLAYER_EVENT_ON_GIVE_XP, Log.Safe("xp give", function(event, player, amount)
    if granting[player:GetGUIDLow()] then return amount end
    local cap = XP.Cap(player)
    if not cap then return amount end
    local given = player:GetLevel() >= cap and 0 or math.floor(amount * Config.xp.kill_rate)
    XP.lastCut[player:GetGUIDLow()] = { amount, given }
    return given
end))

return XP
