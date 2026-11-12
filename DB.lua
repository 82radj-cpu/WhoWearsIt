local _, ns = ...

local DB = {}
ns.DB = DB

DB.SCHEMA = 1

DB.defaults = {
  schema = DB.SCHEMA,
  roster = {},
  looks = {},
  settings = { minimap = { hide = false }, onlyMissing = true, debug = false },
  harvest = {},
}

DB.charDefaults = {
  schema = DB.SCHEMA,
  lastCategory = 4,
}

-- Copies defaults into dst without overwriting anything that already exists.
function DB.MergeDefaults(dst, defaults)
  for k, v in pairs(defaults) do
    if dst[k] == nil then
      if type(v) == "table" then
        dst[k] = DB.MergeDefaults({}, v)
      else
        dst[k] = v
      end
    elseif type(v) == "table" and type(dst[k]) == "table" then
      DB.MergeDefaults(dst[k], v)
    end
  end
  return dst
end

-- Schema migrations: migrations[n] upgrades a table from schema n-1 to n.
DB.migrations = {
  -- [2] = function(db) ... end,
}

function DB.Migrate(db)
  local from = tonumber(db.schema) or 1
  for n = from + 1, DB.SCHEMA do
    if DB.migrations[n] then DB.migrations[n](db) end
  end
  db.schema = DB.SCHEMA
  return db
end

-- Called from ADDON_LOADED only (SavedVariables are not ready before that).
function DB:Init()
  if type(WhoWearsItDB) ~= "table" then WhoWearsItDB = {} end
  if type(WhoWearsItCharDB) ~= "table" then WhoWearsItCharDB = {} end
  DB.Migrate(DB.MergeDefaults(WhoWearsItDB, DB.defaults))
  DB.Migrate(DB.MergeDefaults(WhoWearsItCharDB, DB.charDefaults))
  self.global = WhoWearsItDB
  self.char = WhoWearsItCharDB
end

function DB:Setting(key)
  return self.global and self.global.settings[key]
end

function DB:SetSetting(key, value)
  if self.global then self.global.settings[key] = value end
end

function DB.RosterKey(realm, name)
  return (realm or "?") .. "-" .. (name or "?")
end

-- Records the logged-in character in the account roster (own characters only).
function DB:TouchCharacter(level)
  if not self.global then return end
  local name, realm = UnitFullName("player")
  realm = realm or GetRealmName()
  local _, classFile, classID = UnitClass("player")
  local key = DB.RosterKey(realm, name)
  local entry = self.global.roster[key] or {}
  entry.name = name
  entry.realm = realm
  entry.classFile = classFile
  entry.classID = classID
  entry.level = level or UnitLevel("player")
  entry.faction = UnitFactionGroup("player")
  entry.lastSeen = time()
  self.global.roster[key] = entry
  self.currentKey = key
  return key
end

function DB:Roster()
  return self.global and self.global.roster or {}
end

function DB:Forget(key)
  if self.global and self.global.roster[key] then
    self.global.roster[key] = nil
    return true
  end
  return false
end
