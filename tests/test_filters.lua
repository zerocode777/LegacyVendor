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

T.test("nil sellMode maps to everything", function()
  local db = { itemSources = {}, expansionProfiles = {} }
  -- expansionSellAllMode is intentionally absent (nil)
  addon.MigrateDB(db)
  T.eq(db.sellMode, "everything")
end)

T.test("idempotent second pass leaves sources and version intact", function()
  local db = {
    filterBySource = true,
    itemSources = { dungeon = true, raid = false },
    expansionProfiles = {},
    __sourceKeys = { "dungeon", "raid" },
  }
  addon.MigrateDB(db)
  -- After first pass: dungeon is kept (nil in skip-set), raid is skipped (true)
  local src_dungeon = db.itemSources.dungeon
  local src_raid    = db.itemSources.raid
  local ver         = db.settingsSchemaVersion
  -- Second pass must not re-process an already-converted skip-list
  addon.MigrateDB(db)
  T.eq(db.settingsSchemaVersion, ver)
  T.eq(db.itemSources.dungeon, src_dungeon)
  T.eq(db.itemSources.raid, src_raid)
end)

T.test("SourceSkipped basic", function()
  T.eq(addon.SourceSkipped({ consumable = true }, "consumable"), true)
  T.eq(addon.SourceSkipped({ consumable = true }, "dungeon"), false)
  T.eq(addon.SourceSkipped({}, nil), false)
end)

T.test("resolve uses global set by default", function()
  local db = {
    sellMode = "matching",
    rarities = { [3] = true }, equipSlots = {}, itemTypes = {},
    sellBoP = true, sellBoE = false, sellUnbound = false,
    itemSources = { consumable = true }, onlySellLowerIlvl = false,
    expansionProfiles = { [8] = { useDetailedFilters = false } },
  }
  local r = addon.ResolveActiveFilters(db, 8)
  T.eq(r.usedOverride, false)
  T.eq(r.rarities[3], true)
  T.eq(r.itemSources.consumable, true)
  T.eq(r.bindTypes.bop, true)
end)

T.test("resolve uses override when enabled in matching mode", function()
  local db = {
    sellMode = "matching",
    rarities = { [3] = true }, equipSlots = {}, itemTypes = {},
    sellBoP = true, itemSources = {}, onlySellLowerIlvl = false,
    expansionProfiles = { [8] = {
      useDetailedFilters = true,
      rarities = { [4] = true }, equipSlots = {}, itemTypes = {},
      bindTypes = { bop = true }, itemSources = { raid = true }, onlySellLowerIlvl = true,
    } },
  }
  local r = addon.ResolveActiveFilters(db, 8)
  T.eq(r.usedOverride, true)
  T.eq(r.rarities[4], true)
  T.eq(r.rarities[3], nil)
  T.eq(r.itemSources.raid, true)
  T.eq(r.onlyLowerIlvl, true)
end)

T.test("everything mode ignores useDetailedFilters profile", function()
  local db = {
    sellMode = "everything",
    rarities = { [3] = true }, equipSlots = {}, itemTypes = {},
    sellBoP = true, itemSources = { consumable = true }, onlySellLowerIlvl = false,
    expansionProfiles = { [8] = {
      useDetailedFilters = true,
      rarities = { [4] = true }, itemSources = { raid = true },
    } },
  }
  local r = addon.ResolveActiveFilters(db, 8)
  T.eq(r.usedOverride, false)        -- override must NOT apply in everything mode
  T.eq(r.rarities[3], true)          -- global values, not the profile's
  T.eq(r.rarities[4], nil)
  T.eq(r.itemSources.consumable, true)
end)

T.test("resolve handles nil expansionID without crashing", function()
  local db = {
    sellMode = "matching",
    rarities = { [2] = true }, equipSlots = {}, itemTypes = {},
    sellBoP = true, itemSources = {}, onlySellLowerIlvl = false,
    expansionProfiles = {},
  }
  local r = addon.ResolveActiveFilters(db, nil)
  T.eq(r.usedOverride, false)
  T.eq(r.rarities[2], true)
end)

T.test("summary: everything mode headline", function()
  local db = {
    sellMode = "everything",
    expansions = { [8] = true, [10] = false },
    __names = { exp = { [8] = "Wrath" }, rar = {} },
    rarities = {}, itemSources = {}, expansionProfiles = {},
  }
  local s = addon.BuildActiveSummary(db)
  T.eq(s.mode, "everything")
  T.eq(s.headline, "Selling everything from Wrath.")
  T.eq(#s.chips, 0)
end)

T.test("summary: no expansions", function()
  local db = { sellMode = "everything", expansions = {}, __names = { exp = {}, rar = {} },
               rarities = {}, itemSources = {}, expansionProfiles = {} }
  T.eq(addon.BuildActiveSummary(db).headline, "Nothing will sell — no expansions enabled.")
end)

T.test("summary: matching mode with rarity + skip", function()
  local db = {
    sellMode = "matching",
    expansions = { [8] = true },
    rarities = { [3] = true },
    itemSources = { consumable = true },
    onlySellLowerIlvl = false,
    expansionProfiles = { [8] = { useDetailedFilters = false } },
    selectedExpansionProfileID = 8,
    __names = { exp = { [8] = "Wrath" }, rar = { [3] = "Rare" } },
  }
  local s = addon.BuildActiveSummary(db)
  T.eq(s.mode, "matching")
  T.eq(s.headline, "Selling Rare gear from Wrath (skipping Consumables).")
end)

-- Regression: WoW's Lua 5.1 does not honor \xHH hex escapes (they mangle to literal "xHH").
-- This harness runs under Lua 5.4, which DOES support \x, so such bugs pass tests but break
-- in-game. Guard every shipped file: use decimal \ddd or raw UTF-8 bytes instead.
T.test("no \\xHH hex escapes in shipped lua files", function()
  local shipped = { "Filters.lua", "Core.lua", "Config.lua", "Compat.lua" }
  for _, path in ipairs(shipped) do
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    local at = content:find("\\x%x")
    T.eq(at, nil, path .. " contains a \\xHH hex escape (use decimal \\ddd or raw UTF-8)")
  end
end)
