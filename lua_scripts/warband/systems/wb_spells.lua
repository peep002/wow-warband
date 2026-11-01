-- wb_spells.lua
-- Commanders learn their class spells automatically on every level-up, because the closed
-- world has no class trainers to visit. Bots don't need this: playerbots teaches them itself.
-- The spell list comes from the world database's class trainers (trainer / trainer_spell), the
-- same list a real trainer would offer, so nothing is hand-written here.
--
--   Spells.Teach(player)   learn everything the player's class could train at their level
--
-- Use from other files:  local Spells = require("wb_spells")

local Company = require("wb_company")

local Spells = {}

local PLAYER_EVENT_ON_LEVEL_CHANGE = 13
local SPELL_EFFECT_LEARN_SPELL = 36

local byClass = {} -- [class] = { { spell =, level =, skill = }, ... } sorted by level

-- One class has several trainers (one per city) with the same spells; use the biggest list.
local function LoadClass(class)
    local best = WorldDBQuery(string.format([[
        SELECT t.`Id` FROM `trainer` t JOIN `trainer_spell` s ON s.`TrainerId` = t.`Id`
        WHERE t.`Type` = 0 AND t.`Requirement` = %d GROUP BY t.`Id` ORDER BY COUNT(*) DESC LIMIT 1]], class))
    local list = {}
    if best then
        local q = WorldDBQuery(string.format(
            "SELECT `SpellId`, `ReqLevel`, `ReqSkillLine` FROM `trainer_spell` WHERE `TrainerId` = %d ORDER BY `ReqLevel`",
            best:GetUInt32(0)))
        if q then
            repeat
                list[#list + 1] = { spell = q:GetUInt32(0), level = q:GetUInt32(1), skill = q:GetUInt32(2) }
            until not q:NextRow()
        end
    end
    byClass[class] = list
    return list
end

function Spells.Teach(player)
    local list = byClass[player:GetClass()] or LoadClass(player:GetClass())
    local level = player:GetLevel()
    for _, e in ipairs(list) do
        if e.level <= level and (e.skill == 0 or player:HasSkill(e.skill)) then
            local info = GetSpellInfo(e.spell)
            if info and info:HasEffect(SPELL_EFFECT_LEARN_SPELL) then
                -- A "teaching" spell (as a trainer casts it): casting it learns what it wraps.
                player:CastSpell(player, e.spell, true)
            elseif not player:HasSpell(e.spell) then
                player:LearnSpell(e.spell)
            end
        end
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, function(event, player)
    if Company.IsCommander(player) then Spells.Teach(player) end
end)

return Spells
