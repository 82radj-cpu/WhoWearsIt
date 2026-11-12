local _, ns = ...
local L = ns.L

local commands = {}
local forgetPending = {}  -- lower-case name -> expiry time

local function OnOff(value) return value and L["on"] or L["off"] end

function commands.help()
  ns:Print(L["Commands:"])
  for _, line in ipairs({
    "/wwi - open or close the window",
    "/wwi missing - open showing only missing appearances",
    "/wwi roster - list your recorded characters",
    "/wwi forget <name> - remove a character from the roster",
    "/wwi minimap - show or hide the minimap button",
    "/wwi selftest - run the diagnostics and save them",
    "/wwi debug - toggle debug messages",
    "/wwi help - this list",
  }) do
    DEFAULT_CHAT_FRAME:AddMessage("  " .. L[line])
  end
end

commands[""] = function() ns.UI:Toggle() end
commands.missing = function() ns.UI:Toggle(true) end

function commands.roster()
  ns:Print(L["Recorded characters:"])
  local keys = {}
  for key in pairs(ns.DB:Roster()) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local c = ns.DB:Roster()[key]
    DEFAULT_CHAT_FRAME:AddMessage(("  %s - %s %s"):format(key, tostring(c.level), tostring(c.classFile)))
  end
end

function commands.forget(arg)
  local wanted = (arg or ""):lower()
  local found
  for key, c in pairs(ns.DB:Roster()) do
    if (c.name or ""):lower() == wanted or key:lower() == wanted then found = key end
  end
  if not found then ns:Print(L["No character named %s."], arg or "") return end
  local now = GetTime()
  if forgetPending[wanted] and forgetPending[wanted] > now then
    forgetPending[wanted] = nil
    ns.DB:Forget(found)
    ns:Print(L["Removed %s."], found)
  else
    forgetPending[wanted] = now + 10
    ns:Print(L["Type /wwi forget %s again within 10 seconds to confirm."], arg)
  end
end

function commands.minimap()
  local shown = ns.Minimap:Toggle()
  if shown == nil then shown = not ns.DB.global.settings.minimap.hide end
  ns:Print(L["Minimap button: %s"], OnOff(shown))
end

function commands.selftest() ns.SelfTest:Run() end

function commands.debug()
  local value = not ns.DB:Setting("debug")
  ns.DB:SetSetting("debug", value)
  ns:Print(L["Debug: %s"], OnOff(value))
end

-- Hidden helper for screenshots: /wwi fake
function commands.fake()
  ns.fakeData = not ns.fakeData
  ns:Print(L["Fake data mode: %s"], OnOff(ns.fakeData))
  if ns.UI.frame then ns.UI:Refresh() end
end

SLASH_WHOWEARSIT1 = "/wwi"
SLASH_WHOWEARSIT2 = "/whowears"
SlashCmdList.WHOWEARSIT = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  local handler = commands[cmd] or commands.help
  handler(rest)
end

ns.commands = commands
