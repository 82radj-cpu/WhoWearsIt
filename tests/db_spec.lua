-- Run from the addon folder: lua tests/db_spec.lua   (plain Lua 5.1, no game needed)
local ns = {}
assert(loadfile("DB.lua"))("WhoWearsIt", ns)
local DB = ns.DB

local failed = 0
local function check(cond, msg) if not cond then failed = failed + 1; print("FAIL " .. msg) end end

-- Existing saved data must survive Init.
WhoWearsItDB = {
  schema = 1,
  roster = { ["Realm-Old"] = { name = "Old", level = 12 } },
  settings = { debug = true, minimap = { hide = true } },
}
WhoWearsItCharDB = { lastCategory = 10 }
DB:Init()
check(WhoWearsItDB.roster["Realm-Old"].level == 12, "roster entry kept")
check(WhoWearsItDB.settings.debug == true, "debug setting kept")
check(WhoWearsItDB.settings.minimap.hide == true, "nested minimap.hide kept")
check(WhoWearsItDB.settings.onlyMissing == true, "missing default added")
check(type(WhoWearsItDB.looks) == "table", "looks table created")
check(WhoWearsItCharDB.lastCategory == 10, "char lastCategory kept")
check(WhoWearsItCharDB.schema == DB.SCHEMA, "char schema set")

-- Fresh install.
WhoWearsItDB, WhoWearsItCharDB = nil, nil
DB:Init()
check(WhoWearsItDB.schema == DB.SCHEMA and next(WhoWearsItDB.roster) == nil, "fresh defaults")
check(WhoWearsItDB.settings ~= DB.defaults.settings, "defaults are copied, not shared")

-- Forget.
WhoWearsItDB.roster["R-X"] = { name = "X" }
check(DB:Forget("R-X") == true and WhoWearsItDB.roster["R-X"] == nil, "forget removes")
check(DB:Forget("R-X") == false, "forget twice is false")

print(("db_spec: %s"):format(failed == 0 and "all passed" or (failed .. " failed")))
if failed > 0 then os.exit(1) end
