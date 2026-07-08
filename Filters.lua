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
  -- Gate-ON rule: skip every source not explicitly true in the old include-list.
  -- Snapshot decouples read from write so aliasing (skipInto == oldInclude) is safe.
  local snapshot = {}
  for _, k in ipairs(keys) do snapshot[k] = oldInclude[k] end
  for k in pairs(skipInto) do skipInto[k] = nil end
  for _, k in ipairs(keys) do
    skipInto[k] = (snapshot[k] ~= true) and true or nil
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

function addon.SourceSkipped(skipSet, source)
  if not source or not skipSet then return false end
  return skipSet[source] == true
end

function addon.ResolveActiveFilters(db, expansionID)
  local mode = db.sellMode or "everything"
  local profile = db.expansionProfiles and db.expansionProfiles[expansionID]
  local useOverride = (mode == "matching") and profile and profile.useDetailedFilters == true

  if useOverride then
    return {
      mode = mode, usedOverride = true,
      rarities = profile.rarities or {},
      equipSlots = profile.equipSlots or {},
      itemTypes = profile.itemTypes or {},
      bindTypes = profile.bindTypes or {},
      itemSources = profile.itemSources or {},
      onlyLowerIlvl = profile.onlySellLowerIlvl == true,
    }
  end

  return {
    mode = mode, usedOverride = false,
    rarities = db.rarities or {},
    equipSlots = db.equipSlots or {},
    itemTypes = db.itemTypes or {},
    bindTypes = { bop = db.sellBoP, boe = db.sellBoE, unbound = db.sellUnbound },
    itemSources = db.itemSources or {},
    onlyLowerIlvl = db.onlySellLowerIlvl == true,
  }
end
