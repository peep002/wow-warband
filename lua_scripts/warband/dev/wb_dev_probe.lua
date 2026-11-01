-- wb_dev_probe.lua
-- Read-outs and shortcuts for the headless test bot (tools/wb_testbot.py), which can't see the
-- game screen. Every line starts with "[probe]" so the bot can find it. GMs only. The dev
-- folder is never shipped in the package.
--
-- Commands (chat):
--   .wbdev state        commander?, level, map, position, distance to the hamlet, company state,
--                       running mission, bots in the group
--   .wbdev hasspell ID  whether you know that spell
--   .wbdev npc ENTRY    the nearest creature with that entry: low GUID and distance
--   .wbdev gonpc ENTRY  jump next to the nearest creature with that entry (to talk to it)
--   .wbdev wander       jump 300 yards out of the hamlet (as if you walked off)
--   .wbdev killboss     kill the running mission's target boss, with you as the killer
--   .wbdev log          the last 3 warband_log lines of your company

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
        .. " ORDER BY `id` DESC LIMIT 3")
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
