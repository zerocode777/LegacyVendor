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

local SOURCE_LABELS = {
  consumable = "Consumables", dungeon = "Dungeons", raid = "Raids", outdoor = "World",
  profession = "Professions", vendor = "Vendor", pvp = "PvP", reputation = "Reputation",
  housing = "Housing", unknown = "Other",
}

local function expName(db, id)
  if db.__names then return db.__names.exp[id] end
  local e = addon.EXPANSIONS and addon.EXPANSIONS[id]
  return e and (e.short or e.name) or ("Exp " .. id)
end

local function rarName(db, id)
  if db.__names then return db.__names.rar[id] end
  local r = addon.RARITIES and addon.RARITIES[id]
  return r and r.name or tostring(id)
end

local function enabledExpansionNames(db)
  local names = {}
  for id, on in pairs(db.expansions or {}) do
    if on then names[#names + 1] = { id = id, name = expName(db, id) } end
  end
  table.sort(names, function(a, b) return a.id < b.id end)
  local out = {}
  for _, n in ipairs(names) do out[#out + 1] = n.name end
  return out
end

local function joinList(t)
  if #t == 0 then return "" end
  if #t == 1 then return t[1] end
  if #t == 2 then return t[1] .. " & " .. t[2] end
  return table.concat(t, ", ", 1, #t - 1) .. " & " .. t[#t]
end

function addon.BuildActiveSummary(db)
  local mode = db.sellMode or "everything"
  local exps = enabledExpansionNames(db)
  if #exps == 0 then
    return { mode = mode, chips = {}, headline = "Nothing will sell — no expansions enabled." }
  end
  local expText = joinList(exps)

  if mode == "everything" then
    return { mode = mode, chips = {}, headline = "Selling everything from " .. expText .. "." }
  end

  local resolved = addon.ResolveActiveFilters(db, db.selectedExpansionProfileID or 0)

  local rarNames = {}
  for id = 0, 7 do if resolved.rarities[id] then rarNames[#rarNames + 1] = rarName(db, id) end end
  local rarText = (#rarNames > 0) and joinList(rarNames) or "all"

  local skipped = {}
  for k, v in pairs(resolved.itemSources) do if v == true then skipped[#skipped + 1] = SOURCE_LABELS[k] or k end end
  table.sort(skipped)
  local skipNote = (#skipped > 0) and (" (skipping " .. joinList(skipped) .. ")") or ""

  local chips = {
    "Rarity: " .. rarText,
    "Source: " .. ((#skipped > 0) and ("skip " .. joinList(skipped)) or "all"),
    "Expansions: " .. expText,
  }
  return { mode = mode, chips = chips, headline = "Selling " .. rarText .. " gear from " .. expText .. skipNote .. "." }
end
