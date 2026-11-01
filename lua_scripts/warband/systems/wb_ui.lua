-- wb_ui.lua
-- Server half of the Warband window (the window itself is wb_ui_client.lua, which AIO sends to
-- each player's game client). This file decides what the window shows and checks every click
-- again, because a client can send anything.
--   * Opens from: Sergeant Marlow (9100000), the minimap button, and the chat command .warband
--   * Sergeant Marlow also has a plain menu with the same choices, as a backup for anyone
--     without the AIO addon.
--
--   UI.Show(player)    open (or refresh) the window

local AIO      = AIO or require("AIO")
local Config   = require("wb_config")
local Company  = require("wb_company")
local Missions = require("wb_missions")
local Log      = require("wb_log")

local UI = {}

local PLAYER_EVENT_ON_COMMAND = 42
local GOSSIP_EVENT_ON_HELLO, GOSSIP_EVENT_ON_SELECT = 1, 2
local MARLOW = 9100000
local MARLOW_TEXT = 9100000

-- Players whose game client asked AIO for our window code, i.e. who have the AIO addon.
-- Everyone else gets Sergeant Marlow's plain menu instead of the window.
local hasAddon = {}
AIO.AddOnInit(function(msg, player)
    if player then hasAddon[player:GetGUIDLow()] = true end
    return msg
end)

local function MissionData(key)
    local d = Config.missions[key]
    return { key = key, name = d.name, dungeon = d.dungeon, kind = d.kind, length = d.length, level = d.level,
             icon = d.icon, text = d.text, objective = d.objective, rewards = d.rewards }
end

local function Build(player)
    local c = Company.Get(player)
    local data = { commander = player:GetName(), act = c.act, gold = c.gold, renown = c.renown,
                   materials = c.materials, offers = {}, party = {} }
    for _, key in ipairs(Missions.Offers(player)) do data.offers[#data.offers + 1] = MissionData(key) end
    local m = Missions.Active(player)
    if m then data.active = MissionData(m.key) end
    for _, bot in ipairs(Missions.PartyBots(player)) do
        data.party[#data.party + 1] = { name = bot:GetName(), class = bot:GetClass(), level = bot:GetLevel() }
    end
    return data
end

function UI.Show(player)
    if not Company.IsCommander(player) then
        player:SendBroadcastMessage("|cffff2020[Warband]|r This character isn't a commander. Make a new character to start a company.")
        return
    end
    AIO.Handle(player, "Warband", "Show", Build(player))
end

-- A refresh that doesn't pop the window open if it's closed.
local function Update(player)
    if Company.IsCommander(player) then AIO.Handle(player, "Warband", "Update", Build(player)) end
end
Missions.OnChange(Update)

local function Reply(player, ok, message)
    if message then
        player:SendBroadcastMessage((ok and "|cffffd100[Warband]|r " or "|cffff2020[Warband]|r ") .. message)
    end
end

-- Clicks from the window ---------------------------------------------------------------------

AIO.AddHandlers("Warband", {
    Open = function(player) UI.Show(player) end,
    Embark = function(player, key)
        if type(key) ~= "string" then return end
        local ok, message = Missions.Embark(player, key)
        Reply(player, ok, message)
        Update(player)
    end,
    Abandon = function(player)
        local ok, message = Missions.Abandon(player)
        Reply(player, ok, message)
        Update(player)
    end,
})

-- .warband -------------------------------------------------------------------------------------

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, Log.Safe("ui command", function(event, player, command)
    if not player then return end
    local cmd = command:lower()
    if cmd == "warband" or cmd == "wb" then
        UI.Show(player)
        return false -- handled: don't answer "no such command"
    end
    -- Backup for players without the addon: Marlow stands in the hamlet, not in the dungeon.
    if cmd == "warband abandon" or cmd == "wb abandon" then
        local ok, message = Missions.Abandon(player)
        Reply(player, ok, message)
        return false
    end
end))

-- Sergeant Marlow: opens the window, and keeps a plain menu as a backup ------------------------

local OPT_WINDOW, OPT_CONTRACT, OPT_EMBARK, OPT_ABANDON, OPT_BACK = 1, 100, 200, 300, 400

local function MarlowMenu(player, creature)
    player:GossipClearMenu()
    local c = Company.Get(player)
    if not c then
        player:SendBroadcastMessage("|cffff2020[Warband]|r Only commanders can take contracts. Make a new character to start a company.")
        player:GossipComplete()
        return
    end
    player:GossipMenuAddItem(0, "Show the mission board.", 0, OPT_WINDOW)
    if Missions.Active(player) then
        player:GossipMenuAddItem(0, "Abandon the current mission.", 0, OPT_ABANDON, false,
            "Abandon the mission and fall back to the hamlet?")
    else
        for i, key in ipairs(Missions.Offers(player)) do
            local d = Config.missions[key]
            player:GossipMenuAddItem(0, string.format("Contract: %s (%s, %s)", d.name, d.dungeon, d.length), 0, OPT_CONTRACT + i)
        end
    end
    player:GossipSendMenu(MARLOW_TEXT, creature)
end

RegisterCreatureGossipEvent(MARLOW, GOSSIP_EVENT_ON_HELLO, Log.Safe("marlow hello", function(event, player, creature)
    if Company.IsCommander(player) and hasAddon[player:GetGUIDLow()] then
        player:GossipComplete()
        UI.Show(player)
        return
    end
    MarlowMenu(player, creature)
end))

RegisterCreatureGossipEvent(MARLOW, GOSSIP_EVENT_ON_SELECT, Log.Safe("marlow select", function(event, player, creature, sender, intid)
    local offers = Missions.Offers(player)
    if intid == OPT_WINDOW then
        player:GossipComplete()
        UI.Show(player)
    elseif intid > OPT_CONTRACT and intid < OPT_EMBARK then
        local d = Config.missions[offers[intid - OPT_CONTRACT]]
        if not d then return MarlowMenu(player, creature) end
        player:SendBroadcastMessage(string.format("|cffffd100%s|r - %s, %s %s mission, level %s. Objective: %s. %s",
            d.name, d.dungeon, d.length, d.kind, d.level, d.objective, d.text))
        player:GossipClearMenu()
        player:GossipMenuAddItem(0, "Embark now.", 0, OPT_EMBARK + (intid - OPT_CONTRACT))
        player:GossipMenuAddItem(0, "Back.", 0, OPT_BACK)
        player:GossipSendMenu(MARLOW_TEXT, creature)
    elseif intid > OPT_EMBARK and intid < OPT_ABANDON then
        player:GossipComplete()
        local ok, message = Missions.Embark(player, offers[intid - OPT_EMBARK])
        Reply(player, ok, message)
    elseif intid == OPT_ABANDON then
        player:GossipComplete()
        local ok, message = Missions.Abandon(player)
        Reply(player, ok, message)
    else
        MarlowMenu(player, creature)
    end
end))

return UI
