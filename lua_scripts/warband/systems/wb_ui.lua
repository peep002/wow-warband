-- wb_ui.lua
-- Server half of the Warband window (the window itself is wb_ui_client.lua, which AIO sends to
-- each player's game client). This file decides what the window shows and checks every click
-- again, because a client can send anything.
--   * Tabs: Missions, Roster, Tavern, Memorial (Armory and Hamlet come later).
--   * Opens from: Sergeant Marlow (missions), Maude Ashby (tavern), the minimap button, and
--     chat commands (.warband, .warband roster, .warband tavern).
--   * Marlow and Maude also have plain menus with the same choices, and the chat commands work
--     without the window, as a backup for anyone without the AIO addon.
--
--   UI.Show(player, tab)    open (or refresh) the window on a tab ("missions", "roster", "tavern")

local AIO      = AIO or require("AIO")
local Config   = require("wb_config")
local Company  = require("wb_company")
local Missions = require("wb_missions")
local Roster   = require("wb_roster")
local Tavern   = require("wb_tavern")
local Log      = require("wb_log")

local UI = {}

local PLAYER_EVENT_ON_COMMAND = 42
local GOSSIP_EVENT_ON_HELLO, GOSSIP_EVENT_ON_SELECT = 1, 2
local MARLOW, MARLOW_TEXT = 9100000, 9100000
local MAUDE, MAUDE_TEXT = 9100001, 9100001

-- Players whose game client asked AIO for our window code, i.e. who have the AIO addon.
-- Everyone else gets the NPCs' plain menus instead of the window.
local hasAddon = {}
AIO.AddOnInit(function(msg, player)
    if player then hasAddon[player:GetGUIDLow()] = true end
    return msg
end)

-- Building the window's data -----------------------------------------------------------------

local function SpecOf(class, specNo)
    for _, s in ipairs(Config.specs[class] or {}) do
        if s.no == specNo then return s end
    end
    return { name = "?", role = "dps" }
end

local function Trait(kind, key)
    local t = Config.traits[kind][key]
    return t and { name = t.name, text = t.text } or nil
end

local function Person(p) -- what a hero and a recruit have in common
    return { guid = p.guid, name = p.name, class = p.class, level = p.level,
             race = Config.race_names[p.race] or "?", className = Config.class_names[p.class] or "?",
             spec = SpecOf(p.class, p.spec_no).name, role = p.role, backstory = p.backstory,
             good = Trait("positive", p.trait_pos), bad = Trait("negative", p.trait_neg) }
end

local function MissionData(key)
    local d = Config.missions[key]
    return { key = key, name = d.name, dungeon = d.dungeon, kind = d.kind, length = d.length, level = d.level,
             icon = d.icon, text = d.text, objective = d.objective,
             rewards = string.format("Experience: about %.1f levels for you and every hero who goes "
                 .. "(a quarter of that if you abandon).%s\nGear, gold and renown come in later phases.",
                 d.xp, d.kind == "main" and " Counts towards the act's gate." or (d.kind == "gate" and " Beat it to open the next act." or "")) }
end

local function Build(player)
    local c = Company.Get(player)
    local act = Config.acts[c.act] or Config.acts[#Config.acts]
    local data = { commander = player:GetName(), act = c.act, actName = act.name, progress = c.progress,
                   mainsBeforeGate = act.mains_before_gate, levelCap = act.max_level, gold = c.gold, renown = c.renown,
                   materials = c.materials, onMission = c.state ~= 0, offers = {}, party = {}, roster = {}, recruits = {},
                   slots = Config.heroes.roster_slots, alive = Roster.Alive(player), maxParty = Config.heroes.max_party,
                   minParty = Config.heroes.min_party, foundingLeft = Tavern.FoundingLeft(player),
                   wounded = c.wounded == 1, treatCost = Roster.TreatCost(player:GetLevel()), memorial = {} }
    for _, key in ipairs(Missions.Offers(player)) do data.offers[#data.offers + 1] = MissionData(key) end
    local m = Missions.Active(player)
    if m then data.active = MissionData(m.key) end
    for _, bot in ipairs(Roster.PartyHeroes(player)) do
        data.party[#data.party + 1] = { name = bot:GetName(), class = bot:GetClass(), level = bot:GetLevel() }
    end
    for _, h in ipairs(Roster.List(player)) do
        local p = Person(h)
        p.status, p.inParty, p.missions, p.wounded, p.treatCost = h.status, h.in_party, h.missions, h.wounded,
            Roster.TreatCost(h.level)
        data.roster[#data.roster + 1] = p
    end
    for _, f in ipairs(Roster.Memorial(player)) do
        data.memorial[#data.memorial + 1] = { name = f.name, class = f.class, level = f.level, missions = f.missions,
            race = Config.race_names[f.race] or "?", className = Config.class_names[f.class] or "?", cause = f.cause, died = f.died }
    end
    for _, r in ipairs(Tavern.Offers(player)) do
        local p = Person(r)
        p.cost, p.founding = r.cost, r.founding
        data.recruits[#data.recruits + 1] = p
    end
    return data
end

function UI.Show(player, tab)
    if not Company.IsCommander(player) then
        player:SendBroadcastMessage("|cffff2020[Warband]|r This character isn't a commander. Make a new character to start a company.")
        return
    end
    AIO.Handle(player, "Warband", "Show", Build(player), tab)
end

-- A refresh that doesn't pop the window open if it's closed.
local function Update(player)
    if Company.IsCommander(player) then AIO.Handle(player, "Warband", "Update", Build(player)) end
end
Missions.OnChange(Update)
Roster.OnChange(Update)
Tavern.OnChange(Update)

local function Reply(player, ok, message)
    if message then
        player:SendBroadcastMessage((ok and "|cffffd100[Warband]|r " or "|cffff2020[Warband]|r ") .. message)
    end
end

-- Clicks from the window ---------------------------------------------------------------------

local function Act(fn)
    return function(player, guid)
        if type(guid) ~= "number" then return end
        local ok, message = fn(player, guid)
        Reply(player, ok, message)
        Update(player)
    end
end

AIO.AddHandlers("Warband", {
    Open = function(player, tab) UI.Show(player, type(tab) == "string" and tab or nil) end,
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
    Call = Act(Roster.Call),
    Treat = Act(Roster.Treat),
    Send = Act(Roster.Send),
    Hire = Act(Tavern.Hire),
})

-- Chat commands ----------------------------------------------------------------------------------

local function FindByName(list, name)
    name = name:lower()
    for _, p in ipairs(list) do
        if p.name:lower() == name then return p end
    end
end

local function PrintRoster(player)
    local list = Roster.List(player)
    player:SendBroadcastMessage(string.format("|cffffd100[Warband] Roster|r (%d of %d alive):", Roster.Alive(player), Config.heroes.roster_slots))
    if #list == 0 then player:SendBroadcastMessage("  Nobody yet. Hire at the tavern: .warband tavern") end
    for _, h in ipairs(list) do
        player:SendBroadcastMessage(string.format("  %s - level %d %s %s (%s), %s, %d missions", h.name, h.level,
            SpecOf(h.class, h.spec_no).name, Config.class_names[h.class] or "?", h.role,
            h.status ~= "alive" and h.status or (h.in_party and "in your party" or "in the barracks"), h.missions)
            .. (h.wounded and string.format(", |cffff3333wounded|r (treat: %d gold)", Roster.TreatCost(h.level)) or ""))
    end
    local c = Company.Get(player)
    if c.wounded == 1 then
        player:SendBroadcastMessage(string.format("  You are |cffff3333wounded|r (treat: %d gold, .warband treat me).",
            Roster.TreatCost(player:GetLevel())))
    end
end

local function PrintMemorial(player)
    local list = Roster.Memorial(player)
    player:SendBroadcastMessage("|cffffd100[Warband] Memorial wall|r" .. (#list == 0 and ": nobody yet." or ":"))
    for _, f in ipairs(list) do
        player:SendBroadcastMessage(string.format("  %s, level %d %s, %d missions. %s (%s)", f.name, f.level,
            Config.class_names[f.class] or "?", f.missions, f.cause, f.died))
    end
end

local function PrintTavern(player)
    local list = Tavern.Offers(player)
    local free = Tavern.FoundingLeft(player)
    player:SendBroadcastMessage("|cffffd100[Warband] Tavern|r" .. (free > 0 and string.format(" (founding: %d free hires left)", free) or "") .. ":")
    if #list == 0 then player:SendBroadcastMessage("  Nobody waiting. New recruits arrive after each mission.") end
    for _, r in ipairs(list) do
        player:SendBroadcastMessage(string.format("  %s - level %d %s %s (%s), %s", r.name, r.level, SpecOf(r.class, r.spec_no).name,
            Config.class_names[r.class] or "?", r.role, r.founding and "free" or (r.cost .. " gold")))
    end
end

local COMMANDS = {
    [""] = function(player) UI.Show(player) end,
    roster = function(player) PrintRoster(player); UI.Show(player, "roster") end,
    tavern = function(player) PrintTavern(player); UI.Show(player, "tavern") end,
    memorial = function(player) PrintMemorial(player); UI.Show(player, "memorial") end,
    treat = function(player, arg)
        if arg:lower() == "me" or arg == "" then return Reply(player, Roster.Treat(player, 0)) end
        local h = FindByName(Roster.List(player), arg)
        if not h then return Reply(player, false, "No hero called '" .. arg .. "' on your roster.") end
        Reply(player, Roster.Treat(player, h.guid))
    end,
    abandon = function(player) Reply(player, Missions.Abandon(player)) end,
    hire = function(player, arg)
        local r = FindByName(Tavern.Offers(player), arg)
        if not r then return Reply(player, false, "No recruit called '" .. arg .. "' in your tavern.") end
        Reply(player, Tavern.Hire(player, r.guid))
    end,
    call = function(player, arg)
        local h = FindByName(Roster.List(player), arg)
        if not h then return Reply(player, false, "No hero called '" .. arg .. "' on your roster.") end
        Reply(player, Roster.Call(player, h.guid))
    end,
    send = function(player, arg)
        local h = FindByName(Roster.List(player), arg)
        if not h then return Reply(player, false, "No hero called '" .. arg .. "' on your roster.") end
        Reply(player, Roster.Send(player, h.guid))
    end,
}

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, Log.Safe("ui command", function(event, player, command)
    if not player then return end
    local word, rest = command:match("^(%S+)%s*(.*)$")
    if not word or (word:lower() ~= "warband" and word:lower() ~= "wb") then return end
    local sub, arg = rest:match("^(%S*)%s*(.*)$")
    local fn = COMMANDS[(sub or ""):lower()]
    if not fn then
        Reply(player, false, "Commands: .warband, .warband roster, .warband tavern, .warband memorial, .warband hire NAME, "
            .. ".warband call NAME, .warband send NAME, .warband treat NAME|me, .warband abandon")
        return false
    end
    if not Company.IsCommander(player) then
        Reply(player, false, "This character isn't a commander. Make a new character to start a company.")
        return false
    end
    fn(player, arg or "")
    return false -- handled: don't answer "no such command"
end))

-- Sergeant Marlow: the mission board ------------------------------------------------------------

local OPT_WINDOW, OPT_CONTRACT, OPT_EMBARK, OPT_ABANDON, OPT_BACK = 1, 100, 200, 300, 400

local function NotCommander(player)
    player:SendBroadcastMessage("|cffff2020[Warband]|r Only commanders can do that. Make a new character to start a company.")
    player:GossipComplete()
end

local function MarlowMenu(player, creature)
    player:GossipClearMenu()
    if not Company.IsCommander(player) then return NotCommander(player) end
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
        UI.Show(player, "missions")
        return
    end
    MarlowMenu(player, creature)
end))

RegisterCreatureGossipEvent(MARLOW, GOSSIP_EVENT_ON_SELECT, Log.Safe("marlow select", function(event, player, creature, sender, intid)
    local offers = Missions.Offers(player)
    if intid == OPT_WINDOW then
        player:GossipComplete()
        UI.Show(player, "missions")
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
        Reply(player, Missions.Embark(player, offers[intid - OPT_EMBARK]))
    elseif intid == OPT_ABANDON then
        player:GossipComplete()
        Reply(player, Missions.Abandon(player))
    else
        MarlowMenu(player, creature)
    end
end))

-- Maude Ashby: the tavern and the roster ---------------------------------------------------------
-- Menu options carry a position in the list (hire 101, 102...), since character ids are too big.

local OPT_T_WINDOW, OPT_T_HIRE, OPT_T_CALL, OPT_T_SEND = 1, 100, 200, 300

local function MaudeMenu(player, creature)
    player:GossipClearMenu()
    if not Company.IsCommander(player) then return NotCommander(player) end
    player:GossipMenuAddItem(0, "Show the tavern.", 0, OPT_T_WINDOW)
    local free = Tavern.FoundingLeft(player)
    for i, r in ipairs(Tavern.Offers(player)) do
        local label = string.format("Hire %s: level %d %s %s (%s) - %s", r.name, r.level, SpecOf(r.class, r.spec_no).name,
            Config.class_names[r.class] or "?", r.role, (r.founding and free > 0) and "free" or (r.cost .. " gold"))
        player:GossipMenuAddItem(0, label, 0, OPT_T_HIRE + i, false, "Hire " .. r.name .. "?")
    end
    for i, h in ipairs(Roster.List(player)) do
        if h.status == "alive" then
            if h.in_party then
                player:GossipMenuAddItem(0, "Send " .. h.name .. " to the barracks.", 0, OPT_T_SEND + i)
            else
                player:GossipMenuAddItem(0, "Call " .. h.name .. " to your party.", 0, OPT_T_CALL + i)
            end
        end
    end
    player:GossipSendMenu(MAUDE_TEXT, creature)
end

RegisterCreatureGossipEvent(MAUDE, GOSSIP_EVENT_ON_HELLO, Log.Safe("maude hello", function(event, player, creature)
    if Company.IsCommander(player) and hasAddon[player:GetGUIDLow()] then
        player:GossipComplete()
        UI.Show(player, "tavern")
        return
    end
    MaudeMenu(player, creature)
end))

RegisterCreatureGossipEvent(MAUDE, GOSSIP_EVENT_ON_SELECT, Log.Safe("maude select", function(event, player, creature, sender, intid)
    if intid == OPT_T_WINDOW then
        player:GossipComplete()
        return UI.Show(player, "tavern")
    elseif intid > OPT_T_HIRE and intid < OPT_T_CALL then
        local r = Tavern.Offers(player)[intid - OPT_T_HIRE]
        if r then Reply(player, Tavern.Hire(player, r.guid)) end
    elseif intid > OPT_T_CALL and intid < OPT_T_SEND then
        local h = Roster.List(player)[intid - OPT_T_CALL]
        if h then Reply(player, Roster.Call(player, h.guid)) end
    elseif intid > OPT_T_SEND then
        local h = Roster.List(player)[intid - OPT_T_SEND]
        if h then Reply(player, Roster.Send(player, h.guid)) end
    end
    MaudeMenu(player, creature)
end))

return UI
