-- wb_ui_client.lua
-- Client half of the Warband window. The server never runs this file: AIO.AddAddon() sends it
-- to each player's game client (with the AIO_Client addon installed), where it runs as an
-- addon. It only draws what the server sends (wb_ui.lua) and sends clicks back.
-- Style: classic WoW panels (dialog frame, header plate, bottom tabs), 3.3.5a addon API only.
--   * A minimap button opens and closes it.
--   * Tabs: Missions (now), Roster, Armory, Hamlet (later phases, shown greyed out).

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

local Handlers = AIO.AddHandlers("Warband", {})

local W, H = 700, 470
local LIST_W = 250
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
                       "WARLOCK", nil, "DRUID" }
local TABS = {
    { name = "Missions" },
    { name = "Roster",  later = "The roster and tavern open in phase 3." },
    { name = "Armory",  later = "The shared armory opens in phase 6." },
    { name = "Hamlet",  later = "Hamlet buildings open in phase 11." },
}

local frame, data, selected

local function Text(parent, font, r, g, b)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    if r then t:SetTextColor(r, g, b) end
    t:SetJustifyH("LEFT")
    return t
end

local function Inset(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0, 0, 0, 0.55)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    return f
end

local function ClassName(class, name)
    local token = CLASS_TOKENS[class]
    local c = token and RAID_CLASS_COLORS[token]
    if not c then return name end
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
end

local function Cap(s) return s and (s:sub(1, 1):upper() .. s:sub(2)) or "" end

-- Region:SetShown only exists in later expansions.
local function Shown(region, show) if show then region:Show() else region:Hide() end end

-- The frame ------------------------------------------------------------------------------------

local function MakeFrame()
    local f = CreateFrame("Frame", "WarbandFrame", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "WarbandFrame") -- Escape closes it
    f:Hide()

    -- Header plate with the title, like the game's own dialogs.
    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(320, 64)
    header:SetPoint("TOP", 0, 12)
    local title = Text(f, "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("Warband")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Company line under the header.
    f.company = Text(f, "GameFontHighlight")
    f.company:SetPoint("TOP", 0, -30)
    f.company:SetJustifyH("CENTER")

    -- Missions page --------------------------------------------------------------------------
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 18, -52)
    page:SetPoint("BOTTOMRIGHT", -18, 18)
    f.missions = page

    local listLabel = Text(page, "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 4, 0)
    listLabel:SetText("Contracts on the board")
    f.list = Inset(page)
    f.list:SetPoint("TOPLEFT", 0, -16)
    f.list:SetSize(LIST_W, H - 52 - 18 - 16 - 4)
    f.rows = {}

    f.detail = Inset(page)
    f.detail:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 8, 16)
    f.detail:SetPoint("BOTTOMRIGHT", 0, 0)
    local d = f.detail
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(40, 40)
    d.icon:SetPoint("TOPLEFT", 14, -14)
    d.banner = Text(d, "GameFontNormalSmall", 0.25, 1, 0.25)
    d.banner:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, 2)
    d.name = Text(d, "GameFontNormalLarge")
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -12)
    d.facts = Text(d, "GameFontHighlightSmall", 0.8, 0.8, 0.8)
    d.facts:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10)
    d.objective = Text(d, "GameFontNormal")
    d.objective:SetPoint("TOPLEFT", d.facts, "BOTTOMLEFT", 0, -12)
    d.text = Text(d, "GameFontHighlight")
    d.text:SetPoint("TOPLEFT", d.objective, "BOTTOMLEFT", 0, -8)
    d.text:SetWidth(W - 36 - LIST_W - 8 - 30)
    d.rewardsLabel = Text(d, "GameFontNormal")
    d.rewardsLabel:SetPoint("TOPLEFT", d.text, "BOTTOMLEFT", 0, -14)
    d.rewardsLabel:SetText("Rewards")
    d.rewards = Text(d, "GameFontHighlightSmall")
    d.rewards:SetPoint("TOPLEFT", d.rewardsLabel, "BOTTOMLEFT", 0, -4)
    d.partyLabel = Text(d, "GameFontNormal")
    d.partyLabel:SetPoint("TOPLEFT", d.rewards, "BOTTOMLEFT", 0, -14)
    d.party = Text(d, "GameFontHighlightSmall")
    d.party:SetPoint("TOPLEFT", d.partyLabel, "BOTTOMLEFT", 0, -4)
    d.party:SetWidth(W - 36 - LIST_W - 8 - 30)
    d.button = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.button:SetSize(150, 26)
    d.button:SetPoint("BOTTOMRIGHT", -12, 12)
    d.empty = Text(d, "GameFontDisable")
    d.empty:SetPoint("CENTER")
    d.empty:SetText("No contracts on the board.")

    -- Placeholder page for tabs that open in later phases.
    f.later = CreateFrame("Frame", nil, f)
    f.later:SetAllPoints(page)
    f.later.text = Text(f.later, "GameFontDisableLarge")
    f.later.text:SetPoint("CENTER")
    f.later.text:SetJustifyH("CENTER")

    -- Bottom tabs, the classic character-window kind.
    for i, tab in ipairs(TABS) do
        local t = CreateFrame("Button", "WarbandFrameTab" .. i, f, "CharacterFrameTabButtonTemplate")
        t:SetID(i)
        t:SetText(tab.name)
        if i == 1 then t:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 14, 8)
        else t:SetPoint("LEFT", _G["WarbandFrameTab" .. (i - 1)], "RIGHT", -16, 0) end
        t:SetScript("OnClick", function(self)
            PanelTemplates_SetTab(f, self:GetID())
            Handlers.Draw()
            PlaySound("igCharacterInfoTab")
        end)
    end
    PanelTemplates_SetNumTabs(f, #TABS)
    PanelTemplates_SetTab(f, 1)
    return f
end

local function Row(i)
    local r = frame.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, frame.list)
    r:SetSize(LIST_W - 12, 44)
    r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 46)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(34, 34)
    r.icon:SetPoint("LEFT", 4, 0)
    r.name = Text(r, "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -2)
    r.name:SetWidth(LIST_W - 60)
    r.sub = Text(r, "GameFontHighlightSmall", 0.75, 0.75, 0.75)
    r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 2)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    r.sel:SetBlendMode("ADD")
    r.sel:SetAllPoints()
    r.sel:SetVertexColor(1, 0.82, 0, 0.6)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    r:SetScript("OnClick", function(self)
        selected = self.key
        Handlers.Draw()
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    frame.rows[i] = r
    return r
end

-- Drawing ----------------------------------------------------------------------------------------

local function DrawDetail(m, onMission)
    local d = frame.detail
    Shown(d.empty, m == nil)
    for _, w in ipairs({ d.icon, d.banner, d.name, d.facts, d.objective, d.text, d.rewardsLabel, d.rewards,
                         d.partyLabel, d.party, d.button }) do Shown(w, m ~= nil) end
    if not m then return end
    d.icon:SetTexture(m.icon or QUESTION)
    d.banner:SetText(onMission and "ON MISSION" or "")
    d.name:SetText(m.name)
    d.facts:SetText(string.format("%s   |   %s mission   |   %s   |   Recommended level %s",
        m.dungeon, Cap(m.kind), m.length, m.level))
    d.objective:SetText("Objective: |cffffffff" .. (m.objective or "") .. "|r")
    d.text:SetText(m.text or "")
    d.rewards:SetText(m.rewards or "")

    local party = {}
    for _, b in ipairs(data.party) do
        party[#party + 1] = ClassName(b.class, b.name) .. " |cffa0a0a0(" .. b.level .. ")|r"
    end
    d.partyLabel:SetText(string.format("Your party (%d of 4 heroes)", #data.party))
    d.party:SetText(#party > 0 and table.concat(party, ",  ")
        or "|cffa0a0a0No heroes in your group yet. Until the tavern opens (phase 3), add bots with|r\n"
        .. "|cffffffff.playerbots bot addclass warrior|r |cffa0a0a0(or priest, mage, rogue...).|r")

    if onMission then
        d.button:SetText("Abandon mission")
        d.button:SetScript("OnClick", function() AIO.Handle("Warband", "Abandon") end)
    else
        d.button:SetText("Embark")
        d.button:SetScript("OnClick", function() AIO.Handle("Warband", "Embark", m.key) end)
    end
    d.button:Enable()
end

local function DrawMissions()
    local onMission = data.active ~= nil
    local list = onMission and { data.active } or data.offers
    if onMission then selected = data.active.key end
    local found = false
    for _, m in ipairs(list) do found = found or m.key == selected end
    if not found then selected = list[1] and list[1].key end

    local current
    for i, m in ipairs(list) do
        local r = Row(i)
        r.key = m.key
        r.icon:SetTexture(m.icon or QUESTION)
        r.name:SetText(m.name)
        r.sub:SetText(string.format("%s  -  %s, %s", m.dungeon, Cap(m.kind), m.length))
        Shown(r.sel, m.key == selected)
        r:Show()
        if m.key == selected then current = m end
    end
    for i = #list + 1, #frame.rows do frame.rows[i]:Hide() end
    DrawDetail(current, onMission)
end

function Handlers.Draw()
    if not frame or not data then return end
    frame.company:SetText(string.format("Commander %s   |cffa0a0a0-|r   Act %d   |cffa0a0a0-|r   |cffffd100%d|r gold   "
        .. "|cffa0a0a0-|r   %d renown   |cffa0a0a0-|r   %d materials",
        data.commander, data.act, data.gold, data.renown, data.materials))
    local tab = TABS[PanelTemplates_GetSelectedTab(frame) or 1]
    if tab.later then
        frame.missions:Hide()
        frame.later.text:SetText(tab.name .. "\n\n" .. tab.later)
        frame.later:Show()
    else
        frame.later:Hide()
        frame.missions:Show()
        DrawMissions()
    end
end

-- From the server ------------------------------------------------------------------------------

function Handlers.Show(player, newData)
    if type(newData) ~= "table" then return end
    data = newData
    frame = frame or MakeFrame()
    frame:Show()
    Handlers.Draw()
end

function Handlers.Update(player, newData)
    if type(newData) ~= "table" then return end
    data = newData
    if frame and frame:IsShown() then Handlers.Draw() end
end

-- The minimap button -----------------------------------------------------------------------------

local function MakeMinimapButton()
    local b = CreateFrame("Button", "WarbandMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    local angle = math.rad(200)
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Banner_02")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:SetScript("OnClick", function()
        if frame and frame:IsShown() then frame:Hide() else AIO.Handle("Warband", "Open") end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Warband")
        GameTooltip:AddLine("Click to open the company window.", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

MakeMinimapButton()
