local _, ns = ...
-- Wrapper around C_TransmogCollection: caches in memory only, builds rows in small batches.

local Collection = {}
ns.Collection = Collection

-- "filter": scan every class with SetClassFilter (needs self-test C to pass).
-- "harvest": each character stores what its own class sees at login (plan B).
Collection.strategy = "filter"
Collection.BATCH = 50

-- Armor slots get the Cloth/Leather/Mail/Plate tabs; Back, Shirt and Tabard do not.
Collection.CATEGORIES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
Collection.ARMOR_SLOTS = { [1] = true, [2] = true, [4] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true }

local cache = {}      -- cache[category] = { rows = {}, byVisual = {}, done = bool, classesScanned = {} }
local pendingItems = {} -- itemID -> { row, ... }
local paused = false
local queue = {}

-- Calls _G[namespace][fname](...) only if it exists.
function Collection.Api(namespace, fname, ...)
  local t = _G[namespace]
  local fn = t and t[fname]
  if type(fn) ~= "function" then return nil, "missing-api" end
  return fn(...)
end
local Api = Collection.Api

-- Runs fn with the collection filters set for our scan and always restores the player's filters.
-- The save, the Set calls and the restore all live in the same pcall block.
function Collection.WithFilters(classID, fn)
  local okOuter, result = pcall(function()
    local C = C_TransmogCollection
    local origClass = C.GetClassFilter()
    local origUncollected = C.GetUncollectedShown and C.GetUncollectedShown()
    local origCollected = C.GetCollectedShown and C.GetCollectedShown()
    if C.SetUncollectedShown then C.SetUncollectedShown(true) end
    if C.SetCollectedShown then C.SetCollectedShown(true) end
    if classID then C.SetClassFilter(classID) end
    local okInner, value = pcall(fn)
    C.SetClassFilter(origClass)
    if C.SetUncollectedShown and origUncollected ~= nil then C.SetUncollectedShown(origUncollected) end
    if C.SetCollectedShown and origCollected ~= nil then C.SetCollectedShown(origCollected) end
    if not okInner then error(value, 0) end
    return value
  end)
  if not okOuter then return nil, result end
  return result
end

-- classID -> classFile for every class this client knows.
function Collection.ClassList()
  local list = {}
  for classID = 1, 20 do
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo and C_CreatureInfo.GetClassInfo(classID)
    if info and info.classFile then
      list[#list + 1] = { classID = classID, classFile = info.classFile }
    end
  end
  return list
end

local function NewRow(info, category)
  return { visualID = info.visualID, collected = info.isCollected, category = category, classes = {} }
end

local function FillItem(row)
  local sources = Api("C_TransmogCollection", "GetAppearanceSources", row.visualID, row.category)
  local src = type(sources) == "table" and sources[1]
  if not src then return end
  row.sourceID, row.itemID, row.name, row.quality = src.sourceID, src.itemID, src.name, src.quality
  for _, s in ipairs(sources) do
    if s.isCollected then row.collected = true end
  end
  if row.itemID and C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, _, icon, classID, subClassID = C_Item.GetItemInfoInstant(row.itemID)
    row.icon = icon
    if classID == 4 then row.armor = ns.Rules.ARMOR_SUBCLASS[subClassID] end
  end
  if row.itemID and C_Item and C_Item.GetItemInfo then
    local name, _, quality, _, minLevel = C_Item.GetItemInfo(row.itemID)
    if name then
      row.name, row.quality, row.minLevel = row.name or name, row.quality or quality, minLevel
    else
      pendingItems[row.itemID] = pendingItems[row.itemID] or {}
      table.insert(pendingItems[row.itemID], row)
      if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(row.itemID) end
    end
  end
end

function Collection:OnItemLoaded(itemID, success)
  local rows = pendingItems[itemID]
  if not rows then return end
  pendingItems[itemID] = nil
  if not success then return end
  local name, _, quality, _, minLevel = C_Item.GetItemInfo(itemID)
  for _, row in ipairs(rows) do
    row.name, row.quality, row.minLevel = row.name or name, row.quality or quality, minLevel
  end
  ns:RequestRefresh(false)
end

-- Scans one category for one class (or the current class with classID nil).
local function ScanClass(category, entry, classID, classFile)
  local list, err = Collection.WithFilters(classID, function()
    return C_TransmogCollection.GetCategoryAppearances(category)
  end)
  if type(list) ~= "table" then
    ns:Debug("scan %d/%s failed: %s", category, tostring(classFile), tostring(err))
    return
  end
  for _, info in ipairs(list) do
    local row = entry.byVisual[info.visualID]
    if not row then
      row = NewRow(info, category)
      entry.byVisual[info.visualID] = row
      entry.rows[#entry.rows + 1] = row
    end
    if info.isCollected then row.collected = true end
    if classFile then row.classes[classFile] = true end
  end
  if classFile then entry.classesScanned[classFile] = true end
end

local function Pump()
  if paused or ns.inCombat then paused = true return end
  local job = queue[1]
  if not job then return end
  local entry = cache[job.category]
  if job.phase == "scan" then
    if Collection.strategy == "filter" then
      for _, c in ipairs(Collection.ClassList()) do ScanClass(job.category, entry, c.classID, c.classFile) end
    else
      local _, classFile, classID = UnitClass("player")
      ScanClass(job.category, entry, classID, classFile)
      Collection:ApplyHarvest(job.category, entry)
    end
    job.phase, job.index = "items", 1
  else
    local last = math.min(job.index + Collection.BATCH - 1, #entry.rows)
    for i = job.index, last do FillItem(entry.rows[i]) end
    job.index = last + 1
    if job.index > #entry.rows then
      entry.done = true
      table.remove(queue, 1)
    end
    ns:RequestRefresh(false)
  end
  C_Timer.After(0, Pump)
end

function Collection:Resume()
  if paused then paused = false C_Timer.After(0, Pump) end
end

-- Plan B: remember what this class sees, and merge what other characters saw before.
function Collection:ApplyHarvest(category, entry)
  local store = ns.DB.global and ns.DB.global.harvest
  if not store then return end
  store[category] = store[category] or {}
  local saved = store[category]
  for visualID, row in pairs(entry.byVisual) do
    saved[visualID] = saved[visualID] or {}
    for classFile in pairs(row.classes) do saved[visualID][classFile] = true end
  end
  for visualID, classes in pairs(saved) do
    local row = entry.byVisual[visualID]
    if row then
      for classFile in pairs(classes) do row.classes[classFile] = true; entry.classesScanned[classFile] = true end
    end
  end
end

function Collection:Invalidate()
  wipe(cache)
  wipe(queue)
  wipe(pendingItems)
end

function Collection:Ensure(category)
  if cache[category] then return cache[category] end
  local entry = { rows = {}, byVisual = {}, done = false, classesScanned = {} }
  cache[category] = entry
  queue[#queue + 1] = { category = category, phase = "scan" }
  if #queue == 1 then C_Timer.After(0, Pump) end
  return entry
end

-- Turns a row into the "app" shape Rules.CanWear expects.
function Collection.AppFor(row, entry)
  local app = { armor = row.armor, minLevel = row.minLevel }
  if entry and next(entry.classesScanned) then
    app.classes, app.classesKnown = row.classes, entry.classesScanned
  end
  return app
end

-- Returns rows {visualID, collected, name, itemID, armor, minLevel, classes, quality}, done.
-- opts: { onlyMissing = bool, search = "text", usableBy = rosterKey }
function Collection:GetAppearances(category, armorType, opts)
  opts = opts or {}
  if ns.fakeData then return ns.FakeRows(category, armorType), true end
  if not C_TransmogCollection then return {}, true, "missing-api" end
  local entry = self:Ensure(category)
  local out = {}
  local search = opts.search and opts.search ~= "" and opts.search:lower()
  local char = opts.usableBy and ns.DB:Roster()[opts.usableBy]
  for _, row in ipairs(entry.rows) do
    local keep = true
    if armorType and Collection.ARMOR_SLOTS[category] and row.armor ~= armorType then keep = false end
    if keep and opts.onlyMissing and row.collected then keep = false end
    if keep and search and not (row.name and row.name:lower():find(search, 1, true)) then keep = false end
    if keep and char and not ns.Rules.CanWear(char, Collection.AppFor(row, entry)) then keep = false end
    if keep then out[#out + 1] = row end
  end
  return out, entry.done, nil, entry
end

-- Invented rows for screenshots and for testing the window without data.
function ns.FakeRows(category, armorType)
  local rows = {}
  for i = 1, 30 do
    rows[i] = {
      visualID = 100000 + category * 100 + i, collected = (i % 3 ~= 0), category = category,
      name = ("Sample %d-%d"):format(category, i), quality = (i % 5) + 1,
      armor = Collection.ARMOR_SLOTS[category] and (armorType or "cloth") or nil,
      minLevel = (i * 2) % 60 + 1, classes = {},
    }
  end
  return rows
end
