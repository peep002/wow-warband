-- wb_dev_probe.lua
-- Read-outs and shortcuts for the headless test bot (tools/wb_testbot.py), which can't see the
-- game screen. Every line starts with "[probe]" so the bot can find it. GMs only. The dev
-- folder is never shipped in the package.
--
-- Commands (chat):
--   .wbdev state        commander?, level, map, position, distance to the hamlet, company state,
--                       running mission, bots in the group
--   .wbdev roster       every hero: name, class, level, in party?, online?, missions, status,
--                       unspent talent points (-1 when offline)
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

-- One line per hero: name:class:level:in_party(0/1):online(0/1):missions:status
function probes.roster(player)
    local Roster = require("wb_roster")
    local list, parts, party = Roster.List(player), {}, 0
    for _, h in ipairs(list) do
        local online = GetPlayerByGUID(GetPlayerGUID(h.guid))
        if h.in_party then party = party + 1 end
        parts[#parts + 1] = string.format("%s:%d:%d:%d:%d:%d:%s:%d", h.name, h.class, online and online:GetLevel() or h.level,
            h.in_party and 1 or 0, online and 1 or 0, h.missions, h.status, online and online:GetFreeTalentPoints() or -1)
    end
    Out(player, string.format("heroes=%d alive=%d party=%d list=%s", #list, Roster.Alive(player), party,
        #parts > 0 and table.concat(parts, ",") or "none"))
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
    player:Kill(best, false)
    Out(player, "killed=1")
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

function probes.log(player)
    local q = CharDBQuery("SELECT `event`, `detail` FROM `warband_log` WHERE `company` = " .. player:GetGUIDLow()
        .. " ORDER BY `id` DESC LIMIT 6")
    if not q then return Out(player, "log=none") end
    local lines = {}
    repeat lines[#lines + 1] = q:GetString(0) .. ":" .. q:GetString(1):gsub("%s", "_") until not q:NextRow()
    Out(player, "log=" .. table.concat(lines, ","))
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
