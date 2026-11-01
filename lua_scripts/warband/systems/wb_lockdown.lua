-- wb_lockdown.lua
-- Keeps the campaign the only way a commander touches the world:
--   * Between missions, a commander who leaves the hamlet is sent back to it.
--   * On a mission, a commander who leaves the mission's dungeon is sent back to its entrance.
--   * No auction house, mail, guild bank, trading, flight paths, hearthstone or selling to
--     vendors. (The game has no hooks for most of these, so the client's requests are dropped.)
-- GMs with GM mode on (.gm on) and dead commanders are left alone, so testing and corpse runs
-- still work. Bots follow their commander, who brings them along on every teleport.

local Config   = require("wb_config")
local Company  = require("wb_company")
local Missions = require("wb_missions")

local PACKET_EVENT_ON_PACKET_RECEIVE = 5
local PLAYER_EVENT_ON_CAN_SEND_MAIL  = 49
local PLAYER_EVENT_ON_SPELL_CAST     = 5
local HEARTHSTONE_SPELL = 8690

local BLOCKED_PACKETS = {
    [0x23A] = "mail",              -- CMSG_GET_MAIL_LIST (opening the mailbox)
    [0x238] = "mail",              -- CMSG_SEND_MAIL
    [0x245] = "mail",              -- CMSG_MAIL_TAKE_MONEY
    [0x246] = "mail",              -- CMSG_MAIL_TAKE_ITEM
    [0x255] = "the auction house", -- MSG_AUCTION_HELLO
    [0x256] = "the auction house", -- CMSG_AUCTION_SELL_ITEM
    [0x258] = "the auction house", -- CMSG_AUCTION_LIST_ITEMS
    [0x25A] = "the auction house", -- CMSG_AUCTION_PLACE_BID
    [0x3E6] = "the guild bank",    -- CMSG_GUILD_BANKER_ACTIVATE
    [0x3E7] = "the guild bank",    -- CMSG_GUILD_BANK_QUERY_TAB
    [0x116] = "trading",           -- CMSG_INITIATE_TRADE
    [0x1AD] = "flight paths",      -- CMSG_ACTIVATETAXI
    [0x312] = "flight paths",      -- CMSG_ACTIVATETAXIEXPRESS
    [0x1A0] = "vendors (only the hamlet's own vendor will buy, once it opens)", -- CMSG_SELL_ITEM
}

local function Refuse(player, what)
    player:SendNotification("Commanders can't use " .. what .. ".")
end

for opcode, what in pairs(BLOCKED_PACKETS) do
    RegisterPacketEvent(opcode, PACKET_EVENT_ON_PACKET_RECEIVE, function(event, packet, player)
        if Company.IsCommander(player) and not player:IsGM() then
            Refuse(player, what)
            return false -- drop the request
        end
        return true
    end)
end

RegisterPlayerEvent(PLAYER_EVENT_ON_CAN_SEND_MAIL, function(event, player)
    if Company.IsCommander(player) and not player:IsGM() then
        Refuse(player, "mail")
        return false
    end
    return true
end)

RegisterPlayerEvent(PLAYER_EVENT_ON_SPELL_CAST, function(event, player, spell)
    if spell:GetEntry() == HEARTHSTONE_SPELL and Company.IsCommander(player) and not player:IsGM() then
        spell:Cancel()
        Refuse(player, "a hearthstone")
    end
end)

-- The leash ----------------------------------------------------------------------------------

local function Leash(player)
    if player:IsGM() or player:IsDead() or not player:IsInWorld() then return end
    local last = Missions.lastTeleport[player:GetGUIDLow()]
    if last and os.time() - last < Config.lockdown.teleport_grace then return end
    local m = Missions.Active(player)
    if m then
        if player:GetMapId() ~= m.def.map then
            local e = m.def.entrance
            player:Teleport(m.def.map, e.x, e.y, e.z, e.o)
            player:SendNotification("You're on a mission. Back to the entrance.")
        end
        return
    end
    local hub = Config.hub
    if player:GetMapId() ~= hub.map or player:GetDistance(hub.x, hub.y, hub.z) > hub.radius then
        Missions.SendHome(player)
        player:SendNotification("Between missions, the company stays in " .. hub.name .. ".")
    end
end

CreateLuaEvent(function()
    for _, player in ipairs(GetPlayersInWorld()) do
        if Company.IsCommander(player) then Leash(player) end
    end
end, Config.lockdown.check_seconds * 1000, 0)
