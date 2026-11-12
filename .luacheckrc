std = "lua51"
max_line_length = 130
-- Methods declared with ':' often do not use self; that is fine.
self = false
-- .lua/ and .luarocks/ are created in the workspace by the CI Lua setup actions.
exclude_files = { "Libs/", "tools/", ".github/", ".lua/", ".luarocks/", ".install/" }
-- Locale files are long tables of strings.
files["Locales/"] = { max_line_length = false }
-- Tests run outside the game and set the SavedVariables globals themselves.
files["tests/"] = { globals = { "WhoWearsItDB", "WhoWearsItCharDB" } }

globals = {
  "WhoWearsItDB",
  "WhoWearsItCharDB",
  "SLASH_WHOWEARSIT1",
  "SLASH_WHOWEARSIT2",
  "SlashCmdList",
  "WhoWearsIt_OnCompartmentClick",
  "WhoWearsIt_OnCompartmentEnter",
  "WhoWearsIt_OnCompartmentLeave",
}

read_globals = {
  "C_CreatureInfo",
  "C_Item",
  "C_Timer",
  "C_TransmogCollection",
  "C_TransmogOutfitInfo",
  "CreateDataProvider",
  "CreateFrame",
  "CreateScrollBoxListLinearView",
  "DEFAULT_CHAT_FRAME",
  "Enum",
  "GameTooltip",
  "GetBuildInfo",
  "GetCursorPosition",
  "GetLocale",
  "GetRealmName",
  "GetTime",
  "ITEM_QUALITY_COLORS",
  "LibStub",
  "RAID_CLASS_COLORS",
  "ScrollBoxConstants",
  "ScrollUtil",
  "SearchBoxTemplate_OnTextChanged",
  "UIParent",
  "UISpecialFrames",
  "UnitClass",
  "UnitFactionGroup",
  "UnitFullName",
  "UnitLevel",
  "time",
  "tinsert",
  "wipe",
}
