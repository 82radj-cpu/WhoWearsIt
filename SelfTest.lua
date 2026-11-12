local _, ns = ...
local L = ns.L

local SelfTest = {}
ns.SelfTest = SelfTest

local CHEST = 4
local tests = {}
local function Add(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

-- Each fn returns ok (bool), detail (string).
Add("build", function()
  local version, build, _, interface = GetBuildInfo()
  return true, ("%s (%s) interface %s locale %s"):format(version, build, tostring(interface), GetLocale())
end)

Add("events", function()
  if #ns.unknownEvents == 0 then return true, "all registered" end
  return false, "unknown: " .. table.concat(ns.unknownEvents, ", ")
end)

Add("A api-namespaces", function()
  local missing = {}
  for _, n in ipairs({ "C_TransmogCollection", "C_TransmogSets", "C_TransmogOutfitInfo", "C_Transmog" }) do
    if not _G[n] then missing[#missing + 1] = n end
  end
  return #missing == 0, #missing == 0 and "4 present" or ("missing " .. table.concat(missing, ","))
end)

Add("B chest-appearances", function()
  local list = C_TransmogCollection.GetCategoryAppearances(CHEST) or {}
  local have = 0
  for _, v in ipairs(list) do if v.isCollected then have = have + 1 end end
  return #list > 0, ("chest %d collected %d"):format(#list, have)
end)

Add("C class-filter", function()
  local counts, distinct, seen = {}, 0, {}
  for _, c in ipairs(ns.Collection.ClassList()) do
    local list = ns.Collection.WithFilters(c.classID, function()
      return C_TransmogCollection.GetCategoryAppearances(CHEST)
    end)
    local n = type(list) == "table" and #list or -1
    counts[#counts + 1] = c.classFile .. "=" .. n
    if not seen[n] then seen[n] = true; distinct = distinct + 1 end
  end
  return distinct > 1, table.concat(counts, " ")
end)

Add("E uncollected-shown", function()
  -- Forever's own UI hides uncollected appearances; check that the API still lists them.
  local C = C_TransmogCollection
  local orig = C.GetUncollectedShown()
  local okSet, result = pcall(function()
    C.SetUncollectedShown(false)
    local hidden = #(C.GetCategoryAppearances(CHEST) or {})
    C.SetUncollectedShown(true)
    local shown, missing = 0, 0
    for _, v in ipairs(C.GetCategoryAppearances(CHEST) or {}) do
      shown = shown + 1
      if not v.isCollected then missing = missing + 1 end
    end
    return { hidden = hidden, shown = shown, missing = missing }
  end)
  C.SetUncollectedShown(orig)
  if not okSet then error(result, 0) end
  return result.missing > 0, ("flag-off %d flag-on %d uncollected %d (original %s)")
    :format(result.hidden, result.shown, result.missing, tostring(orig))
end)

Add("D dressup-model", function()
  local m = CreateFrame("DressUpModel", nil, UIParent)
  m:SetSize(10, 10)
  m:SetUnit("player")
  local ok = type(m.TryOn) == "function"
  m:Hide()
  return ok, ok and "TryOn present" or "no TryOn"
end)

Add("sources-and-item", function()
  local list = C_TransmogCollection.GetCategoryAppearances(CHEST) or {}
  local first = list[1]
  if not first then return false, "no appearances" end
  local sources = C_TransmogCollection.GetAppearanceSources(first.visualID, CHEST) or {}
  local src = sources[1]
  if not src then return false, "no sources for " .. first.visualID end
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(src.itemID)
  return true, ("visual %d item %s class %s/%s"):format(first.visualID, tostring(src.itemID),
    tostring(classID), tostring(subClassID))
end)

Add("valid-sources-for-class", function()
  local list = C_TransmogCollection.GetCategoryAppearances(CHEST) or {}
  local first = list[1]
  if not first then return false, "no appearances" end
  local _, _, classID = UnitClass("player")
  local valid = C_TransmogCollection.GetValidAppearanceSourcesForClass(first.visualID, classID, CHEST)
  return type(valid) == "table", "returned " .. (type(valid) == "table" and #valid or type(valid))
end)

Add("outfits-info", function()
  local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
  return type(outfits) == "table", "outfits " .. (type(outfits) == "table" and #outfits or type(outfits))
end)

Add("scrollbox", function()
  local ok = type(CreateScrollBoxListLinearView) == "function" and type(ScrollUtil) == "table"
    and type(CreateDataProvider) == "function"
  return ok, ok and "present" or "missing ScrollBox helpers"
end)

Add("saved-variables", function()
  local roster = WhoWearsItDB and WhoWearsItDB.roster or {}
  local n = 0
  for _ in pairs(roster) do n = n + 1 end
  return n > 0, ("roster %d, previous selftest %s"):format(n, WhoWearsItDB.selftestAt and "yes" or "no")
end)

Add("armor-skills", function()
  -- What this character really wears, to confirm Rules.ARMOR (test 12).
  local _, classFile = UnitClass("player")
  local guess = ns.Rules.ARMOR[classFile] or {}
  local parts = {}
  for _, armor in ipairs(ns.Rules.ARMOR_ORDER) do parts[#parts + 1] = armor .. "=" .. tostring(guess[armor]) end
  return true, classFile .. " level " .. UnitLevel("player") .. " guess " .. table.concat(parts, " ")
end)

function SelfTest:Run()
  if ns.inCombat then ns:Print(L["Not in combat. Try again after the fight."]) return end
  local results, pass, fail = {}, 0, 0
  for _, t in ipairs(tests) do
    local okCall, ok, detail = pcall(t.fn)
    if not okCall then ok, detail = false, "error: " .. tostring(ok) end
    ok = ok and true or false
    results[#results + 1] = { name = t.name, ok = ok, detail = tostring(detail or "") }
    if ok then pass = pass + 1 else fail = fail + 1 end
    ns:Print("%s %s - %s", ok and "|cff00ff00OK|r" or "|cffff4040FAIL|r", t.name, tostring(detail or ""))
  end
  WhoWearsItDB.selftest = results
  WhoWearsItDB.selftestAt = time()
  ns:Print(L["Self-test: %d OK, %d FAIL. Saved; /reload writes it to disk."], pass, fail)
  return results
end
