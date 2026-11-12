local _, ns = ...
-- Meta outfits ("looks"). Pure on top of a looks list, so tests can pass their own tables.
-- look = { id, name, slots = { [category] = visualID }, created }

local Looks = {}
ns.Looks = Looks

local function List(store)
  if store then return store end
  return ns.DB.global and ns.DB.global.looks or {}
end

local function Find(list, id)
  for i, look in ipairs(list) do
    if look.id == id then return look, i end
  end
end

function Looks.Create(name, store, now)
  local list = List(store)
  local nextID = 1
  for _, look in ipairs(list) do
    if look.id >= nextID then nextID = look.id + 1 end
  end
  local look = { id = nextID, name = name, slots = {}, created = now or (time and time()) or 0 }
  list[#list + 1] = look
  return look
end

function Looks.Rename(id, name, store)
  local look = Find(List(store), id)
  if look then look.name = name end
  return look ~= nil
end

function Looks.Delete(id, store)
  local list = List(store)
  local _, index = Find(list, id)
  if index then table.remove(list, index) end
  return index ~= nil
end

-- visualID nil clears the slot.
function Looks.Assign(id, category, visualID, store)
  local look = Find(List(store), id)
  if not look then return false end
  look.slots[category] = visualID
  return true
end

-- isCollected(visualID) -> bool. Returns collected, assigned.
function Looks.Progress(look, isCollected)
  local have, total = 0, 0
  for _, visualID in pairs(look.slots) do
    total = total + 1
    if isCollected(visualID) then have = have + 1 end
  end
  return have, total
end

-- appFor(category, visualID) -> app for Rules.CanWear. Returns roster keys that can wear every piece.
function Looks.WhoCanWear(look, roster, appFor)
  local who = {}
  for key, char in pairs(roster) do
    local ok = true
    for category, visualID in pairs(look.slots) do
      if not ns.Rules.CanWear(char, appFor(category, visualID)) then ok = false break end
    end
    if ok then who[#who + 1] = key end
  end
  table.sort(who)
  return who
end

Looks.Find = function(id, store) return Find(List(store), id) end
