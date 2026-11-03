-- wb_dev_probe.lua
-- Read-outs and shortcuts for the headless test bot (tools/wb_testbot.py), which can't see the
-- game screen. Every line starts with "[probe]" so the bot can find it. GMs only. The dev
-- folder is never shipped in the package.
--
-- Commands (chat):
--   .wbdev state        commander?, level, map, position, distance to the hamlet, company state,
--                       running mission, bots in the group
--   .wbdev roster       every hero: name, class, level, in party?, online?, missions, status,
--                       unspent talent points (-1 when offline), wounded?, alive?; commander wounded?
--   .wbdev down NAME|me [hold]   kill them on the spot (hold: no fight-is-over rescue for them)
--   .wbdev bleed NAME|me run out their bleed-out clock now
--   .wbdev clear        kill every hostile monster within 100 yards
--   .wbdev armory       the armory's items (id, entry, quality, count, suffix, upgrade for), gold,
--                       renown, materials
--   .wbdev lootsim ENTRY [NAME]  an item goes through the real loot capture (you or a hero)
--   .wbdev giveitem NAME ENTRY   put an item in a hero's bags
--   .wbdev worn NAME|me SLOT     what's worn in an equipment slot (entry, random property/suffix)
--   .wbdev downed       who's downed in your party, with seconds left
--   .wbdev tavern       every recruit: name, role, level, cost, founding?; free founding hires left
--   .wbdev board [refresh|KEY,KEY]  the board's contracts (or deal new ones, or set them)
--   .wbdev progress N   set the act's main-mission count
--   .wbdev xp           your XP, XP to next level, level cap, last kill-XP cut (normal -> given)
--   .wbdev killnear ENTRY  kill the nearest living creature with that entry, you get the XP
--   .wbdev grant N      mission XP by hand: N levels' worth
--   .wbdev hasspell ID  whether you know that spell
--   .wbdev npc ENTRY    the nearest creature with that entry: low GUID and distance
--   .wbdev gonpc ENTRY  jump next to the nearest creature with that entry (to talk to it)
--   .wbdev wander       jump 300 yards out of the hamlet (as if you walked off)
--   .wbdev killboss     kill the running mission's target boss, with you as the killer
--   .wbdev log          the last 6 warband_log lines of your company
--   .wbdev trait NAME pos|pos2|neg KEY   give a hero a trait;  .wbdev traits NAME   its trait state
--   .wbdev hp NAME|me PCT   set health;  .wbdev aggro NAME|me [RANGE]   the nearest idle monster attacks them
--   .wbdev attackers NAME|me   who hits them and whom those hit;  .wbdev near NAME|me RANGE  monsters fighting
--   .wbdev calm         kill the monsters that are fighting (idle ones stay, unlike clear)
--   .wbdev traitset KEY FIELD VALUE   change a trait's number, e.g. "clumsy chance 1" (until .reload ale)
--   .wbdev stress NAME [N|+N|-N]   read/set/change stress;  .wbdev resolve NAME KEY|-   set an affliction/virtue
--   .wbdev stressset FIELD VALUE   change a Config.stress number;  .wbdev heavyhit NAME   a simulated heavy hit

local Config   = require("wb_config")
local Company  = require("wb_company")
local Missions = require("wb_missions")

local PLAYER_EVENT_ON_COMMAND = 42

local function Out(player, text) player:SendBroadcastMessage("[probe] " .. text) end

local probes = {}

function probes.state(player)
    local c = Company.Get(player)
    local m = Missions.Active(player)
    local hub = Config.hub
    local dist = player:GetMapId() == hub.map and math.floor(player:GetDistance(hub.x, hub.y, hub.z)) or -1
    Out(player, string.format("commander=%d level=%d map=%d x=%.1f y=%.1f z=%.1f hubdist=%d alive=%d hp=%d combat=%d",
        c and 1 or 0, player:GetLevel(), player:GetMapId(), player:GetX(), player:GetY(), player:GetZ(), dist,
        player:IsAlive() and 1 or 0, player:GetHealthPct(), player:IsInCombat() and 1 or 0))
    local bots, botmaps = Missions.PartyBots(player), {}
    for _, b in ipairs(bots) do botmaps[#botmaps + 1] = tostring(b:GetMapId()) end
    Out(player, string.format("state=%d act=%d gold=%d mission=%s bots=%d botmaps=%s hearthstone=%d",
        c and c.state or -1, c and c.act or 0, c and c.gold or 0, m and m.key or "none",
        #bots, #botmaps > 0 and table.concat(botmaps, ",") or "none",
        player:GetItemCount(Config.lockdown.hearthstone)))
end

-- One entry per hero: name:class:level:in_party(0/1):online(0/1):missions:status:talents:wounded(0/1):alive(0/1)
function probes.roster(player)
    local Roster = require("wb_roster")
    local list, parts, party = Roster.List(player), {}, 0
    for _, h in ipairs(list) do
        local online = GetPlayerByGUID(GetPlayerGUID(h.guid))
        if h.in_party then party = party + 1 end
        parts[#parts + 1] = string.format("%s:%d:%d:%d:%d:%d:%s:%d:%d:%d", h.name, h.class,
            online and online:GetLevel() or h.level, h.in_party and 1 or 0, online and 1 or 0, h.missions, h.status,
            online and online:GetFreeTalentPoints() or -1, h.wounded and 1 or 0, (online and online:IsAlive()) and 1 or 0)
    end
    local c = Company.Get(player)
    Out(player, string.format("heroes=%d alive=%d party=%d cwounded=%d list=%s", #list, Roster.Alive(player), party,
        c.wounded, #parts > 0 and table.concat(parts, ",") or "none"))
end

-- Death's door. "who" = a hero's name, or "me".
local function Who(player, who)
    if who:lower() == "me" then return player end
    for _, h in ipairs(require("wb_roster").List(player)) do
        if h.name:lower() == who:lower() then return GetPlayerByGUID(GetPlayerGUID(h.guid)) end
    end
end

-- ".wbdev down NAME|me [hold]": kill them on the spot; "hold" stops the fight-is-over rescue for them.
function probes.down(player, arg)
    local who, hold = arg:match("^(%S+)%s*(%S*)$")
    local unit = who and Who(player, who)
    if not unit or unit:IsDead() then return Out(player, "down=0") end
    unit:SetHealth(1)
    player:Kill(unit, false)
    if hold == "hold" then
        -- The death check runs every second: wait for it to see the death, then hold.
        local guid = unit:GetGUIDLow()
        CreateLuaEvent(function() require("wb_death").Hold(guid) end, 1500, 1)
    end
    Out(player, "down=1")
end

-- ".wbdev revive NAME|me": ResurrectPlayer at 30%, reporting alive/health right after and 2 s later.
function probes.revive(player, arg)
    local unit = Who(player, arg)
    if not unit then return Out(player, "revive=none") end
    unit:ResurrectPlayer(0.3)
    Out(player, string.format("revive=1 alive=%d hp=%d", unit:IsAlive() and 1 or 0, unit:GetHealth()))
    local guid = unit:GetGUID()
    CreateLuaEvent(function()
        local u = GetPlayerByGUID(guid)
        if u then Out(player, string.format("later alive=%d hp=%d", u:IsAlive() and 1 or 0, u:GetHealth())) end
    end, 2000, 1)
end

-- The armory: id:entry:quality:count:prop:suffix:upgrade-for (names joined by +)
function probes.armory(player)
    local Armory = require("wb_armory")
    local up, parts = Armory.Upgrades(player), {}
    local list = Armory.List(player)
    for _, it in ipairs(list) do
        local who = {}
        for _, u in ipairs(up[it.id] or {}) do who[#who + 1] = u.name end
        parts[#parts + 1] = string.format("%d:%d:%d:%d:%d:%d:%s", it.id, it.entry, it.quality, it.count, it.prop, it.suffix,
            #who > 0 and table.concat(who, "+") or "-")
    end
    local c = Company.Get(player)
    Out(player, string.format("items=%d gold=%d renown=%d materials=%d list=%s", #list, c.gold, c.renown, c.materials,
        #parts > 0 and table.concat(parts, ",") or "none"))
end

-- ".wbdev lootsim ENTRY [NAME]": the item appears in your (or a hero's) bags and goes through the
-- same capture as a real loot. Reports whether it's still in the bags afterwards.
function probes.lootsim(player, arg)
    local entry, who = arg:match("^(%d+)%s*(%S*)$")
    local unit = (who and who ~= "") and Who(player, who) or player
    if not unit then return Out(player, "loot=nounit") end
    local item = unit:AddItem(tonumber(entry), 1)
    if not item then return Out(player, "loot=noitem") end
    require("wb_armory").OnLoot(nil, unit, item, 1)
    Out(player, string.format("loot=1 inbags=%d", unit:GetItemCount(tonumber(entry))))
end

-- ".wbdev giveitem NAME ENTRY": put an item in a hero's bags (it stays there).
function probes.giveitem(player, arg)
    local who, entry = arg:match("^(%S+)%s+(%d+)$")
    local unit = who and Who(player, who)
    local item = unit and unit:AddItem(tonumber(entry), 1)
    Out(player, "given=" .. (item and 1 or 0))
end

-- ".wbdev worn NAME|me SLOT": what's worn there: entry, random property, random suffix.
function probes.worn(player, arg)
    local who, slot = arg:match("^(%S+)%s+(%d+)$")
    local unit = who and Who(player, who)
    local item = unit and unit:GetEquippedItemBySlot(tonumber(slot))
    Out(player, item and string.format("worn=%d prop=%d suffix=%d", item:GetEntry(), item:GetRandomProperty(),
        item:GetRandomSuffix()) or "worn=0")
end

-- Kill every hostile monster within 100 yards (a quiet spot for death tests).
function probes.clear(player)
    local n = 0
    for _, cr in ipairs(player:GetCreaturesInRange(100, 0, 1, 1)) do
        player:Kill(cr, false)
        n = n + 1
    end
    Out(player, "cleared=" .. n)
end

-- ".wbdev bleed NAME|me": their bleed-out clock runs out now.
function probes.bleed(player, arg)
    local unit = Who(player, arg)
    if not unit then return Out(player, "bleed=0") end
    require("wb_death").Expire(unit:GetGUIDLow())
    Out(player, "bleed=1")
end

-- Who's downed in your party, with seconds left.
function probes.downed(player)
    local Death, parts = require("wb_death"), {}
    local list = { player }
    for _, b in ipairs(require("wb_roster").PartyHeroes(player)) do list[#list + 1] = b end
    for _, u in ipairs(list) do
        local st, left = Death.State(u)
        if st == "downed" then parts[#parts + 1] = u:GetName() .. ":" .. left end
    end
    Out(player, "downed=" .. (#parts > 0 and table.concat(parts, ",") or "none"))
end

-- name:role:level:cost:founding(0/1) for each recruit
function probes.tavern(player)
    local Tavern = require("wb_tavern")
    local list, parts = Tavern.Offers(player), {}
    for _, r in ipairs(list) do
        parts[#parts + 1] = string.format("%s:%s:%d:%d:%d", r.name, r.role, r.level, r.cost, r.founding and 1 or 0)
    end
    Out(player, string.format("recruits=%d free=%d list=%s", #list, Tavern.FoundingLeft(player),
        #parts > 0 and table.concat(parts, ",") or "none"))
end

-- ".wbdev board" shows it; ".wbdev board refresh" deals a new one; ".wbdev board KEY,KEY" sets it.
function probes.board(player, arg)
    local Board = require("wb_board")
    if arg == "refresh" then Board.Refresh(player)
    elseif arg ~= "" then
        local keys = {}
        for key in arg:gmatch("[^,%s]+") do keys[#keys + 1] = key end
        Board.Set(player, keys)
    end
    local c = Company.Get(player)
    Out(player, string.format("board=%s progress=%d act=%d", table.concat(Board.Get(player), ","), c.progress, c.act))
end

function probes.progress(player, arg)
    local c = Company.Get(player)
    c.progress = tonumber(arg) or c.progress
    Company.Save(player)
    Out(player, "progress=" .. c.progress)
end

-- Your XP, the XP to the next level, the level cap, and the last kill the 10% cut changed.
function probes.xp(player)
    local XP = require("wb_xp")
    local last = XP.lastCut[player:GetGUIDLow()] or { -1, -1 }
    Out(player, string.format("level=%d xp=%d next=%d cap=%s cutfrom=%d cutto=%d", player:GetLevel(), player:GetXP(),
        player:GetUInt32Value(635), tostring(XP.Cap(player)), last[1], last[2]))
end

-- Kill the nearest living creature with that entry, with you as the killer (you get the XP).
function probes.killnear(player, arg)
    local list = player:GetCreaturesInRange(80, tonumber(arg) or 0, 0, 1)
    local best, bestDist
    for _, cr in ipairs(list) do
        local d = player:GetDistance(cr)
        if not bestDist or d < bestDist then best, bestDist = cr, d end
    end
    if not best then return Out(player, "killed=0") end
    -- Real damage, not Kill(): the server only rewards XP when players did enough of the damage.
    player:DealDamage(best, best:GetMaxHealth() * 2)
    Out(player, "killed=" .. (best:IsDead() and 1 or 0))
end

-- Mission XP by hand: ".wbdev grant 2" = two levels' worth.
function probes.grant(player, arg)
    local given = require("wb_xp").Grant(player, tonumber(arg) or 0)
    Out(player, string.format("granted=%d level=%d", given, player:GetLevel()))
end

function probes.hasspell(player, arg)
    local id = tonumber(arg) or 0
    Out(player, string.format("spell=%d known=%d", id, player:HasSpell(id) and 1 or 0))
end

function probes.npc(player, arg)
    local list = player:GetCreaturesInRange(200, tonumber(arg) or 0, 0, 0)
    local best, bestDist
    for _, cr in ipairs(list) do
        local d = player:GetDistance(cr)
        if not bestDist or d < bestDist then best, bestDist = cr, d end
    end
    Out(player, best and string.format("npc=%d low=%d dist=%.1f", best:GetEntry(), best:GetGUIDLow(), bestDist)
        or "npc=none")
end

-- Talking to an NPC only works within about 5 yards, and the bot can't walk.
function probes.gonpc(player, arg)
    local list = player:GetCreaturesInRange(200, tonumber(arg) or 0, 0, 0)
    local cr = list[1]
    if not cr then return Out(player, "gonpc=none") end
    player:Teleport(cr:GetMapId(), cr:GetX() + 1.5, cr:GetY(), cr:GetZ(), cr:GetO() + math.pi)
    Out(player, string.format("gonpc=%d low=%d", cr:GetEntry(), cr:GetGUIDLow()))
end

function probes.wander(player)
    local hub = Config.hub
    player:Teleport(hub.map, hub.x - 300, hub.y, hub.z + 5, hub.o)
    Out(player, "wander=1")
end

function probes.killboss(player)
    local m = Missions.Active(player)
    if not m then return Out(player, "killed=0 reason=nomission") end
    local list = player:GetCreaturesInRange(500, m.def.boss, 0, 1)
    if not list[1] then return Out(player, "killed=0 reason=notfound") end
    player:Kill(list[1], false)
    Out(player, "killed=1")
end

-- ".wbdev log [EVENT]": the last 6 log lines (or the last 6 of one event, e.g. "hero_died").
function probes.log(player, arg)
    local only = (arg or ""):match("^([%w_]+)$")
    local q = CharDBQuery("SELECT `event`, `detail` FROM `warband_log` WHERE `company` = " .. player:GetGUIDLow()
        .. (only and (" AND `event` = '" .. only .. "'") or "") .. " ORDER BY `id` DESC LIMIT 6")
    if not q then return Out(player, "log=none") end
    local lines = {}
    repeat lines[#lines + 1] = q:GetString(0) .. ":" .. q:GetString(1):gsub("%s", "_") until not q:NextRow()
    Out(player, "log=" .. table.concat(lines, ","))
end

-- Traits (phase 7) ---------------------------------------------------------------------------------

local function HeroOf(player, name)
    for _, h in ipairs(require("wb_roster").List(player)) do
        if h.name:lower() == (name or ""):lower() then return h end
    end
end

-- ".wbdev trait NAME pos|pos2|neg KEY": give a hero a trait (saved, like a rolled one). KEY "-" clears.
function probes.trait(player, arg)
    local name, slot, key = arg:match("^(%S+)%s+(%S+)%s+(%S+)$")
    local field = ({ pos = "trait_pos", pos2 = "trait_pos2", neg = "trait_neg" })[slot or ""]
    local h = HeroOf(player, name)
    if not h or not field then return Out(player, "trait=0") end
    h[field] = key == "-" and "" or key
    CharDBExecute(string.format("UPDATE `warband_heroes` SET `%s` = '%s' WHERE `guid` = %d", field, h[field], h.guid))
    Out(player, "trait=1")
end

-- ".wbdev traits NAME": aura102000:aura102001 (1 = on), what's used this fight, health %, alive
function probes.traits(player, arg)
    local h = HeroOf(player, arg)
    local unit = h and GetPlayerByGUID(GetPlayerGUID(h.guid))
    if not unit then return Out(player, "traits=none") end
    local auras = {}
    for _, key in ipairs({ "stalwart", "glass_jaw" }) do
        auras[#auras + 1] = key .. ":" .. (unit:HasAura(Config.trait_effects.auras[key]) and 1 or 0)
    end
    Out(player, string.format("traits=%s,%s,%s auras=%s used=%s hp=%d alive=%d combat=%d", h.trait_pos, h.trait_pos2,
        h.trait_neg, table.concat(auras, ","), require("wb_traits").State(h.guid), unit:GetHealthPct(),
        unit:IsAlive() and 1 or 0, unit:IsInCombat() and 1 or 0))
end

-- ".wbdev hp NAME|me PCT": set health to a share of the maximum
function probes.hp(player, arg)
    local who, pct = arg:match("^(%S+)%s+(%d+)$")
    local unit = who and Who(player, who)
    if not unit then return Out(player, "hp=0") end
    unit:SetHealth(math.max(1, math.floor(unit:GetMaxHealth() * tonumber(pct) / 100)))
    Out(player, "hp=" .. unit:GetHealthPct())
end

-- ".wbdev aggro NAME|me [RANGE]": the nearest idle monster attacks them, seen or not (it walks there)
function probes.aggro(player, arg)
    local who, range = arg:match("^(%S+)%s*(%d*)$")
    local unit = who and Who(player, who)
    if not unit then return Out(player, "aggro=none") end
    local best, bestDist
    for _, c in ipairs(unit:GetCreaturesInRange(tonumber(range) or 60, 0, 1, 1) or {}) do
        if not c:IsInCombat() and not c:IsCivilian() and not c:IsTrigger() and not c:IsDungeonBoss() then
            local d = unit:GetDistance(c)
            if not best or d < bestDist then best, bestDist = c, d end
        end
    end
    if not best then return Out(player, "aggro=none") end
    best:AttackStart(unit)
    Out(player, string.format("aggro=%d low=%d dist=%d", best:GetEntry(), best:GetGUIDLow(), bestDist))
end

-- ".wbdev calm": kill every monster within 100 yards that is fighting (the idle ones stay)
function probes.calm(player)
    local n = 0
    for _, c in ipairs(player:GetCreaturesInRange(100, 0, 1, 1) or {}) do
        if c:IsInCombat() then
            player:Kill(c, false)
            n = n + 1
        end
    end
    Out(player, "calmed=" .. n)
end

-- ".wbdev attackers NAME|me": who is attacking them, and whom each of those is hitting (name:victim)
function probes.attackers(player, arg)
    local unit = Who(player, arg)
    if not unit then return Out(player, "attackers=none") end
    local parts = {}
    for _, a in ipairs(unit:GetAttackers() or {}) do
        local v = a:GetVictim()
        parts[#parts + 1] = string.format("%d:%s", a:GetEntry(), v and v:GetName() or "-")
    end
    Out(player, "attackers=" .. (#parts > 0 and table.concat(parts, ",") or "none"))
end

-- ".wbdev near NAME|me RANGE": monsters fighting within range (entry:victim), to see a pull
function probes.near(player, arg)
    local who, range = arg:match("^(%S+)%s*(%d*)$")
    local unit = who and Who(player, who)
    if not unit then return Out(player, "near=none") end
    local fighting = 0
    for _, c in ipairs(unit:GetCreaturesInRange(tonumber(range) or 60, 0, 1, 1) or {}) do
        if c:IsInCombat() then fighting = fighting + 1 end
    end
    Out(player, "fighting=" .. fighting)
end

-- ".wbdev traitset KEY FIELD VALUE": change one of a trait's numbers until the next .reload ale (tests)
function probes.traitset(player, arg)
    local key, field, value = arg:match("^(%S+)%s+(%S+)%s+([%d%.]+)$")
    local e = key and Config.trait_effects[key]
    if not e or type(e) ~= "table" or e[field] == nil then return Out(player, "set=none") end
    e[field] = tonumber(value)
    Out(player, "set=" .. e[field])
end

-- Stress (phase 8) ----------------------------------------------------------------------------------

-- ".wbdev stress NAME [N|+N|-N]": read a hero's stress (and resolve); N sets it straight (no resolve
-- check), +N / -N go through the real Stress.Add (Brave, resolve checks, heart attacks...).
function probes.stress(player, arg)
    local name, how, n = arg:match("^(%S+)%s*([%+%-]?)(%d*)$")
    local h = HeroOf(player, name)
    if not h then return Out(player, "stress=none") end
    local Stress = require("wb_stress")
    if n ~= "" then
        if how == "" then
            h.stress = tonumber(n)
            require("wb_roster").Save(h, { "stress" })
        else
            Stress.Add(player, h, (how == "-" and -1 or 1) * tonumber(n), "probe")
        end
    end
    local r = Stress.Resolve(h)
    local unit = GetPlayerByGUID(GetPlayerGUID(h.guid))
    local A = Config.stress.auras
    Out(player, string.format("stress=%d resolve=%s kind=%s left=%d hopeless=%d focused=%d alive=%d", h.stress,
        h.resolve ~= "" and h.resolve or "none", r and r.kind or "none", h.resolve_left,
        (unit and unit:HasAura(A.hopeless)) and 1 or 0, (unit and unit:HasAura(A.focused)) and 1 or 0,
        (unit and unit:IsAlive()) and 1 or 0))
end

-- ".wbdev resolve NAME KEY|-": give a hero an affliction or virtue (or clear it)
function probes.resolve(player, arg)
    local name, key = arg:match("^(%S+)%s+(%S+)$")
    local h = HeroOf(player, name)
    if not h or (key ~= "-" and not Config.resolves[key]) then return Out(player, "resolve=0") end
    require("wb_stress").SetResolve(player, h, key == "-" and "" or key)
    Out(player, "resolve=1")
end

-- ".wbdev stressset FIELD VALUE": change a Config.stress number until the next .reload ale (tests)
function probes.stressset(player, arg)
    local field, value = arg:match("^(%S+)%s+([%d%.]+)$")
    if not field or type(Config.stress[field]) ~= "number" then return Out(player, "set=none") end
    Config.stress[field] = tonumber(value)
    Out(player, "set=" .. Config.stress[field])
end

-- ".wbdev heavyhit NAME": a hit for half their health goes through the heavy-hit check (not dealt)
function probes.heavyhit(player, arg)
    local unit = Who(player, arg)
    if not unit then return Out(player, "heavyhit=none") end
    local counted = require("wb_stress").OnHeavyHit(unit, math.floor(unit:GetMaxHealth() / 2))
    Out(player, "heavyhit=" .. (counted and 1 or 0))
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, function(event, player, command)
    if not player then return end
    local what, arg = command:match("^wbdev%s+(%S+)%s*(.*)$")
    if not what then return end
    if player:GetGMRank() < 3 then return end
    local fn = probes[what:lower()]
    if fn then fn(player, arg) else Out(player, "unknown=" .. what) end
    return false
end)
