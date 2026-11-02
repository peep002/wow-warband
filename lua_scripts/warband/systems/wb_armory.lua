-- wb_armory.lua
-- The shared armory (table warband_armory) and the company's currencies.
--   * Loot: every weapon and piece of armour the commander or a hero loots (or wins in a roll) is
--     taken out of their bags and stored in the armory. Trade goods become materials; items nobody
--     on the roster could ever use are salvaged into materials straight away; quest items and
--     consumables stay where they are. Coin from monsters is taken away (closed economy).
--   * Equipping: in the hamlet, any armory item can be put on the commander or a hero in the party;
--     whatever they wore in that slot goes back into the armory. Items keep their random suffix.
--   * Suggestions: an item "is an upgrade" when it scores better than what's worn (item level x
--     quality, lighter-than-best armour counts less). "Equip all upgrades" does them all at once.
--   * Selling (the only way to turn items into gold) and salvaging (into materials).
--   * A hero who dies for good leaves their bag gear to the armory; what they wore stays on them.
--   * Mission rewards: gold and renown (Config.rewards); new commanders get starter gear.
--
--   Armory.List(player)                     items, each a table (see Read)
--   Armory.Targets(player)                  who can be equipped now: the commander and party heroes
--   Armory.Equip(player, id, targetGuid)    0 = the commander; returns ok, message
--   Armory.EquipAll(player)                 returns ok, message
--   Armory.Upgrades(player)                 { [item id] = { { guid =, name =, gain = 0.12 }, ... } }
--   Armory.Sell(player, id) / Armory.Salvage(player, id) / Armory.SellJunk(player)
--
-- Use from other files:  local Armory = require("wb_armory")

local Config   = require("wb_config")
local Company  = require("wb_company")
local Roster   = require("wb_roster")
local Missions = require("wb_missions")
local Log      = require("wb_log")

local Armory = {}

local PLAYER_EVENT_ON_LOOT_ITEM = 32
local PLAYER_EVENT_ON_LOOT_MONEY = 37
local PLAYER_EVENT_ON_GROUP_ROLL_REWARD_ITEM = 56
local ITEM_CLASS_WEAPON, ITEM_CLASS_ARMOR, ITEM_CLASS_TRADE_GOODS = 2, 4, 7
local A = Config.armory

local changeHandlers = {}
function Armory.OnChange(fn) changeHandlers[#changeHandlers + 1] = fn end
local function Changed(player) for _, fn in ipairs(changeHandlers) do fn(player) end end

-- Which equipment slot(s) an inventory type goes in (0 head ... 18 tabard).
local SLOTS = {
    [1] = { 0 }, [2] = { 1 }, [3] = { 2 }, [4] = { 3 }, [5] = { 4 }, [20] = { 4 }, [6] = { 5 }, [7] = { 6 },
    [8] = { 7 }, [9] = { 8 }, [10] = { 9 }, [11] = { 10, 11 }, [12] = { 12, 13 }, [16] = { 14 },
    [13] = { 15, 16 }, [17] = { 15 }, [21] = { 15 }, [22] = { 16 }, [14] = { 16 }, [23] = { 16 },
    [15] = { 17 }, [25] = { 17 }, [26] = { 17 }, [28] = { 17 }, [19] = { 18 },
}
Armory.SLOTS = SLOTS

local function Contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- The company a player belongs to, as a commander guid (theirs, or their commander's).
local function CompanyGuid(player)
    if Company.IsCommander(player) then return player:GetGUIDLow() end
    return Roster.OwnerOf(player:GetGUIDLow())
end

-- Item templates, read once per entry from the world database.
local templates = {}
local function Template(entry)
    if templates[entry] == nil then
        local q = WorldDBQuery("SELECT `name`, `class`, `subclass`, `Quality`, `InventoryType`, `ItemLevel`, `RequiredLevel`, "
            .. "`AllowableClass`, `SellPrice` FROM `item_template` WHERE `entry` = " .. entry)
        templates[entry] = q and { entry = entry, name = q:GetString(0), class = q:GetUInt32(1), subclass = q:GetUInt32(2),
            quality = q:GetUInt32(3), invtype = q:GetUInt32(4), ilvl = q:GetUInt32(5), reqlevel = q:GetUInt32(6),
            allow = q:GetInt32(7), sell = q:GetUInt32(8) } or false
    end
    return templates[entry] or nil
end
Armory.Template = Template

-- Could a character of this class ever use the item (armour/weapon type, class restriction)?
local function ClassCanUse(t, class)
    if t.allow ~= -1 and t.allow ~= 0 and bit32 and bit32.band(t.allow, bit32.lshift(1, class - 1)) == 0 then return false end
    local p = Config.proficiency[class]
    if not p then return false end
    if t.class == ITEM_CLASS_ARMOR then
        return t.subclass == 0 or t.invtype == 16 or Contains(p.armor, t.subclass) -- misc and cloaks: anyone
    elseif t.class == ITEM_CLASS_WEAPON then
        return Contains(p.weapons, t.subclass)
    end
    return false
end

local function BestArmor(class, level)
    local best, from = 1, 0
    for lvl, sub in pairs(Config.proficiency[class].best_armor) do
        if level >= lvl and lvl >= from then best, from = sub, lvl end
    end
    return best
end

-- How good an item is for this character (0 = can't use it).
local function Score(t, class, level)
    if not t or not ClassCanUse(t, class) then return 0 end
    local s = t.ilvl * (A.quality_score[t.quality] or 1)
    if t.class == ITEM_CLASS_ARMOR and t.subclass >= 1 and t.subclass <= 4 and t.invtype ~= 16
        and t.subclass < BestArmor(class, level) then
        s = s * A.lower_armor_score
    end
    return s
end

-- Storing --------------------------------------------------------------------------------------------

local function SalvageValue(t)
    return math.floor((A.salvage[t.quality] or 0) + t.ilvl * A.salvage_per_ilvl)
end

-- Everyone whose class counts for "could anyone use this": the commander and living heroes.
local function RosterClasses(commanderGuid)
    local classes = {}
    local commander = GetPlayerByGUID(GetPlayerGUID(commanderGuid))
    if commander then
        classes[commander:GetClass()] = true
        for _, h in ipairs(Roster.List(commander)) do
            if h.status == "alive" then classes[h.class] = true end
        end
    end
    return classes
end

local function AddMaterials(commanderGuid, n)
    local commander = GetPlayerByGUID(GetPlayerGUID(commanderGuid))
    local c = Company.GetByGuid(commanderGuid)
    if not c or n <= 0 then return end
    c.materials = c.materials + n
    if commander then Company.Save(commander) end
end

-- Puts an item into the company's armory (or turns it into materials). Returns what happened:
-- "stored", "materials", "salvaged", "pocketed" or nil (not armory material: leave it where it is).
-- pocket = a Greedy hero's guid: the item is kept for them, out of sight, until they fall.
function Armory.Store(commanderGuid, entry, count, prop, suffix, pocket)
    local t = Template(entry)
    if not t then return nil end
    if t.class == ITEM_CLASS_TRADE_GOODS then
        AddMaterials(commanderGuid, count * A.trade_good)
        return "materials"
    end
    if t.class ~= ITEM_CLASS_WEAPON and t.class ~= ITEM_CLASS_ARMOR then return nil end
    if t.invtype == 4 or t.invtype == 19 then return nil end -- shirts and tabards stay with their owner
    local usable = t.quality == 0 -- grey junk is kept, to be sold
    for class in pairs(RosterClasses(commanderGuid)) do usable = usable or ClassCanUse(t, class) end
    if not usable then
        AddMaterials(commanderGuid, SalvageValue(t) * count)
        Log.Event(commanderGuid, "armory_salvaged", t.name)
        return "salvaged"
    end
    CharDBQuery(string.format("INSERT INTO `warband_armory` (`company`, `entry`, `count`, `prop`, `suffix`, `pocket`) "
        .. "VALUES (%d, %d, %d, %d, %d, %d)", commanderGuid, entry, count, prop or 0, suffix or 0, pocket or 0))
    Log.Event(commanderGuid, pocket and "armory_pocketed" or "armory_stored", t.name)
    return pocket and "pocketed" or "stored"
end

-- Moves an item a character holds into the armory (removing it from them). Returns the result.
local function TakeIntoArmory(commanderGuid, holder, item, count, pocket)
    local result = Armory.Store(commanderGuid, item:GetEntry(), count or item:GetCount(), item:GetRandomProperty(),
        item:GetRandomSuffix(), pocket)
    if result then holder:RemoveItem(item, count or item:GetCount()) end
    return result
end

local SAYS = { stored = "goes to the armory", materials = "becomes materials", salvaged = "is salvaged into materials" }

local function OnLoot(event, player, item, count)
    local cguid = CompanyGuid(player)
    if not cguid or not item then return end
    local name = item:GetName()
    local commander = GetPlayerByGUID(GetPlayerGUID(cguid))
    -- Greedy heroes: a chance per item that one of them keeps it (only worth it for real gear).
    local pocket, pocketName
    if commander and (item:GetClass() == ITEM_CLASS_WEAPON or item:GetClass() == ITEM_CLASS_ARMOR) then
        pocket, pocketName = require("wb_traits").Pocket(commander)
    end
    local result = TakeIntoArmory(cguid, player, item, count, pocket)
    if commander and result then
        if result == "pocketed" then
            commander:SendBroadcastMessage(string.format("|cffff8020[Warband] %s pockets %s|r instead of handing it in. (Greedy)",
                pocketName, name))
        else
            commander:SendBroadcastMessage(string.format("|cffffd100[Warband]|r %s %s.", name, SAYS[result]))
        end
        Changed(commander)
    end
end
Armory.OnLoot = OnLoot -- for tests: the same path a real loot takes
RegisterPlayerEvent(PLAYER_EVENT_ON_LOOT_ITEM, Log.Safe("armory loot", OnLoot))
RegisterPlayerEvent(PLAYER_EVENT_ON_GROUP_ROLL_REWARD_ITEM, Log.Safe("armory roll", function(event, player, item, count)
    OnLoot(event, player, item, count)
end))

-- Coin from monsters is taken back: in Warband all gold comes from the campaign.
RegisterPlayerEvent(PLAYER_EVENT_ON_LOOT_MONEY, Log.Safe("armory coin", function(event, player, amount)
    if CompanyGuid(player) and amount > 0 then player:ModifyMoney(-amount) end
end))

-- A hero who died for good leaves the gear in their bags to the armory (green or better: their bags
-- also hold the plain clothes they started life with).
local function Keep(item)
    local t = Template(item:GetEntry())
    return t and t.quality >= 2
end
Roster.OnKilled(function(commander, bot)
    -- What a Greedy hero pocketed turns up in their things.
    local q = CharDBQuery(string.format("SELECT COUNT(*) FROM `warband_armory` WHERE `company` = %d AND `pocket` = %d",
        commander:GetGUIDLow(), bot:GetGUIDLow()))
    local found = q and q:GetUInt32(0) or 0
    if found > 0 then
        CharDBQuery(string.format("UPDATE `warband_armory` SET `pocket` = 0 WHERE `company` = %d AND `pocket` = %d",
            commander:GetGUIDLow(), bot:GetGUIDLow()))
        commander:SendBroadcastMessage(string.format("|cffffd100[Warband]|r Among %s's things: %d pocketed item%s, back in the armory.",
            bot:GetName(), found, found == 1 and "" or "s"))
        Log.Event(commander:GetGUIDLow(), "armory_unpocketed", bot:GetName() .. " " .. found)
    end
    for bag = 255, 255 do -- the backpack (bags 19-22 too)
        for slot = 23, 38 do
            local item = bot:GetItemByPos(bag, slot)
            if item and Keep(item) then TakeIntoArmory(commander:GetGUIDLow(), bot, item) end
        end
    end
    for bag = 19, 22 do
        for slot = 0, 35 do
            local item = bot:GetItemByPos(bag, slot)
            if item and Keep(item) then TakeIntoArmory(commander:GetGUIDLow(), bot, item) end
        end
    end
end)

-- Reading -----------------------------------------------------------------------------------------------

function Armory.List(player)
    local list = {}
    local q = CharDBQuery("SELECT `id`, `entry`, `count`, `prop`, `suffix` FROM `warband_armory` WHERE `company` = "
        .. player:GetGUIDLow() .. " AND `pocket` = 0 ORDER BY `id` DESC")
    if q then
        repeat
            local t = Template(q:GetUInt32(1))
            if t then
                list[#list + 1] = { id = q:GetUInt32(0), entry = t.entry, count = q:GetUInt32(2), prop = q:GetUInt32(3),
                    suffix = q:GetUInt32(4), name = t.name, quality = t.quality, ilvl = t.ilvl, reqlevel = t.reqlevel,
                    invtype = t.invtype, class = t.class, subclass = t.subclass,
                    sell = math.max(t.sell > 0 and 1 or 0, math.floor(t.sell * A.sell_rate)), salvage = SalvageValue(t) }
            end
        until not q:NextRow()
    end
    return list
end

local function Find(player, id)
    for _, it in ipairs(Armory.List(player)) do
        if it.id == id then return it end
    end
end

-- Who can be equipped right now: the commander and the heroes in the party (online).
function Armory.Targets(player)
    local list = { player }
    for _, hero in ipairs(Roster.PartyHeroes(player)) do
        local h = Roster.Get(player, hero:GetGUIDLow())
        if h and h.status == "alive" and hero:IsAlive() then list[#list + 1] = hero end
    end
    return list
end

local function Worn(unit, slot)
    local item = unit:GetEquippedItemBySlot(slot)
    return item, item and Template(item:GetEntry())
end

-- The best slot for this item on this character, and how much better it is (0 = not an upgrade).
local function BestSlot(unit, t, byHand)
    local slots = SLOTS[t.invtype]
    if not slots then return nil, 0 end
    if t.quality == 0 and not byHand then return nil, 0 end -- grey junk is never suggested (only handed out by hand)
    local new = Score(t, unit:GetClass(), unit:GetLevel())
    if new <= 0 or t.reqlevel > unit:GetLevel() then return nil, 0 end
    local bestSlot, bestOld
    for _, slot in ipairs(slots) do
        if slot ~= 16 or t.invtype ~= 13 or unit:HasSpell(674) then -- 674 = Dual Wield
            local _, wt = Worn(unit, slot)
            local old = wt and Score(wt, unit:GetClass(), unit:GetLevel()) or 0
            if not bestOld or old < bestOld then bestSlot, bestOld = slot, old end
        end
    end
    if not bestSlot then return nil, 0 end
    local gain = bestOld > 0 and (new / bestOld - 1) or 1
    return bestSlot, gain
end

function Armory.Upgrades(player)
    local result = {}
    for _, it in ipairs(Armory.List(player)) do
        local t = Template(it.entry)
        for _, unit in ipairs(Armory.Targets(player)) do
            local slot, gain = BestSlot(unit, t)
            if slot and gain >= A.upgrade_margin - 1 then
                result[it.id] = result[it.id] or {}
                table.insert(result[it.id], { guid = unit == player and 0 or unit:GetGUIDLow(), name = unit:GetName(), gain = gain })
            end
        end
    end
    return result
end

-- Equipping ------------------------------------------------------------------------------------------------

local function InHamlet(player)
    local c = Company.Get(player)
    return c and c.state == 0
end

local function TargetOf(player, guid)
    if guid == 0 then return player end
    for _, unit in ipairs(Armory.Targets(player)) do
        if unit:GetGUIDLow() == guid then return unit end
    end
end

-- Creates the armory item in the target's bags and equips it into slot; whatever was worn there
-- goes back to the armory. Returns ok, message.
-- Every step is checked by looking at what's really worn afterwards: mod-ale's EquipItem reports
-- success even when it fails, and an item only counts as back in the armory once it's really off.
local function PutOn(player, unit, it, slot)
    local cguid = player:GetGUIDLow()
    local item = unit:AddItem(it.entry, 1)
    if not item then return false, unit:GetName() .. "'s bags are full." end
    if it.prop > 0 then item:SetRandomProperty(it.prop) end
    if it.suffix > 0 then item:SetRandomSuffix(it.suffix) end
    local oldItem = unit:GetEquippedItemBySlot(slot)
    local old
    if oldItem then
        old = { entry = oldItem:GetEntry(), prop = oldItem:GetRandomProperty(), suffix = oldItem:GetRandomSuffix() }
        unit:RemoveItem(oldItem, 1)
        if unit:GetEquippedItemBySlot(slot) then
            unit:RemoveItem(item, 1)
            return false, string.format("%s's %s couldn't be taken off.", unit:GetName(), Template(old.entry).name)
        end
    end
    unit:EquipItem(item, slot)
    local now = unit:GetEquippedItemBySlot(slot)
    if not now or now:GetEntry() ~= it.entry then
        unit:RemoveItem(it.entry, 1)                         -- the new item, still in the bags
        if old then                                          -- put the old one back on
            local back = unit:AddItem(old.entry, 1)
            if back then
                if old.prop > 0 then back:SetRandomProperty(old.prop) end
                if old.suffix > 0 then back:SetRandomSuffix(old.suffix) end
                unit:EquipItem(back, slot)
            end
        end
        return false, string.format("%s can't wear %s.", unit:GetName(), it.name)
    end
    if old then
        CharDBQuery(string.format("INSERT INTO `warband_armory` (`company`, `entry`, `count`, `prop`, `suffix`) VALUES (%d, %d, 1, %d, %d)",
            cguid, old.entry, old.prop, old.suffix))
    end
    if it.count > 1 then
        CharDBExecute(string.format("UPDATE `warband_armory` SET `count` = `count` - 1 WHERE `id` = %d", it.id))
    else
        CharDBQuery("DELETE FROM `warband_armory` WHERE `id` = " .. it.id)
    end
    unit:SaveToDB()
    Log.Event(cguid, "armory_equipped", string.format("%s -> %s slot %d", it.name, unit:GetName(), slot))
    return true, string.format("%s equips %s.", unit == player and "You" or unit:GetName(), it.name)
end

function Armory.Equip(player, id, targetGuid)
    if not InHamlet(player) then return false, "Gear is handed out in the hamlet." end
    local it = Find(player, id)
    if not it then return false, "That item isn't in the armory any more." end
    local unit = TargetOf(player, targetGuid)
    if not unit then return false, "Only you and the heroes in your party can be equipped. Call them first." end
    local t = Template(it.entry)
    if Score(t, unit:GetClass(), unit:GetLevel()) <= 0 then
        return false, string.format("%s can't use %s.", unit:GetName(), it.name)
    end
    if t.reqlevel > unit:GetLevel() then
        return false, string.format("%s needs level %d.", it.name, t.reqlevel)
    end
    local slot = BestSlot(unit, t, true)
    if not slot then return false, string.format("%s can't wear %s.", unit:GetName(), it.name) end
    local ok, message = PutOn(player, unit, it, slot)
    Changed(player)
    return ok, message
end

function Armory.EquipAll(player)
    if not InHamlet(player) then return false, "Gear is handed out in the hamlet." end
    local done = 0
    -- Biggest gains first, so the best item goes where it helps most.
    for _ = 1, 40 do
        local bestIt, bestUnit, bestSlot, bestGain
        for _, it in ipairs(Armory.List(player)) do
            local t = Template(it.entry)
            for _, unit in ipairs(Armory.Targets(player)) do
                local slot, gain = BestSlot(unit, t)
                if slot and gain >= A.upgrade_margin - 1 and (not bestGain or gain > bestGain) then
                    bestIt, bestUnit, bestSlot, bestGain = it, unit, slot, gain
                end
            end
        end
        if not bestIt then break end
        if PutOn(player, bestUnit, bestIt, bestSlot) then done = done + 1 else break end
    end
    Changed(player)
    if done == 0 then return false, "No upgrades in the armory for you or your party." end
    return true, string.format("%d upgrade%s equipped.", done, done == 1 and "" or "s")
end

-- Selling and salvaging ---------------------------------------------------------------------------------------

local function Remove(it)
    CharDBQuery("DELETE FROM `warband_armory` WHERE `id` = " .. it.id)
end

function Armory.Sell(player, id)
    local c = Company.Get(player)
    local it = c and Find(player, id)
    if not it then return false, "That item isn't in the armory any more." end
    local gold = it.sell * it.count
    Remove(it)
    c.gold = c.gold + gold
    Company.Save(player)
    Log.Event(c.guid, "armory_sold", string.format("%s for %d", it.name, gold))
    Changed(player)
    return true, string.format("Sold %s for %d gold.", it.name, gold)
end

function Armory.SellJunk(player)
    local c = Company.Get(player)
    if not c then return false end
    local n, gold = 0, 0
    for _, it in ipairs(Armory.List(player)) do
        if it.quality == 0 then
            Remove(it)
            n, gold = n + 1, gold + it.sell * it.count
        end
    end
    if n == 0 then return false, "No junk in the armory." end
    c.gold = c.gold + gold
    Company.Save(player)
    Changed(player)
    return true, string.format("Sold %d junk item%s for %d gold.", n, n == 1 and "" or "s", gold)
end

function Armory.Salvage(player, id)
    local c = Company.Get(player)
    local it = c and Find(player, id)
    if not it then return false, "That item isn't in the armory any more." end
    local n = it.salvage * it.count
    Remove(it)
    c.materials = c.materials + n
    Company.Save(player)
    Log.Event(c.guid, "armory_salvaged", it.name)
    Changed(player)
    return true, string.format("Salvaged %s into %d materials.", it.name, n)
end

-- Mission rewards: gold and renown -------------------------------------------------------------------------------

Missions.OnFinish(function(player, status, def)
    local c = Company.Get(player)
    if not c or not def then return end
    local length = def.kind == "gate" and "gate" or def.length
    local R = Config.rewards
    local share = status == "done" and 1 or (status == "abandoned" and R.abandoned_gold or R.failed_gold)
    local gold = math.floor((R.gold[length] or 0) * share)
    local renown = status == "done" and (R.renown[length] or 0) or 0
    if gold == 0 and renown == 0 then return end
    c.gold, c.renown = c.gold + gold, c.renown + renown
    Company.Save(player)
    Log.Event(c.guid, "reward", string.format("%s gold=%d renown=%d", status, gold, renown))
    player:SendBroadcastMessage(string.format("|cffffd100[Warband]|r The company earns %d gold%s.", gold,
        renown > 0 and (" and " .. renown .. " renown") or ""))
end)

-- Starter gear for a new commander ----------------------------------------------------------------------------------

local function StarterItem(where)
    local S = Config.starter
    local q = WorldDBQuery(string.format("SELECT `entry` FROM `item_template` WHERE %s AND `Quality` = %d "
        .. "AND `RequiredLevel` BETWEEN %d AND %d AND `RandomProperty` = 0 AND `RandomSuffix` = 0 "
        -- (items that need a reputation or a profession can't be worn by a new character)
        .. "AND `RequiredReputationFaction` = 0 AND `RequiredSkill` = 0 AND `RequiredSpell` = 0 "
        .. "AND `AllowableClass` IN (-1, 0, 32767, 262143) ORDER BY RAND() LIMIT 1", where, S.quality, S.min_level, S.max_level))
    return q and q:GetUInt32(0)
end

function Armory.GiveStarterGear(player)
    local class = player:GetClass()
    local S = Config.starter
    local given = 0
    local armor = BestArmor(class, player:GetLevel())
    -- The level-1 starting clothes and weapon make way (they're worthless).
    local function Wear(entry, slot)
        local old = player:GetEquippedItemBySlot(slot)
        if old then player:RemoveItem(old, 1) end
        if player:EquipItem(entry, slot) then given = given + 1 end
    end
    for _, invtype in ipairs(S.armor_slots) do
        local entry = StarterItem(string.format("`class` = 4 AND `subclass` = %d AND `InventoryType` IN (%d%s)", armor, invtype,
            invtype == 5 and ", 20" or ""))
        local slot = SLOTS[invtype] and SLOTS[invtype][1]
        if entry and slot then Wear(entry, slot) end
    end
    local options = S.weapon[class]
    if options then
        local w = options[math.random(#options)]
        local entry = StarterItem(string.format("`class` = 2 AND `subclass` = %d AND `InventoryType` = %d", w[1], w[2]))
        local slot = SLOTS[w[2]] and SLOTS[w[2]][1]
        if entry and slot then
            if w[2] == 17 then -- a two-hander: the off-hand must be empty
                local off = player:GetEquippedItemBySlot(16)
                if off then player:RemoveItem(off, 1) end
            end
            Wear(entry, slot)
        end
    end
    Log.Event(player:GetGUIDLow(), "starter_gear", tostring(given))
    return given
end

Company.OnCreated(function(player) Armory.GiveStarterGear(player) end)

return Armory
