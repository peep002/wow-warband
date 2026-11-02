-- wb_ui_client.lua
-- Client half of the Warband window. The server never runs this file: AIO.AddAddon() sends it
-- to each player's game client (with the AIO_Client addon installed), where it runs as an
-- addon. It only draws what the server sends (wb_ui.lua) and sends clicks back.
-- Style: classic WoW panels (dialog frame, header plate, bottom tabs), 3.3.5a addon API only.
--   * A minimap button opens and closes it.
--   * Tabs: Missions, Roster, Tavern, Armory, Memorial; Hamlet is shown greyed out for a later phase.

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

local Handlers = AIO.AddHandlers("Warband", {})

local W, H = 720, 500
local LIST_W = 250
local CARD_H = 74
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
                       "WARLOCK", nil, "DRUID" }
local ROLE = { tank = { "Tank", 0.4, 0.6, 1 }, healer = { "Healer", 0.3, 1, 0.3 }, dps = { "Damage", 1, 0.4, 0.3 } }
local TABS = {
    { key = "missions", name = "Missions" },
    { key = "roster",   name = "Roster" },
    { key = "tavern",   name = "Tavern" },
    { key = "armory",   name = "Armory" },
    { key = "memorial", name = "Memorial" },
    { key = "hamlet",   name = "Hamlet", later = "Hamlet buildings open in phase 11." },
}

local SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest", [20] = "Chest",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrists", [10] = "Hands", [11] = "Finger", [12] = "Trinket",
    [16] = "Back", [13] = "One-hand", [17] = "Two-hand", [21] = "Main hand", [22] = "Off hand", [14] = "Shield",
    [23] = "Held in off hand", [15] = "Ranged", [25] = "Thrown", [26] = "Ranged", [28] = "Relic", [19] = "Tabard" }

local frame, data, selected, selectedItem

-- Small helpers ----------------------------------------------------------------------------------

local function Text(parent, font, r, g, b)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    if r then t:SetTextColor(r, g, b) end
    t:SetJustifyH("LEFT")
    return t
end

-- Region:SetShown only exists in later expansions.
local function Shown(region, show) if show then region:Show() else region:Hide() end end

local function Inset(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0, 0, 0, 0.55)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    return f
end

local function ClassColor(class)
    local token = CLASS_TOKENS[class]
    return token and RAID_CLASS_COLORS[token]
end

local function ClassName(class, name)
    local c = ClassColor(class)
    if not c then return name end
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
end

local function Cap(s) return s and (s:sub(1, 1):upper() .. s:sub(2)) or "" end

local function SetClassIcon(tex, class)
    local coords = CLASS_TOKENS[class] and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[CLASS_TOKENS[class]]
    if coords then
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(unpack(coords))
    else
        tex:SetTexture(QUESTION)
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local function TabIndex(key)
    for i, t in ipairs(TABS) do
        if t.key == key then return i end
    end
end

-- The frame --------------------------------------------------------------------------------------

local function MakeScrollPage(parent, name)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.header = Text(page, "GameFontNormal")
    page.header:SetPoint("TOPLEFT", 4, 0)
    page.note = Text(page, "GameFontHighlightSmall", 0.8, 0.8, 0.8)
    page.note:SetPoint("TOPRIGHT", -4, 0)
    page.note:SetJustifyH("RIGHT")
    local box = Inset(page)
    box:SetPoint("TOPLEFT", 0, -16)
    box:SetPoint("BOTTOMRIGHT", 0, 0)
    page.scroll = CreateFrame("ScrollFrame", name, box, "UIPanelScrollFrameTemplate")
    page.scroll:SetPoint("TOPLEFT", 6, -6)
    page.scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    page.content = CreateFrame("Frame", nil, page.scroll)
    page.content:SetSize(W - 36 - 40, 10)
    page.scroll:SetScrollChild(page.content)
    page.empty = Text(box, "GameFontDisable")
    page.empty:SetPoint("CENTER")
    page.empty:SetJustifyH("CENTER")
    page.cards = {}
    return page
end

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

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", 18, -52)
    body:SetPoint("BOTTOMRIGHT", -18, 18)
    f.pages = {}

    -- Missions page ----------------------------------------------------------------------------
    local page = CreateFrame("Frame", nil, body)
    page:SetAllPoints()
    f.pages.missions = page

    local listLabel = Text(page, "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 4, 0)
    listLabel:SetText("Contracts on the board")
    f.actLine = Text(page, "GameFontHighlightSmall", 0.8, 0.8, 0.8)
    f.actLine:SetPoint("TOPRIGHT", -4, 0)
    f.actLine:SetJustifyH("RIGHT")
    f.list = Inset(page)
    f.list:SetPoint("TOPLEFT", 0, -16)
    f.list:SetPoint("BOTTOMLEFT", 0, 0)
    f.list:SetWidth(LIST_W)
    f.rows = {}

    f.detail = Inset(page)
    f.detail:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 8, 16)
    f.detail:SetPoint("BOTTOMRIGHT", 0, 0)
    local d = f.detail
    local textW = W - 36 - LIST_W - 8 - 30
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
    d.text:SetWidth(textW)
    d.rewardsLabel = Text(d, "GameFontNormal")
    d.rewardsLabel:SetPoint("TOPLEFT", d.text, "BOTTOMLEFT", 0, -14)
    d.rewardsLabel:SetText("Rewards")
    d.rewards = Text(d, "GameFontHighlightSmall")
    d.rewards:SetPoint("TOPLEFT", d.rewardsLabel, "BOTTOMLEFT", 0, -4)
    d.partyLabel = Text(d, "GameFontNormal")
    d.partyLabel:SetPoint("TOPLEFT", d.rewards, "BOTTOMLEFT", 0, -14)
    d.party = Text(d, "GameFontHighlightSmall")
    d.party:SetPoint("TOPLEFT", d.partyLabel, "BOTTOMLEFT", 0, -4)
    d.party:SetWidth(textW)
    d.button = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.button:SetSize(150, 26)
    d.button:SetPoint("BOTTOMRIGHT", -12, 12)
    d.empty = Text(d, "GameFontDisable")
    d.empty:SetPoint("CENTER")
    d.empty:SetText("No contracts on the board.")

    -- Roster and tavern pages ------------------------------------------------------------------
    f.pages.roster = MakeScrollPage(body, "WarbandRosterScroll")
    f.pages.tavern = MakeScrollPage(body, "WarbandTavernScroll")
    f.pages.memorial = MakeScrollPage(body, "WarbandMemorialScroll")
    -- The commander's own wound: a line and a Treat button above the roster.
    local r = f.pages.roster
    r.treatSelf = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    r.treatSelf:SetSize(150, 20)
    r.treatSelf:SetPoint("TOP", 40, 3)
    r.treatSelf:SetScript("OnClick", function() AIO.Handle("Warband", "Treat", 0) end)

    -- Armory page ------------------------------------------------------------------------------
    local ap = CreateFrame("Frame", nil, body)
    ap:SetAllPoints()
    f.pages.armory = ap
    ap.header = Text(ap, "GameFontNormal")
    ap.header:SetPoint("TOPLEFT", 4, 0)
    ap.equipAll = CreateFrame("Button", nil, ap, "UIPanelButtonTemplate")
    ap.equipAll:SetSize(170, 20)
    ap.equipAll:SetPoint("TOPRIGHT", -126, 3)
    ap.equipAll:SetScript("OnClick", function() AIO.Handle("Warband", "EquipAll") end)
    ap.sellJunk = CreateFrame("Button", nil, ap, "UIPanelButtonTemplate")
    ap.sellJunk:SetSize(120, 20)
    ap.sellJunk:SetPoint("TOPRIGHT", 0, 3)
    ap.sellJunk:SetScript("OnClick", function() AIO.Handle("Warband", "SellJunk") end)
    local box = Inset(ap)
    box:SetPoint("TOPLEFT", 0, -20)
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetWidth(LIST_W + 40)
    ap.scroll = CreateFrame("ScrollFrame", "WarbandArmoryScroll", box, "UIPanelScrollFrameTemplate")
    ap.scroll:SetPoint("TOPLEFT", 6, -6)
    ap.scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    ap.content = CreateFrame("Frame", nil, ap.scroll)
    ap.content:SetSize(LIST_W, 10)
    ap.scroll:SetScrollChild(ap.content)
    ap.empty = Text(box, "GameFontDisable")
    ap.empty:SetPoint("CENTER")
    ap.empty:SetJustifyH("CENTER")
    ap.empty:SetText("The armory is empty.\nEverything your warband loots ends up here.")
    ap.rows = {}
    local ad = Inset(ap)
    ad:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
    ad:SetPoint("BOTTOMRIGHT", 0, 0)
    ap.detail = ad
    ad.icon = CreateFrame("Button", nil, ad)
    ad.icon:SetSize(40, 40)
    ad.icon:SetPoint("TOPLEFT", 14, -14)
    ad.icon.tex = ad.icon:CreateTexture(nil, "ARTWORK")
    ad.icon.tex:SetAllPoints()
    ad.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ad.name = Text(ad, "GameFontNormalLarge")
    ad.name:SetPoint("TOPLEFT", ad.icon, "TOPRIGHT", 10, -2)
    ad.name:SetWidth(W - 36 - LIST_W - 40 - 8 - 80)
    ad.facts = Text(ad, "GameFontHighlightSmall", 0.8, 0.8, 0.8)
    ad.facts:SetPoint("TOPLEFT", ad.name, "BOTTOMLEFT", 0, -4)
    ad.hint = Text(ad, "GameFontDisableSmall")
    ad.hint:SetPoint("TOPLEFT", ad.icon, "BOTTOMLEFT", 0, -8)
    ad.hint:SetText("Hover the icon for the item's full tooltip.")
    ad.giveLabel = Text(ad, "GameFontNormal")
    ad.giveLabel:SetPoint("TOPLEFT", ad.hint, "BOTTOMLEFT", 0, -12)
    ad.giveLabel:SetText("Give to")
    ad.give = {}
    for i = 1, 5 do
        local b = CreateFrame("Button", nil, ad, "UIPanelButtonTemplate")
        b:SetSize(W - 36 - LIST_W - 40 - 8 - 30, 22)
        b:SetPoint("TOPLEFT", ad.giveLabel, "BOTTOMLEFT", 0, -4 - (i - 1) * 25)
        ad.give[i] = b
    end
    ad.none = Text(ad, "GameFontDisableSmall")
    ad.none:SetPoint("TOPLEFT", ad.giveLabel, "BOTTOMLEFT", 0, -6)
    ad.none:SetWidth(W - 36 - LIST_W - 40 - 8 - 30)
    ad.none:SetText("Only you and the heroes in your party can be equipped, in the hamlet. Call heroes from the Roster tab.")
    ad.sell = CreateFrame("Button", nil, ad, "UIPanelButtonTemplate")
    ad.sell:SetSize(130, 22)
    ad.sell:SetPoint("BOTTOMLEFT", 12, 12)
    ad.salvage = CreateFrame("Button", nil, ad, "UIPanelButtonTemplate")
    ad.salvage:SetSize(160, 22)
    ad.salvage:SetPoint("LEFT", ad.sell, "RIGHT", 8, 0)
    ad.empty = Text(ad, "GameFontDisable")
    ad.empty:SetPoint("CENTER")
    ad.empty:SetText("Pick an item on the left.")

    -- Placeholder page for tabs that open in later phases.
    f.pages.later = CreateFrame("Frame", nil, body)
    f.pages.later:SetAllPoints()
    f.pages.later.text = Text(f.pages.later, "GameFontDisableLarge")
    f.pages.later.text:SetPoint("CENTER")
    f.pages.later.text:SetJustifyH("CENTER")

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

-- Missions page ------------------------------------------------------------------------------------

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

local function DrawDetail(m, onMission)
    local d = frame.detail
    Shown(d.empty, m == nil)
    for _, w in ipairs({ d.icon, d.banner, d.name, d.facts, d.objective, d.text, d.rewardsLabel, d.rewards,
                         d.partyLabel, d.party, d.button }) do Shown(w, m ~= nil) end
    if not m then return end
    d.icon:SetTexture(m.icon or QUESTION)
    d.banner:SetText(onMission and "ON MISSION" or "")
    d.name:SetText(m.name)
    d.facts:SetText(string.format("%s   |   %s   |   %s   |   Recommended level %s",
        m.dungeon, m.kind == "gate" and "|cffff8020Act gate|r" or (Cap(m.kind) .. " mission"), m.length, m.level))
    d.objective:SetText("Objective: |cffffffff" .. (m.objective or "") .. "|r")
    d.text:SetText(m.text or "")
    d.rewards:SetText(m.rewards or "")

    local party = {}
    for _, b in ipairs(data.party) do
        party[#party + 1] = ClassName(b.class, b.name) .. " |cffa0a0a0(" .. b.level .. ")|r"
    end
    d.partyLabel:SetText(string.format("Your party (%d of %d heroes)", #data.party, data.maxParty))
    d.party:SetText(#party > 0 and table.concat(party, ",  ")
        or "|cffa0a0a0No heroes in your party. Call them from the Roster tab, or hire some at the Tavern.|r")

    if onMission then
        d.button:SetText("Abandon mission")
        d.button:SetScript("OnClick", function() AIO.Handle("Warband", "Abandon") end)
        d.button:Enable()
    else
        d.button:SetText("Embark")
        d.button:SetScript("OnClick", function() AIO.Handle("Warband", "Embark", m.key) end)
        if #data.party >= data.minParty then d.button:Enable() else d.button:Disable() end
    end
end

local function DrawMissions()
    frame.actLine:SetText(data.progress >= data.mainsBeforeGate
        and string.format("Act %d: %s  -  |cffff8020the gate is open|r  (level cap %d)", data.act, data.actName, data.levelCap)
        or string.format("Act %d: %s  -  main missions %d of %d, then the gate  (level cap %d)", data.act, data.actName,
            data.progress, data.mainsBeforeGate, data.levelCap))
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
        r.sub:SetText(string.format("%s  -  %s, %s", m.dungeon, m.kind == "gate" and "|cffff8020Gate|r" or Cap(m.kind), m.length))
        Shown(r.sel, m.key == selected)
        r:Show()
        if m.key == selected then current = m end
    end
    for i = #list + 1, #frame.rows do frame.rows[i]:Hide() end
    DrawDetail(current, onMission)
end

-- Hero / recruit cards (roster and tavern pages) ---------------------------------------------------

local function TraitTooltip(self)
    if not self.trait then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(self.trait.name, unpack(self.color))
    GameTooltip:AddLine(self.trait.text, 1, 1, 1, true)
    GameTooltip:AddLine("Traits take effect in a later phase.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function TraitButton(card)
    local b = CreateFrame("Button", nil, card)
    b:SetHeight(14)
    b.label = Text(b, "GameFontHighlightSmall")
    b.label:SetPoint("LEFT")
    b:SetScript("OnEnter", TraitTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function Card(page, i)
    local c = page.cards[i]
    if c then return c end
    c = CreateFrame("Frame", nil, page.content)
    c:SetSize(W - 36 - 40, CARD_H - 4)
    c:SetPoint("TOPLEFT", 0, -(i - 1) * CARD_H)
    c:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    c:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    c:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(44, 44)
    c.icon:SetPoint("LEFT", 10, 0)
    c.name = Text(c, "GameFontNormalLarge")
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 2)
    c.role = Text(c, "GameFontNormalSmall")
    c.role:SetPoint("LEFT", c.name, "RIGHT", 10, 0)
    c.what = Text(c, "GameFontHighlightSmall", 0.85, 0.85, 0.85)
    c.what:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    c.good = TraitButton(c)
    c.good:SetPoint("TOPLEFT", c.what, "BOTTOMLEFT", 0, -3)
    c.bad = TraitButton(c)
    c.bad:SetPoint("LEFT", c.good, "RIGHT", 14, 0)
    c.story = Text(c, "GameFontDisableSmall")
    c.story:SetPoint("TOPLEFT", c.good, "BOTTOMLEFT", 0, -3)
    c.story:SetWidth(W - 36 - 40 - 64 - 170)
    c.status = Text(c, "GameFontHighlightSmall")
    c.status:SetPoint("TOPRIGHT", -12, -10)
    c.status:SetJustifyH("RIGHT")
    c.button = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    c.button:SetSize(140, 24)
    c.button:SetPoint("BOTTOMRIGHT", -10, 10)
    c.button2 = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    c.button2:SetSize(140, 24)
    c.button2:SetPoint("RIGHT", c.button, "LEFT", -6, 0)
    c.button2:Hide()
    page.cards[i] = c
    return c
end

local function FillTrait(b, trait, sign, color)
    b.trait, b.color = trait, color
    if trait then
        b.label:SetText(sign .. " " .. trait.name)
        b.label:SetTextColor(unpack(color))
        b:SetWidth(b.label:GetStringWidth() + 4)
        b:Show()
    else
        b:Hide()
    end
end

local function FillCard(c, p)
    SetClassIcon(c.icon, p.class)
    c.name:SetText(ClassName(p.class, p.name))
    local role = ROLE[p.role] or ROLE.dps
    c.role:SetText(role[1])
    c.role:SetTextColor(role[2], role[3], role[4])
    c.what:SetText(string.format("Level %d %s  -  %s %s", p.level, p.race, p.spec, p.className))
    FillTrait(c.good, p.good, "+", { 0.3, 1, 0.3 })
    FillTrait(c.bad, p.bad, "-", { 1, 0.35, 0.3 })
    c.story:SetText(p.backstory or "")
    c.button2:Hide()
end

local function Place(page, count, emptyText)
    page.content:SetHeight(math.max(10, count * CARD_H))
    for i = count + 1, #page.cards do page.cards[i]:Hide() end
    page.empty:SetText(emptyText or "")
    Shown(page.empty, count == 0)
end

local function DrawRoster()
    local page = frame.pages.roster
    local inParty = 0
    for _, h in ipairs(data.roster) do if h.inParty and h.status == "alive" then inParty = inParty + 1 end end
    page.header:SetText(string.format("Roster: %d of %d heroes", data.alive, data.slots)
        .. (data.wounded and "   |cffff3333You are wounded|r" or ""))
    Shown(page.treatSelf, data.wounded)
    if data.wounded then
        page.treatSelf:SetText(string.format("Treat yourself (%d g)", data.treatCost))
        if data.onMission or data.gold < data.treatCost then page.treatSelf:Disable() else page.treatSelf:Enable() end
    end
    page.note:SetText(string.format("Party: %d of %d   (embarking needs %d)", inParty, data.maxParty, data.minParty))
    for i, h in ipairs(data.roster) do
        local c = Card(page, i)
        FillCard(c, h)
        local alive = h.status == "alive"
        c.status:SetText((alive and (h.inParty and "|cff33ff33In your party|r" or "|cffa0a0a0In the barracks|r")
            or ("|cffff3333" .. Cap(h.status) .. "|r")) .. (h.wounded and "\n|cffff3333Wounded (-10% health)|r" or "")
            .. "\n|cffa0a0a0" .. h.missions .. " missions|r")
        if alive and h.wounded then
            c.button2:SetText(string.format("Treat (%d gold)", h.treatCost))
            local guid = h.guid
            c.button2:SetScript("OnClick", function() AIO.Handle("Warband", "Treat", guid) end)
            if data.onMission or data.gold < h.treatCost then c.button2:Disable() else c.button2:Enable() end
            c.button2:Show()
        end
        if not alive then
            c.button:Hide()
        else
            c.button:Show()
            c.button:SetText(h.inParty and "Send to barracks" or "Call to party")
            local guid, action = h.guid, h.inParty and "Send" or "Call"
            c.button:SetScript("OnClick", function() AIO.Handle("Warband", action, guid) end)
            if data.onMission or (not h.inParty and inParty >= data.maxParty) then c.button:Disable() else c.button:Enable() end
        end
        c:Show()
    end
    Place(page, #data.roster, "Nobody on the roster yet.\nHire your first heroes at the Tavern.")
end

local function DrawTavern()
    local page = frame.pages.tavern
    local full = data.alive >= data.slots
    page.header:SetText(data.foundingLeft > 0
        and string.format("Founding recruits: hire %d for free", data.foundingLeft)
        or string.format("Recruits for hire (%d)", #data.recruits))
    page.note:SetText(string.format("Roster: %d of %d   |   Company gold: |cffffd100%d|r", data.alive, data.slots, data.gold))
    for i, r in ipairs(data.recruits) do
        local c = Card(page, i)
        FillCard(c, r)
        local free = r.founding and data.foundingLeft > 0
        local afford = free or data.gold >= r.cost
        c.status:SetText(free and "|cff33ff33Free|r" or string.format("%s%d gold|r", afford and "|cffffd100" or "|cffff3333", r.cost))
        c.button:Show()
        c.button:SetText("Hire")
        local guid = r.guid
        c.button:SetScript("OnClick", function() AIO.Handle("Warband", "Hire", guid) end)
        if full or not afford then c.button:Disable() else c.button:Enable() end
        c:Show()
    end
    Place(page, #data.recruits, "Nobody is waiting at the tavern.\nNew recruits arrive after each mission.")
end

-- Armory page --------------------------------------------------------------------------------------

local function ItemLink(it)
    -- item:id:enchant:gem1:gem2:gem3:gem4:random:unique:level (random < 0 = a random suffix)
    local random = it.prop > 0 and it.prop or (it.suffix > 0 and -it.suffix or 0)
    return string.format("item:%d:0:0:0:0:0:%d:0:0", it.entry, random)
end

local function QualityColor(q)
    local _, _, _, hex = GetItemQualityColor(q or 1)
    return hex or "|cffffffff"
end

local function ItemIcon(entry)
    return (GetItemIcon and GetItemIcon(entry)) or select(10, GetItemInfo(entry)) or QUESTION
end

local function ShowItemTooltip(owner, it)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(ItemLink(it))
    GameTooltip:Show()
end

local function ArmoryRow(i)
    local ap = frame.pages.armory
    local r = ap.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, ap.content)
    r:SetSize(LIST_W, 36)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * 38)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 2, 0)
    r.name = Text(r, "GameFontNormalSmall")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
    r.name:SetWidth(LIST_W - 44)
    r.sub = Text(r, "GameFontHighlightSmall", 0.7, 0.7, 0.7)
    r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 1)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    r.sel:SetBlendMode("ADD")
    r.sel:SetAllPoints()
    r.sel:SetVertexColor(1, 0.82, 0, 0.6)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    r:SetScript("OnClick", function(self)
        selectedItem = self.id
        Handlers.Draw()
    end)
    r:SetScript("OnEnter", function(self) if self.item then ShowItemTooltip(self, self.item) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ap.rows[i] = r
    return r
end

local function DrawArmory()
    local ap = frame.pages.armory
    local upgrades, junk = 0, 0
    for _, it in ipairs(data.armory) do
        if #it.upgrades > 0 then upgrades = upgrades + 1 end
        if it.quality == 0 then junk = junk + 1 end
    end
    ap.header:SetText(string.format("Armory: %d item%s   |cffa0a0a0-|r   %d materials", #data.armory,
        #data.armory == 1 and "" or "s", data.materials))
    ap.equipAll:SetText(string.format("Equip all upgrades (%d)", upgrades))
    if upgrades > 0 and not data.onMission then ap.equipAll:Enable() else ap.equipAll:Disable() end
    ap.sellJunk:SetText(string.format("Sell junk (%d)", junk))
    if junk > 0 then ap.sellJunk:Enable() else ap.sellJunk:Disable() end

    local current
    for i, it in ipairs(data.armory) do
        local r = ArmoryRow(i)
        r.id, r.item = it.id, it
        r.icon:SetTexture(ItemIcon(it.entry))
        r.name:SetText(QualityColor(it.quality) .. it.name .. "|r" .. (it.count > 1 and (" x" .. it.count) or ""))
        r.sub:SetText(string.format("Item level %d  -  %s%s", it.ilvl, SLOT_NAMES[it.invtype] or "",
            #it.upgrades > 0 and "  |cff33ff33Upgrade|r" or ""))
        Shown(r.sel, it.id == selectedItem)
        r:Show()
        if it.id == selectedItem then current = it end
    end
    for i = #data.armory + 1, #ap.rows do ap.rows[i]:Hide() end
    ap.content:SetHeight(math.max(10, #data.armory * 38))
    Shown(ap.empty, #data.armory == 0)

    local ad = ap.detail
    Shown(ad.empty, current == nil)
    for _, w in ipairs({ ad.icon, ad.name, ad.facts, ad.hint, ad.giveLabel, ad.sell, ad.salvage }) do Shown(w, current ~= nil) end
    for _, b in ipairs(ad.give) do b:Hide() end
    ad.none:Hide()
    if not current then return end
    local it = current
    ad.icon.tex:SetTexture(ItemIcon(it.entry))
    ad.icon:SetScript("OnEnter", function(self) ShowItemTooltip(self, it) end)
    ad.name:SetText(QualityColor(it.quality) .. it.name .. "|r")
    ad.facts:SetText(string.format("%s   |   Item level %d   |   Requires level %d", SLOT_NAMES[it.invtype] or "?",
        it.ilvl, it.reqlevel))
    local gains = {}
    for _, u in ipairs(it.upgrades) do gains[u.guid] = u.gain end
    for i, t in ipairs(data.targets) do
        local b = ad.give[i]
        if b then
            local gain = gains[t.guid]
            b:SetText(ClassName(t.class, t.name) .. string.format(" (%d)", t.level)
                .. (gain and string.format("  |cff33ff33+%d%%|r", math.floor(gain * 100 + 0.5)) or "  |cffa0a0a0not an upgrade|r"))
            local guid, id = t.guid, it.id
            b:SetScript("OnClick", function() AIO.Handle("Warband", "Equip", id, guid) end)
            if data.onMission then b:Disable() else b:Enable() end
            b:Show()
        end
    end
    Shown(ad.none, #data.targets <= 1)
    if #data.targets <= 1 then
        ad.none:ClearAllPoints()
        ad.none:SetPoint("TOPLEFT", ad.give[1], "BOTTOMLEFT", 0, -6)
    end
    ad.sell:SetText(string.format("Sell (%d gold)", it.sell * it.count))
    ad.sell:SetScript("OnClick", function() AIO.Handle("Warband", "Sell", it.id) end)
    ad.salvage:SetText(string.format("Salvage (+%d materials)", it.salvage * it.count))
    ad.salvage:SetScript("OnClick", function() AIO.Handle("Warband", "Salvage", it.id) end)
end

local function DrawMemorial()
    local page = frame.pages.memorial
    page.header:SetText("The memorial wall")
    page.note:SetText(#data.memorial == 0 and "" or string.format("%d fallen", #data.memorial))
    for i, f in ipairs(data.memorial) do
        local c = Card(page, i)
        SetClassIcon(c.icon, f.class)
        c.icon:SetDesaturated(true)
        c.name:SetText(ClassName(f.class, f.name))
        c.role:SetText("")
        c.what:SetText(string.format("Level %d %s %s  -  survived %d mission%s", f.level, f.race, f.className, f.missions,
            f.missions == 1 and "" or "s"))
        c.good:Hide()
        c.bad:Hide()
        c.story:SetText("|cffd0a060" .. f.cause .. "|r")
        c.status:SetText("|cffa0a0a0" .. f.died .. "|r")
        c.button:Hide()
        c.button2:Hide()
        c:Show()
    end
    Place(page, #data.memorial, "Nobody has fallen yet.\nMay it stay that way.")
end

-- Drawing the whole window -------------------------------------------------------------------------

function Handlers.Draw()
    if not frame or not data then return end
    frame.company:SetText(string.format("Commander %s   |cffa0a0a0-|r   Act %d   |cffa0a0a0-|r   |cffffd100%d|r gold   "
        .. "|cffa0a0a0-|r   %d renown   |cffa0a0a0-|r   %d materials",
        data.commander, data.act, data.gold, data.renown, data.materials))
    local tab = TABS[PanelTemplates_GetSelectedTab(frame) or 1]
    for _, p in pairs(frame.pages) do p:Hide() end
    if tab.later then
        frame.pages.later.text:SetText(tab.name .. "\n\n" .. tab.later)
        frame.pages.later:Show()
    elseif tab.key == "missions" then
        frame.pages.missions:Show()
        DrawMissions()
    elseif tab.key == "roster" then
        frame.pages.roster:Show()
        DrawRoster()
    elseif tab.key == "tavern" then
        frame.pages.tavern:Show()
        DrawTavern()
    elseif tab.key == "memorial" then
        frame.pages.memorial:Show()
        DrawMemorial()
    elseif tab.key == "armory" then
        frame.pages.armory:Show()
        DrawArmory()
    end
end

-- From the server ------------------------------------------------------------------------------------

function Handlers.Show(player, newData, tab)
    if type(newData) ~= "table" then return end
    data = newData
    frame = frame or MakeFrame()
    if type(tab) == "string" and TabIndex(tab) then PanelTemplates_SetTab(frame, TabIndex(tab)) end
    frame:Show()
    Handlers.Draw()
end

function Handlers.Update(player, newData)
    if type(newData) ~= "table" then return end
    data = newData
    if frame and frame:IsShown() then Handlers.Draw() end
end

-- The minimap button -----------------------------------------------------------------------------------

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
