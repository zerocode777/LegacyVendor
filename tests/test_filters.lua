local T = _G.__LV_TEST
T.test("harness runs", function() T.eq(1 + 1, 2) end)

local _, addon = _G.__LV_ARGS()
assert(loadfile("Filters.lua"))(_G.__LV_ARGS())  -- load module into addon

T.test("migrate sets schema + mode from sellAll true", function()
  local db = { expansionSellAllMode = true, itemSources = {}, expansionProfiles = {} }
  addon.MigrateDB(db)
  T.eq(db.settingsSchemaVersion, addon.SCHEMA_VERSION)
  T.eq(db.sellMode, "everything")
end)

T.test("migrate maps sellAll false to matching", function()
  local db = { expansionSellAllMode = false, itemSources = {}, expansionProfiles = {} }
  addon.MigrateDB(db)
  T.eq(db.sellMode, "matching")
end)

T.test("source skip empty when gate off", function()
  local db = { filterBySource = false, itemSources = { dungeon = true }, expansionProfiles = {} }
  addon.MigrateDB(db)
  T.eq(db.itemSources.dungeon, nil)  -- nothing skipped
end)

T.test("source skip preserves include-list when gate on", function()
  local db = {
    filterBySource = true,
    itemSources = { dungeon = true, consumable = false },
    expansionProfiles = {},
    __sourceKeys = { "dungeon", "consumable", "raid" },
  }
  addon.MigrateDB(db)
  -- old: sold only dungeon. new skip-list: skip everything except dungeon.
  T.eq(db.itemSources.dungeon, nil)   -- not skipped
  T.eq(db.itemSources.consumable, true) -- skipped
  T.eq(db.itemSources.raid, true)       -- skipped
end)

T.test("migrate is idempotent", function()
  local db = { expansionSellAllMode = true, itemSources = {}, expansionProfiles = {} }
  addon.MigrateDB(db); local mode = db.sellMode
  db.sellMode = "matching"          -- simulate user change
  addon.MigrateDB(db)               -- must not re-derive
  T.eq(db.sellMode, "matching")
end)
