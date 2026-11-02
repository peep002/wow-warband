-- wb_roster.lua
-- A company's heroes: hired bot characters, saved in warband_heroes.
--   * Heroes live on the hero account (Config.heroes.account). Each commander's account is linked
--     to it in playerbots' tables, which is what lets the commander control them as bots.
--   * "Calling" a hero logs the bot in; playerbots puts it in the commander's group and we move it
--     next to the commander. "Sending" it to the barracks logs it out. Heroes that were in the party
--     come back by themselves when the commander logs in again.
--   * The first time a hero logs in it's set up for real: playerbots' factory gives it its level,
--     class spells, gear, and the talent spec it was recruited with.
--
--   Roster.List(player)            the company's heroes (alive first), each a table
--   Roster.Get(player, guid)       one hero of this company, or nil
--   Roster.OwnerOf(heroGuid)       the commander guid a hero belongs to, or nil
--   Roster.SetWounded(player, h, bool) / Roster.Treat(player, guid or 0 = commander)
--   Roster.ShowWound(unit, bool)   put the wound's -10% health aura on (or off) a character
--   Roster.Kill(player, guid, cause, missionKey)   permanent death: memorial wall, bot sent away
--   Roster.Memorial(player)        the company's fallen, newest first
--   Roster.Alive(player)           how many heroes are alive
--   Roster.PartyHeroes(player)     heroes that are online in the commander's group
--   Roster.Call(player, guid)      returns ok, message
--   Roster.Send(player, guid)      returns ok, message
--   Roster.Add(player, fields)     put a newly hired character on the roster (wb_tavern)
--   Roster.HeroAccount()           the hero account's id
--   Roster.OnChange(fn)            fn(player) when the roster changes
--
-- Use from other files:  local Roster = require("wb_roster")

local Config  = require("wb_config")
local Company = require("wb_company")
local Log     = require("wb_log")

local Roster = {}

local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_LEVEL_CHANGE = 13

local heroes = {}       -- [commander guid] = { [hero guid] = hero }
local owner = {}        -- [hero guid] = commander guid, for every loaded hero
local changeHandlers = {}

function Roster.OnChange(fn) changeHandlers[#changeHandlers + 1] = fn end
local function Changed(player) for _, fn in ipairs(changeHandlers) do fn(player) end end
local killedHandlers = {}
-- fn(commander, bot) when a hero dies for good, while the bot is still online (e.g. empty its bags)
function Roster.OnKilled(fn) killedHandlers[#killedHandlers + 1] = fn end

local heroAccount
function Roster.HeroAccount()
    if not heroAccount then
        local q = AuthDBQuery("SELECT `id` FROM `account` WHERE `username` = '" .. Config.heroes.account .. "'")
        heroAccount = q and q:GetUInt32(0) or 0
        if heroAccount == 0 then
            Log.Event(0, "setup_error", "hero account missing: run sql/updates/002_hero_pool.sql")
        end
    end
    return heroAccount
end

-- Lets this commander's account control the hero account's characters (playerbots checks this
-- table on every bot login, both directions written to be safe).
local function LinkAccount(account)
    local hero, db = Roster.HeroAccount(), Config.db.playerbots
    if hero == 0 then return end
    for _, pair in ipairs({ { hero, account }, { account, hero } }) do
        CharDBExecute(string.format(
            "INSERT INTO `%s`.`playerbots_account_links` (`account_id`, `linked_account_id`) "
            .. "SELECT %d, %d FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `%s`.`playerbots_account_links` "
            .. "WHERE `account_id` = %d AND `linked_account_id` = %d)",
            db, pair[1], pair[2], db, pair[1], pair[2]))
    end
end

local COLUMNS = "h.`guid`, c.`name`, c.`class`, c.`race`, c.`level`, h.`spec_no`, h.`role`, h.`trait_pos`, "
    .. "h.`trait_neg`, h.`backstory`, h.`status`, h.`in_party`, h.`set_up`, h.`start_level`, h.`missions`, h.`wounded`, "
    .. "h.`trait_pos2`, h.`gear_quality`"

local function ReadHero(q)
    return { guid = q:GetUInt32(0), name = q:GetString(1), class = q:GetUInt32(2), race = q:GetUInt32(3),
             level = q:GetUInt32(4), spec_no = q:GetUInt32(5), role = q:GetString(6), trait_pos = q:GetString(7),
             trait_neg = q:GetString(8), backstory = q:GetString(9), status = q:GetString(10),
             in_party = q:GetUInt32(11) == 1, set_up = q:GetUInt32(12) == 1, start_level = q:GetUInt32(13),
             missions = q:GetUInt32(14), wounded = q:GetUInt32(15) == 1, trait_pos2 = q:GetString(16),
             gear_quality = q:GetUInt32(17) }
end

-- Wounds -------------------------------------------------------------------------------------------
-- A wound is the "Wither Strike" aura (-10% max health) made to last until healed. Auras vanish on
-- death and logout, so it's put back on login and after every revive.

function Roster.ShowWound(unit, wounded)
    local spell = Config.death.wound_spell
    if not wounded then
        unit:RemoveAura(spell)
        return
    end
    if unit:IsDead() or unit:HasAura(spell) then return end
    local aura = unit:AddAura(spell, unit)
    if aura then
        aura:SetMaxDuration(-1)
        aura:SetDuration(-1)
    end
end

function Roster.TreatCost(level)
    return Config.infirmary.cost_base + Config.infirmary.cost_per_level * level
end

local function Load(commanderGuid)
    local list = {}
    local q = CharDBQuery("SELECT " .. COLUMNS .. " FROM `warband_heroes` h JOIN `characters` c ON c.`guid` = h.`guid` "
        .. "WHERE h.`company` = " .. commanderGuid)
    if q then
        repeat
            local h = ReadHero(q)
            list[h.guid] = h
            owner[h.guid] = commanderGuid
        until not q:NextRow()
    end
    heroes[commanderGuid] = list
    return list
end

local function Save(h, fields)
    local sets = {}
    for _, f in ipairs(fields) do
        local v = h[f]
        if type(v) == "boolean" then v = v and 1 or 0 end
        sets[#sets + 1] = type(v) == "number" and string.format("`%s` = %d", f, v) or string.format("`%s` = '%s'", f, v)
    end
    CharDBExecute("UPDATE `warband_heroes` SET " .. table.concat(sets, ", ") .. " WHERE `guid` = " .. h.guid)
end

function Roster.List(player)
    local list = {}
    for _, h in pairs(heroes[player:GetGUIDLow()] or {}) do
        local online = GetPlayerByGUID(GetPlayerGUID(h.guid))
        if online then h.level = online:GetLevel() end
        -- Not set up yet (never called): the character is still level 1 in the database, but
        -- it will arrive at the level it was hired at.
        if not h.set_up then h.level = h.start_level end
        list[#list + 1] = h
    end
    table.sort(list, function(a, b)
        if (a.status == "alive") ~= (b.status == "alive") then return a.status == "alive" end
        return a.name < b.name
    end)
    return list
end

-- The commander guid a hero belongs to (heroes of online commanders only), or nil.
function Roster.OwnerOf(heroGuid)
    return owner[heroGuid]
end

function Roster.Get(player, guid)
    return (heroes[player:GetGUIDLow()] or {})[guid]
end

function Roster.Alive(player)
    local n = 0
    for _, h in pairs(heroes[player:GetGUIDLow()] or {}) do
        if h.status == "alive" then n = n + 1 end
    end
    return n
end

function Roster.PartyHeroes(player)
    local list = {}
    local group = player:GetGroup()
    if not group then return list end
    local mine = heroes[player:GetGUIDLow()] or {}
    for _, m in ipairs(group:GetMembers()) do
        if m ~= player and mine[m:GetGUIDLow()] then list[#list + 1] = m end
    end
    return list
end

local function PartyCount(player)
    local n = 0
    for _, h in pairs(heroes[player:GetGUIDLow()] or {}) do
        if h.in_party and h.status == "alive" then n = n + 1 end
    end
    return n
end

local function BotMgr(player)
    local mgrs = GetPlayerbotsMgr()
    return mgrs and mgrs:GetPlayerbotMgr(player)
end

local function LogIn(player, h)
    local mgr = BotMgr(player)
    if not mgr then return false end
    mgr:AddPlayerBot(GetPlayerGUID(h.guid), player:GetAccountId())
    return true
end

function Roster.Call(player, guid)
    local c = Company.Get(player)
    local h = Roster.Get(player, guid)
    if not c or not h then return false, "That hero isn't on your roster." end
    if h.status ~= "alive" then return false, h.name .. " is no longer with the company." end
    if c.state ~= 0 then return false, "You can only change the party in the hamlet." end
    if h.in_party then
        -- In the party but not online (e.g. logged out with a playerbots command): bring them back.
        if GetPlayerByGUID(GetPlayerGUID(h.guid)) then return false, h.name .. " is already in your party." end
        LinkAccount(player:GetAccountId())
        if not LogIn(player, h) then return false, "The bot system isn't ready; try again in a moment." end
        return true, h.name .. " rejoins your party."
    end
    if PartyCount(player) >= Config.heroes.max_party then
        return false, string.format("Your party is full (%d heroes). Send someone to the barracks first.", Config.heroes.max_party)
    end
    LinkAccount(player:GetAccountId())
    h.in_party = true
    Save(h, { "in_party" })
    if not LogIn(player, h) then return false, "The bot system isn't ready; try again in a moment." end
    Log.Event(c.guid, "hero_called", h.name)
    Changed(player)
    return true, h.name .. " joins your party."
end

function Roster.Send(player, guid)
    local c = Company.Get(player)
    local h = Roster.Get(player, guid)
    if not c or not h then return false, "That hero isn't on your roster." end
    if c.state ~= 0 then return false, "You can only change the party in the hamlet." end
    if not h.in_party then return false, h.name .. " is already resting in the barracks." end
    h.in_party = false
    Save(h, { "in_party" })
    local mgr = BotMgr(player)
    if mgr then mgr:LogoutPlayerBot(GetPlayerGUID(h.guid)) end
    Log.Event(c.guid, "hero_sent", h.name)
    Changed(player)
    return true, h.name .. " heads to the barracks to rest."
end

-- fields: guid, spec_no, role, trait_pos, trait_pos2, trait_neg, backstory, start_level, gear_quality
function Roster.Add(player, f)
    local c = Company.Get(player)
    CharDBQuery(string.format(
        "INSERT INTO `warband_heroes` (`guid`, `company`, `spec_no`, `role`, `trait_pos`, `trait_pos2`, `trait_neg`, `backstory`, "
        .. "`start_level`, `gear_quality`) VALUES (%d, %d, %d, '%s', '%s', '%s', '%s', '%s', %d, %d)",
        f.guid, c.guid, f.spec_no, f.role, f.trait_pos, f.trait_pos2 or "", f.trait_neg, (f.backstory:gsub("'", "\\'")),
        f.start_level, f.gear_quality or Config.heroes.gear_quality))
    Load(c.guid)
    Changed(player)
    return Roster.Get(player, f.guid)
end

function Roster.SetWounded(player, h, wounded)
    h.wounded = wounded
    Save(h, { "wounded" })
    local bot = GetPlayerByGUID(GetPlayerGUID(h.guid))
    if bot then Roster.ShowWound(bot, wounded) end
    Log.Event(player:GetGUIDLow(), wounded and "hero_wounded" or "hero_healed", h.name)
    Changed(player)
end

-- Treat a wound for gold: guid of a hero, or 0 for the commander. Only in the hamlet.
function Roster.Treat(player, guid)
    local c = Company.Get(player)
    if not c then return false, "Only a commander can pay for treatment." end
    if c.state ~= 0 then return false, "Wounds are treated in the hamlet." end
    local name, level, wounded
    local h = guid ~= 0 and Roster.Get(player, guid)
    if guid == 0 then
        name, level, wounded = "Your wound", player:GetLevel(), c.wounded == 1
    elseif h and h.status == "alive" then
        name, level, wounded = h.name .. "'s wound", h.level, h.wounded
    else
        return false, "That hero isn't on your roster."
    end
    if not wounded then return false, "There's no wound to treat." end
    local cost = Roster.TreatCost(level)
    if c.gold < cost then return false, string.format("Treatment costs %d gold; the company has %d.", cost, c.gold) end
    c.gold = c.gold - cost
    if guid == 0 then
        c.wounded = 0
        Roster.ShowWound(player, false)
        Log.Event(c.guid, "commander_healed", "treated")
    end
    Company.Save(player)
    if h then Roster.SetWounded(player, h, false) else Changed(player) end
    return true, string.format("%s is treated (%d gold).", name, cost)
end

-- A hero dies for good: off the roster, onto the memorial wall. Their gear stays on the body (a
-- Recover the Fallen mission can bring it back later). The bot is sent away after a few seconds.
function Roster.Kill(player, guid, cause, missionKey)
    local h = Roster.Get(player, guid)
    if not h or h.status ~= "alive" then return end
    local bot = GetPlayerByGUID(GetPlayerGUID(guid))
    local level = bot and bot:GetLevel() or h.level
    if bot then for _, fn in ipairs(killedHandlers) do fn(player, bot) end end
    h.status, h.in_party, h.wounded = "dead", false, false
    Save(h, { "status", "in_party", "wounded" })
    CharDBQuery(string.format(
        "INSERT INTO `warband_memorial` (`company`, `guid`, `name`, `class`, `race`, `level`, `missions`, `cause`, `mission_key`) "
        .. "VALUES (%d, %d, '%s', %d, %d, %d, %d, '%s', '%s')",
        player:GetGUIDLow(), guid, h.name, h.class, h.race, level, h.missions, cause:gsub("'", "\\'"), missionKey or ""))
    Log.Event(player:GetGUIDLow(), "hero_died", h.name .. ": " .. cause)
    player:SendBroadcastMessage(string.format("|cffff2020[Warband] %s has fallen.|r %s Their name goes on the memorial wall.",
        h.name, cause))
    local pguid = player:GetGUID()
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(pguid)
        local mgr = p and BotMgr(p)
        if mgr and GetPlayerByGUID(GetPlayerGUID(guid)) then mgr:LogoutPlayerBot(GetPlayerGUID(guid)) end
    end, Config.death.logout_seconds * 1000, 1)
    Changed(player)
end

-- The memorial wall: everyone this company has lost, newest first.
function Roster.Memorial(player)
    local list = {}
    local q = CharDBQuery("SELECT `name`, `class`, `race`, `level`, `missions`, `cause`, DATE_FORMAT(`died`, '%Y-%m-%d') "
        .. "FROM `warband_memorial` WHERE `company` = " .. player:GetGUIDLow() .. " ORDER BY `id` DESC")
    if q then
        repeat
            list[#list + 1] = { name = q:GetString(0), class = q:GetUInt32(1), race = q:GetUInt32(2), level = q:GetUInt32(3),
                                missions = q:GetUInt32(4), cause = q:GetString(5), died = q:GetString(6) }
        until not q:NextRow()
    end
    return list
end

-- Every bag position as { bag, slot }: the backpack (bag 255, slots 23-38) and bags 19-22.
function Roster.BagSlots()
    local list = {}
    for slot = 23, 38 do list[#list + 1] = { 255, slot } end
    for bag = 19, 22 do
        for slot = 0, 35 do list[#list + 1] = { bag, slot } end
    end
    return list
end

-- A hero logs in (as a bot) -------------------------------------------------------------------

local function SetUp(bot, h)
    local factory = CreatePlayerbotFactory(bot, h.start_level, h.gear_quality or Config.heroes.gear_quality, 0)
    factory:Randomize(false)                         -- level, skills, spells, gear, bags...
    factory:InitTalentsBySpecNo(bot, h.spec_no, true) -- the spec it was recruited with
    -- The factory can leave spare weapons and armour in the bags; a hero only keeps what they wear
    -- (spares would be free gear outside the armory).
    for _, pos in ipairs(Roster.BagSlots()) do
        local item = bot:GetItemByPos(pos[1], pos[2])
        if item then
            local q = WorldDBQuery("SELECT `class` FROM `item_template` WHERE `entry` = " .. item:GetEntry())
            local class = q and q:GetUInt32(0)
            if class == 2 or class == 4 then bot:RemoveItem(item, item:GetCount()) end
        end
    end
    bot:SaveToDB()
    h.set_up = true
    Save(h, { "set_up" })
    Log.Event(owner[h.guid] or 0, "hero_set_up", string.format("%s level %d spec %d", h.name, h.start_level, h.spec_no))
end

local function OnHeroLogin(bot)
    local commanderGuid = owner[bot:GetGUIDLow()]
    if not commanderGuid then return end
    local h = heroes[commanderGuid][bot:GetGUIDLow()]
    if not h.set_up then SetUp(bot, h) end
    -- Wait a moment for the login to finish, then stand next to the commander.
    bot:RegisterEvent(function(_, _, _, b)
        Roster.ShowWound(b, h.wounded)
        local commander = GetPlayerByGUID(GetPlayerGUID(commanderGuid))
        if commander then
            b:Teleport(commander:GetMapId(), commander:GetX() + 1.5, commander:GetY() + 1.5, commander:GetZ(), commander:GetO())
            Changed(commander)
        end
    end, 1500, 1)
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, Log.Safe("roster login", function(event, player)
    if player:IsBot() then OnHeroLogin(player) end
end))

-- A hero levels up: playerbots doesn't do this for bots a player controls, so teach the new
-- class spells and spend the new talent points along the recruited spec.
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, Log.Safe("hero level", function(event, bot)
    local commanderGuid = owner[bot:GetGUIDLow()]
    if not commanderGuid or not bot:IsBot() then return end
    local h = heroes[commanderGuid][bot:GetGUIDLow()]
    if not h.set_up then return end -- the first set-up levels the hero itself
    local factory = CreatePlayerbotFactory(bot, bot:GetLevel(), Config.heroes.gear_quality, 0)
    factory:InitSkills()
    factory:InitClassSpells()
    factory:InitAvailableSpells()
    factory:InitTalentsBySpecNo(bot, h.spec_no, true)
    bot:SaveToDB()
    h.level = bot:GetLevel()
end))

-- A commander logs in: load the roster, link the accounts, bring back the party.
Company.OnReady(function(player, c)
    LinkAccount(player:GetAccountId())
    Load(c.guid)
    local guid = player:GetGUID()
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p then return end
        Roster.ShowWound(p, c.wounded == 1)
        for _, h in pairs(heroes[c.guid]) do
            if h.in_party and h.status == "alive" and not GetPlayerByGUID(GetPlayerGUID(h.guid)) then LogIn(p, h) end
        end
    end, 3000, 1)
end)

-- After ".reload ale": load the rosters of commanders already online.
for _, player in ipairs(GetPlayersInWorld()) do
    local c = Company.Get(player)
    if c then Load(c.guid) end
end

return Roster
