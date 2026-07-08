local addonName, addon = ...
addon.SCHEMA_VERSION = 2

local function sourceKeys(db)
  if db.__sourceKeys then return db.__sourceKeys end
  local keys = {}
  for k in pairs(addon.ITEM_SOURCES or {}) do keys[#keys + 1] = k end
  return keys
end

local function migrateSourceScope(skipInto, oldInclude, gate, keys)
  if not gate then
    for k in pairs(skipInto) do skipInto[k] = nil end
    return
  end
  for _, k in ipairs(keys) do
    skipInto[k] = (oldInclude[k] ~= true) and true or nil
  end
end

function addon.MigrateDB(db)
  if not db then return db end
  if db.settingsSchemaVersion == addon.SCHEMA_VERSION then return db end

  if db.sellMode == nil then
    db.sellMode = (db.expansionSellAllMode == false) and "matching" or "everything"
  end

  local keys = sourceKeys(db)
  db.itemSources = db.itemSources or {}
  migrateSourceScope(db.itemSources, db.itemSources, db.filterBySource, keys)

  for _, profile in pairs(db.expansionProfiles or {}) do
    profile.itemSources = profile.itemSources or {}
    migrateSourceScope(profile.itemSources, profile.itemSources, profile.filterBySource, keys)
  end

  db.settingsSchemaVersion = addon.SCHEMA_VERSION
  return db
end
