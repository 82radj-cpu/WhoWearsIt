local _, ns = ...
-- Pure rules engine: no game API in this file, so tests/rules_spec.lua can run it with plain Lua 5.1.

local Rules = {}
ns.Rules = Rules

Rules.MAX_LEVEL = 60

Rules.REASON = {
  ARMOR = "ARMOR",     -- the class never wears this armor type
  LEVEL = "LEVEL",     -- detail = level needed
  CLASS = "CLASS",     -- appearance locked to other classes
  UNKNOWN = "UNKNOWN", -- not enough data to decide
}

-- Armor type -> level at which the class can wear it.
-- HYPOTHESIS (Classic style: mail and plate at 40) until test 12 in the client confirms it.
Rules.ARMOR = {
  WARRIOR     = { cloth = 1, leather = 1, mail = 1, plate = 40 },
  PALADIN     = { cloth = 1, leather = 1, mail = 1, plate = 40 },
  DEATHKNIGHT = { cloth = 1, leather = 1, mail = 1, plate = 1 },
  HUNTER      = { cloth = 1, leather = 1, mail = 40 },
  SHAMAN      = { cloth = 1, leather = 1, mail = 40 },
  EVOKER      = { cloth = 1, leather = 1, mail = 1 },
  ROGUE       = { cloth = 1, leather = 1 },
  DRUID       = { cloth = 1, leather = 1 },
  MONK        = { cloth = 1, leather = 1 },
  DEMONHUNTER = { cloth = 1, leather = 1 },
  MAGE        = { cloth = 1 },
  PRIEST      = { cloth = 1 },
  WARLOCK     = { cloth = 1 },
}

-- Item subclass (armor class 4) -> our armor key.
Rules.ARMOR_SUBCLASS = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate" }
Rules.ARMOR_ORDER = { "cloth", "leather", "mail", "plate" }

-- char: { classFile, level }
-- app:  { armor = "cloth"|"leather"|"mail"|"plate"|nil, minLevel = n|nil,
--         classes = {CLASSFILE = true}|nil, classesKnown = {CLASSFILE = true}|nil }
-- Returns true, or false, reason, detail.
function Rules.CanWear(char, app)
  local R = Rules.REASON
  if type(char) ~= "table" or type(app) ~= "table" or not char.classFile then
    return false, R.UNKNOWN
  end
  local level = tonumber(char.level) or 1

  if app.armor then
    local allowed = Rules.ARMOR[char.classFile]
    if not allowed then return false, R.UNKNOWN end
    local need = allowed[app.armor]
    if not need then return false, R.ARMOR, app.armor end
    if level < need then return false, R.LEVEL, need end
  end

  -- classes = classes whose collection lists this appearance; classesKnown = classes already scanned.
  if app.classes and not app.classes[char.classFile] then
    if app.classesKnown and not app.classesKnown[char.classFile] then return false, R.UNKNOWN end
    return false, R.CLASS
  end

  local minLevel = tonumber(app.minLevel)
  if minLevel and level < Rules.MAX_LEVEL and level < minLevel then
    return false, R.LEVEL, minLevel
  end

  return true
end

-- Every character in roster that passes CanWear, and the failures with their reasons.
function Rules.WhoCanWear(roster, app)
  local yes, no = {}, {}
  for key, char in pairs(roster or {}) do
    local ok, reason, detail = Rules.CanWear(char, app)
    if ok then
      yes[#yes + 1] = key
    else
      no[#no + 1] = { key = key, reason = reason, detail = detail }
    end
  end
  table.sort(yes)
  table.sort(no, function(a, b) return a.key < b.key end)
  return yes, no
end
