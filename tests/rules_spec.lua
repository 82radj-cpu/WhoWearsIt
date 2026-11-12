-- Run from the addon folder: lua tests/rules_spec.lua   (plain Lua 5.1, no game needed)
local ns = {}
assert(loadfile("Rules.lua"))("WhoWearsIt", ns)
assert(loadfile("Looks.lua"))("WhoWearsIt", ns)
local Rules, Looks, R = ns.Rules, ns.Looks, ns.Rules.REASON

local passed, failed = 0, 0
local function case(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function eq(a, b) if a ~= b then error(("expected %s, got %s"):format(tostring(b), tostring(a)), 2) end end

local mage = { classFile = "MAGE", level = 60 }
local warrior30 = { classFile = "WARRIOR", level = 30 }
local warrior60 = { classFile = "WARRIOR", level = 60 }
local hunter20 = { classFile = "HUNTER", level = 20 }
local dk = { classFile = "DEATHKNIGHT", level = 55 }

case("1 mage wears cloth", function() eq(Rules.CanWear(mage, { armor = "cloth" }), true) end)
case("2 mage never wears plate", function()
  local ok, reason, detail = Rules.CanWear(mage, { armor = "plate" })
  eq(ok, false); eq(reason, R.ARMOR); eq(detail, "plate")
end)
case("3 warrior 30 cannot wear plate yet", function()
  local ok, reason, detail = Rules.CanWear(warrior30, { armor = "plate" })
  eq(ok, false); eq(reason, R.LEVEL); eq(detail, 40)
end)
case("4 warrior 60 wears plate", function() eq(Rules.CanWear(warrior60, { armor = "plate" }), true) end)
case("5 hunter 20 mail locked until 40", function()
  local _, reason, detail = Rules.CanWear(hunter20, { armor = "mail" })
  eq(reason, R.LEVEL); eq(detail, 40)
end)
case("6 death knight plate from level 1", function() eq(Rules.CanWear(dk, { armor = "plate" }), true) end)
case("7 cloak without armor type is fine", function() eq(Rules.CanWear(mage, { armor = nil }), true) end)
case("8 item level requirement under 60", function()
  local _, reason, detail = Rules.CanWear(warrior30, { armor = "cloth", minLevel = 45 })
  eq(reason, R.LEVEL); eq(detail, 45)
end)
case("9 level 60 ignores item level", function()
  eq(Rules.CanWear(warrior60, { armor = "cloth", minLevel = 70 }), true)
end)
case("10 unknown class", function()
  local ok, reason = Rules.CanWear({ classFile = "BARD", level = 10 }, { armor = "cloth" })
  eq(ok, false); eq(reason, R.UNKNOWN)
end)
case("11 missing classFile", function()
  local _, reason = Rules.CanWear({ level = 10 }, { armor = "cloth" }); eq(reason, R.UNKNOWN)
end)
case("12 class-locked appearance", function()
  local app = { armor = "cloth", classes = { PRIEST = true }, classesKnown = { PRIEST = true, MAGE = true } }
  local _, reason = Rules.CanWear(mage, app); eq(reason, R.CLASS)
end)
case("13 class not scanned yet is unknown, not class", function()
  local app = { armor = "cloth", classes = { PRIEST = true }, classesKnown = { PRIEST = true } }
  local _, reason = Rules.CanWear(mage, app); eq(reason, R.UNKNOWN)
end)
case("14 armor reason wins over class reason", function()
  local app = { armor = "plate", classes = { WARRIOR = true }, classesKnown = { WARRIOR = true, MAGE = true } }
  local _, reason = Rules.CanWear(mage, app); eq(reason, R.ARMOR)
end)
case("15 WhoCanWear splits yes and no", function()
  local yes, no = Rules.WhoCanWear({ a = mage, b = warrior60 }, { armor = "plate" })
  eq(#yes, 1); eq(yes[1], "b"); eq(#no, 1); eq(no[1].reason, R.ARMOR)
end)

-- Looks (fake data)
case("16 look progress", function()
  local store = {}
  local look = Looks.Create("Test", store, 0)
  Looks.Assign(look.id, 1, 11, store); Looks.Assign(look.id, 4, 44, store); Looks.Assign(look.id, 10, 100, store)
  local have, total = Looks.Progress(look, function(v) return v ~= 100 end)
  eq(have, 2); eq(total, 3)
end)
case("17 look WhoCanWear", function()
  local store = {}
  local look = Looks.Create("Plate set", store, 0)
  Looks.Assign(look.id, 4, 44, store)
  local who = Looks.WhoCanWear(look, { m = mage, w = warrior60 }, function() return { armor = "plate" } end)
  eq(#who, 1); eq(who[1], "w")
end)
case("18 look rename and delete", function()
  local store = {}
  local a = Looks.Create("A", store, 0); local b = Looks.Create("B", store, 0)
  eq(b.id, a.id + 1)
  eq(Looks.Rename(a.id, "A2", store), true); eq(store[1].name, "A2")
  eq(Looks.Delete(a.id, store), true); eq(#store, 1); eq(Looks.Delete(999, store), false)
end)

print(("rules_spec: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
