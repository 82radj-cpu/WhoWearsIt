local _, ns = ...
local L = ns.L

local Preview = {}
ns.Preview = Preview

-- Built on demand by MainFrame (never at load time).
function Preview:Create(parent)
  if self.frame then return self.frame end
  local model = CreateFrame("DressUpModel", nil, parent)
  model:SetAllPoints()
  model:EnableMouse(true)
  model:EnableMouseWheel(true)
  model.rotation, model.zoom = 0, 0

  model:SetScript("OnShow", function(m) m:SetUnit("player") end)
  model:SetScript("OnMouseDown", function(m) m.dragX = GetCursorPosition() end)
  model:SetScript("OnMouseUp", function(m) m.dragX = nil end)
  model:SetScript("OnUpdate", function(m)
    if not m.dragX then return end
    local x = GetCursorPosition()
    m.rotation = m.rotation + (x - m.dragX) * 0.01
    m.dragX = x
    m:SetFacing(m.rotation)
  end)
  model:SetScript("OnMouseWheel", function(m, delta)
    m.zoom = math.max(-1, math.min(1, m.zoom + delta * 0.1))
    if m.SetPortraitZoom then m:SetPortraitZoom(m.zoom) end
  end)

  local undress = CreateFrame("Button", nil, model, "UIPanelButtonTemplate")
  undress:SetSize(90, 20)
  undress:SetPoint("BOTTOMRIGHT", -4, 4)
  undress:SetText(L["Undress"])
  undress:SetScript("OnClick", function() model:Undress() end)

  model:SetUnit("player")
  self.frame = model
  return model
end

-- Try a row on the logged-in character. Retries once when the item data arrives.
function Preview:Show(row)
  local model = self.frame
  if not model or not row or not row.sourceID then return end
  local result = model:TryOn(row.sourceID)
  local pending = Enum and Enum.ItemTryOnReason and Enum.ItemTryOnReason.DataPending
  if pending and result == pending then
    C_Timer.After(0.5, function() model:TryOn(row.sourceID) end)
  end
end
