local _, ns = ...
local L = ns.L

local WhoPanel = {}
ns.WhoPanel = WhoPanel

local YES = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t "
local NO = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t "

function WhoPanel.ArmorName(armor)
  for subclass, key in pairs(ns.Rules.ARMOR_SUBCLASS) do
    if key == armor and C_Item and C_Item.GetItemSubClassInfo then
      local name = C_Item.GetItemSubClassInfo(4, subclass)
      if name then return name end
    end
  end
  local fallback = { cloth = L["Cloth"], leather = L["Leather"], mail = L["Mail"], plate = L["Plate"] }
  return fallback[armor] or tostring(armor)
end

function WhoPanel.ReasonText(reason, detail)
  local R = ns.Rules.REASON
  if reason == R.ARMOR then return L["Does not use %s"]:format(WhoPanel.ArmorName(detail)) end
  if reason == R.LEVEL then return L["Level %d"]:format(detail or 0) end
  if reason == R.CLASS then return L["Class only"] end
  return L["Unknown"]
end

local function ClassColored(char)
  local color = char.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[char.classFile]
  local name = char.name or "?"
  return color and color:WrapTextInColorCode(name) or name
end

function WhoPanel:Create(parent)
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 4, -4)
  title:SetText(L["Who can wear it"])
  local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  text:SetPoint("BOTTOMRIGHT", -4, 4)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  f.text = text
  self.frame = f
  self:Show(nil)
  return f
end

function WhoPanel:Show(row, entry)
  if not self.frame then return end
  if not row then self.frame.text:SetText(L["Select an appearance."]) return end
  local roster = ns.DB:Roster()
  if not next(roster) then
    self.frame.text:SetText(L["No characters yet. Log in with each of your characters once."])
    return
  end
  local app = ns.Collection.AppFor(row, entry)
  local keys = {}
  for key in pairs(roster) do keys[#keys + 1] = key end
  table.sort(keys)
  local lines = {}
  for _, key in ipairs(keys) do
    local char = roster[key]
    local ok, reason, detail = ns.Rules.CanWear(char, app)
    local line = (ok and YES or NO) .. ClassColored(char) .. " (" .. (char.level or "?") .. ")"
    if not ok then line = line .. " - " .. WhoPanel.ReasonText(reason, detail) end
    lines[#lines + 1] = line
  end
  self.frame.text:SetText(table.concat(lines, "\n"))
end
