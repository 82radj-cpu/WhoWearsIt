local _, ns = ...
local L = ns.L

local Minimap = {}
ns.Minimap = Minimap

local ICON = "Interface\\Icons\\INV_Chest_Cloth_17"

local function Tooltip(tt)
  tt:AddLine(L["Who Wears It"])
  tt:AddLine(L["Left-click: open or close"], 1, 1, 1)
end

-- Native add-on compartment (declared in the TOC). Globals because the TOC names them.
function WhoWearsIt_OnCompartmentClick()
  ns.UI:Toggle()
end

function WhoWearsIt_OnCompartmentEnter(_, button)
  GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
  Tooltip(GameTooltip)
  GameTooltip:Show()
end

function WhoWearsIt_OnCompartmentLeave()
  GameTooltip:Hide()
end

-- Optional minimap button: only if another addon already loaded LibDataBroker + LibDBIcon.
-- 0.1 bundles no libraries (LibDataBroker has no declared license; see docs/API-NOTES.md).
function Minimap:Init()
  if self.ready then return end
  self.ready = true
  if not LibStub then return end
  local LDB = LibStub("LibDataBroker-1.1", true)
  local icon = LibStub("LibDBIcon-1.0", true)
  if not (LDB and icon) then return end
  local broker = LDB:NewDataObject("WhoWearsIt", {
    type = "launcher",
    icon = ICON,
    OnClick = function() ns.UI:Toggle() end,
    OnTooltipShow = Tooltip,
  })
  icon:Register("WhoWearsIt", broker, ns.DB.global.settings.minimap)
  self.icon = icon
end

-- Returns the new "shown" state, or nil when no minimap library is present.
function Minimap:Toggle()
  local settings = ns.DB.global.settings.minimap
  settings.hide = not settings.hide
  if self.icon then
    if settings.hide then self.icon:Hide("WhoWearsIt") else self.icon:Show("WhoWearsIt") end
    return not settings.hide
  end
  return nil
end
