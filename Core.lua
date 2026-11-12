local ADDON, ns = ...

ns.ADDON = ADDON
ns.events = {}       -- [EVENT] = function(...)
ns.inCombat = false
ns.fakeData = false  -- true = UI shows invented rows (for screenshots)

local PREFIX = "|cff66ccffWho Wears It|r: "

function ns:Print(fmt, ...)
  local msg = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

function ns:Debug(fmt, ...)
  if ns.DB and ns.DB:Setting("debug") then
    ns:Print("|cff999999" .. (select("#", ...) > 0 and fmt:format(...) or fmt) .. "|r")
  end
end

-- Calls fn only if it exists. Returns nil, "missing-api" instead of erroring.
function ns.SafeCall(fn, ...)
  if type(fn) ~= "function" then return nil, "missing-api" end
  return fn(...)
end

-- Throttled refresh: at most one call every 0.5 s. invalidate = drop the cache first.
local refreshPending, invalidatePending = false, false
function ns:RequestRefresh(invalidate)
  if invalidate then invalidatePending = true end
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(0.5, function()
    refreshPending = false
    if invalidatePending and ns.Collection then ns.Collection:Invalidate() end
    invalidatePending = false
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
  end)
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame

local function OnEvent(_, event, ...)
  local handler = ns.events[event]
  if handler then handler(...) end
end
frame:SetScript("OnEvent", OnEvent)

ns.events.ADDON_LOADED = function(name)
  if name ~= ADDON then return end
  ns.DB:Init()
  frame:UnregisterEvent("ADDON_LOADED")
  ns:Debug("ADDON_LOADED")
end

ns.events.PLAYER_LOGIN = function()
  ns.DB:TouchCharacter()
  if ns.Minimap then ns.Minimap:Init() end
  ns:Debug("PLAYER_LOGIN")
end

ns.events.PLAYER_LEVEL_UP = function(level)
  ns.DB:TouchCharacter(tonumber(level))
  ns:Debug("PLAYER_LEVEL_UP %s", tostring(level))
end

local function CollectionChanged() ns:RequestRefresh(true) end
ns.events.TRANSMOG_COLLECTION_UPDATED = CollectionChanged
ns.events.TRANSMOG_COLLECTION_SOURCE_ADDED = CollectionChanged
ns.events.TRANSMOG_COLLECTION_SOURCE_REMOVED = CollectionChanged
ns.events.TRANSMOG_SOURCE_COLLECTABILITY_UPDATE = CollectionChanged

ns.events.ITEM_DATA_LOAD_RESULT = function(itemID, success)
  if ns.Collection then ns.Collection:OnItemLoaded(itemID, success) end
end

ns.events.PLAYER_REGEN_DISABLED = function()
  ns.inCombat = true
  ns:Debug("combat: scans paused")
end

ns.events.PLAYER_REGEN_ENABLED = function()
  ns.inCombat = false
  if ns.Collection then ns.Collection:Resume() end
  ns:Debug("combat over: scans resumed")
end

ns.events.TRANSMOG_OUTFITS_CHANGED = function(newOutfitID)
  ns:Debug("TRANSMOG_OUTFITS_CHANGED %s (0.2)", tostring(newOutfitID))
end

-- The event frame is the only thing created at load time (it must exist to see ADDON_LOADED).
-- pcall: an event missing from this client build must not stop the addon from loading.
ns.unknownEvents = {}
for event in pairs(ns.events) do
  if not pcall(frame.RegisterEvent, frame, event) then
    ns.unknownEvents[#ns.unknownEvents + 1] = event
  end
end
