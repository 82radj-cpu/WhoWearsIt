local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local ARMOR_LABELS = { cloth = "Cloth", leather = "Leather", mail = "Mail", plate = "Plate" }
local ROW_HEIGHT = 22

local state = { category = 4, armor = "cloth", onlyMissing = true, search = "", usableBy = nil, selected = nil }

local function CategoryName(category)
  local name = C_TransmogCollection and C_TransmogCollection.GetCategoryInfo
    and C_TransmogCollection.GetCategoryInfo(category)
  return name or ("#" .. category)
end

local function QualityColor(quality)
  local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  return c and c.hex or "|cffffffff"
end

local function SaveState()
  local char = ns.DB.char
  if not char then return end
  char.lastCategory, char.lastArmor = state.category, state.armor
  ns.DB:SetSetting("onlyMissing", state.onlyMissing)
end

local function InitRow(button, row)
  if not button.label then
    button:SetHeight(ROW_HEIGHT)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("LEFT", 2, 0)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
    button.label:SetPoint("RIGHT", -24, 0)
    button.label:SetJustifyH("LEFT")
    button.mark = button:CreateTexture(nil, "OVERLAY")
    button.mark:SetSize(14, 14)
    button.mark:SetPoint("RIGHT", -4, 0)
    button.mark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  end
  button.icon:SetTexture(row.icon or 134400)
  button.label:SetText(QualityColor(row.quality) .. (row.name or L["Loading…"]) .. "|r")
  button.mark:SetShown(row.collected)
  button:SetScript("OnClick", function()
    state.selected = row
    ns.Preview:Show(row)
    ns.WhoPanel:Show(row, UI.entry)
  end)
end

local function CreateList(parent)
  local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
  local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
  box:SetPoint("TOPLEFT", 150, -86)
  box:SetPoint("BOTTOMLEFT", 150, 40)
  box:SetWidth(300)
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
  bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 0)
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(ROW_HEIGHT)
  view:SetElementInitializer("Button", InitRow)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
  return box
end

local function CreateButton(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 80, 22)
  b:SetText(text)
  return b
end

function UI:Create()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "WhoWearsItFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(820, 500)
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.DB.char.point = { point, relPoint, x, y }
  end)
  local p = ns.DB.char and ns.DB.char.point
  if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER") end
  local title = f.TitleText
  if not title then
    title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
  end
  title:SetText(L["Who Wears It"])
  tinsert(UISpecialFrames, "WhoWearsItFrame")

  -- Left: slot list.
  f.categoryButtons = {}
  for i, category in ipairs(ns.Collection.CATEGORIES) do
    local b = CreateButton(f, CategoryName(category), 130)
    b:SetPoint("TOPLEFT", 12, -30 - (i - 1) * 24)
    b:SetScript("OnClick", function() state.category = category; state.selected = nil; UI:Refresh() end)
    f.categoryButtons[category] = b
  end

  -- Top: armor tabs, filters, search.
  f.armorButtons = {}
  for i, armor in ipairs(ns.Rules.ARMOR_ORDER) do
    local b = CreateButton(f, L[ARMOR_LABELS[armor]], 70)
    b:SetPoint("TOPLEFT", 150 + (i - 1) * 74, -30)
    b:SetScript("OnClick", function() state.armor = armor; UI:Refresh() end)
    f.armorButtons[armor] = b
  end

  local missing = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  missing:SetPoint("TOPLEFT", 150, -56)
  missing:SetSize(24, 24)
  local missingLabel = missing:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  missingLabel:SetPoint("LEFT", missing, "RIGHT", 2, 0)
  missingLabel:SetText(L["Only missing"])
  missing:SetScript("OnClick", function(cb) state.onlyMissing = cb:GetChecked(); UI:Refresh() end)
  f.missing = missing

  -- "Usable by" cycles: all characters -> each recorded character.
  local usable = CreateButton(f, L["All characters"], 150)
  usable:SetPoint("TOPLEFT", 290, -56)
  usable:SetScript("OnClick", function()
    local keys = {}
    for key in pairs(ns.DB:Roster()) do keys[#keys + 1] = key end
    table.sort(keys)
    local nextKey
    if not state.usableBy then nextKey = keys[1] else
      for i, key in ipairs(keys) do if key == state.usableBy then nextKey = keys[i + 1] end end
    end
    state.usableBy = nextKey
    UI:Refresh()
  end)
  f.usable = usable
  local usableLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  usableLabel:SetPoint("RIGHT", usable, "LEFT", -4, 0)
  usableLabel:SetText(L["Usable by:"])

  local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
  search:SetSize(140, 20)
  search:SetPoint("TOPLEFT", 460, -32)
  if search.Instructions then search.Instructions:SetText(L["Search"]) end
  search:SetScript("OnTextChanged", function(box, userInput)
    if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(box) end
    if userInput then state.search = box:GetText(); UI:Refresh() end
  end)

  -- Center: list. Right: preview on top, who-panel below.
  f.list = CreateList(f)
  local previewHolder = CreateFrame("Frame", nil, f)
  previewHolder:SetPoint("TOPLEFT", 480, -60)
  previewHolder:SetPoint("TOPRIGHT", -12, -60)
  previewHolder:SetHeight(250)
  ns.Preview:Create(previewHolder)
  local whoHolder = CreateFrame("Frame", nil, f)
  whoHolder:SetPoint("TOPLEFT", previewHolder, "BOTTOMLEFT", 0, -6)
  whoHolder:SetPoint("BOTTOMRIGHT", -12, 40)
  ns.WhoPanel:Create(whoHolder)

  -- Footer: progress and "Add to look".
  f.progress = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.progress:SetPoint("BOTTOMLEFT", 150, 16)
  f.status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.status:SetPoint("BOTTOMLEFT", 12, 16)
  f.status:SetWidth(130)
  f.status:SetJustifyH("LEFT")
  local add = CreateButton(f, L["Add to look"], 120)
  add:SetPoint("BOTTOMRIGHT", -12, 10)
  add:SetScript("OnClick", function()
    if not state.selected then return end
    local looks = ns.DB.global.looks
    local look = looks[#looks] or ns.Looks.Create(L["New look"])
    ns.Looks.Assign(look.id, state.category, state.selected.visualID)
    ns:Print("%s: " .. L["%d of %d"], look.name, ns.Looks.Progress(look, function(visualID)
      local row = UI.entry and UI.entry.byVisual[visualID]
      return row and row.collected
    end))
  end)

  f:SetScript("OnShow", function() UI:Refresh() end)
  self.frame = f
  return f
end

function UI:Refresh()
  local f = self.frame
  if not f or not f:IsShown() then return end
  local armorSlot = ns.Collection.ARMOR_SLOTS[state.category]
  for armor, b in pairs(f.armorButtons) do
    b:SetShown(armorSlot)
    b:SetEnabled(armor ~= state.armor)
  end
  for category, b in pairs(f.categoryButtons) do b:SetEnabled(category ~= state.category) end
  f.missing:SetChecked(state.onlyMissing)
  local char = state.usableBy and ns.DB:Roster()[state.usableBy]
  f.usable:SetText(char and char.name or L["All characters"])

  local rows, done, err, entry = ns.Collection:GetAppearances(state.category, armorSlot and state.armor or nil,
    { onlyMissing = state.onlyMissing, search = state.search, usableBy = state.usableBy })
  self.entry = entry
  f.list:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)

  local C = C_TransmogCollection
  local have = C and C.GetCategoryCollectedCount and C.GetCategoryCollectedCount(state.category) or 0
  local total = C and C.GetCategoryTotal and C.GetCategoryTotal(state.category) or 0
  local text = L["Collected %d of %d"]:format(have, total) .. "  " .. L["Missing %d"]:format(math.max(0, total - have))
  if not done then text = text .. "  " .. L["Loading…"] end
  if err then text = text .. "  (" .. err .. ")" end
  f.progress:SetText(text)
  local status = ns.fakeData and L["Fake data mode: %s"]:format(L["on"])
    or L["Strategy: %s"]:format(ns.Collection.strategy)
  if done and #rows == 0 and armorSlot and ns.Collection.strategy == "harvest" then
    status = L["Log in with a character that wears %s to fill this list."]:format(ns.WhoPanel.ArmorName(state.armor))
  end
  f.status:SetText(status)
  if state.selected then ns.WhoPanel:Show(state.selected, entry) end
  SaveState()
end

function UI:Toggle(onlyMissing)
  -- Opening in combat is fine (plain frames); Collection pauses its scans until combat ends.
  if not self.frame then
    local c = ns.DB.char
    state.category = c and c.lastCategory or 4
    state.armor = c and c.lastArmor or "cloth"
    state.onlyMissing = ns.DB:Setting("onlyMissing") ~= false
  end
  local f = self:Create()
  if onlyMissing ~= nil then state.onlyMissing = onlyMissing; f:Show(); self:Refresh() return end
  f:SetShown(not f:IsShown())
end
