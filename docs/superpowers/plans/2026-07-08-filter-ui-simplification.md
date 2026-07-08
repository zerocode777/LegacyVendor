# Filter UI Simplification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse Legacy Vendor's confusing global-vs-per-expansion filter model into one global filter set (with an optional Advanced per-expansion override), fix the silently-inert source filter, and replace the summary bar with an honest, derived "what will sell" readout.

**Architecture:** Extract the risky *policy* logic (DB migration, source-skip decision, active-filter resolution, readout text) out of the WoW-API-bound `ShouldSellItem` into pure functions on the `addon` table that take plain tables and return plain values. Those pure functions get real automated Lua tests. The `CreateSimpleConfig` frame is rebuilt to drive the new model and consume the pure readout builder; the duplicate native Settings panel is reduced to a launcher.

**Tech Stack:** Lua 5.1 semantics (WoW client / LuaJIT). Addon has **no** runtime dependencies. Tests run under a standalone Lua interpreter with a tiny hand-written WoW-globals stub — test-only, never shipped.

## Global Constraints

- **Lua dialect:** WoW runs Lua 5.1 (LuaJIT). Do not use 5.4-only syntax (integer `//`, `<close>`, bitwise operators, `goto` is fine). Pure logic must stay 5.1-compatible.
- **No shipped dependencies:** the addon loads only `Compat.lua`, `Core.lua`, `Config.lua` (see `LegacyVendor.toc`). The test harness lives under `tests/` and is NOT added to any `.toc`.
- **Preserve all filtering capability:** expansion, rarity, source, slot, type, bind, ilvl, grays, strict M+ protection must all remain reachable. This is a UX/model change, not a capability removal.
- **Conservative migration:** no item that sold before may silently start or stop selling after upgrade. Where an old state cannot be preserved exactly, the change must be visible in the readout, never silent.
- **File size:** `Core.lua` and `Config.lua` are already large. Do not grow them further than necessary — extract new pure logic into a new `Filters.lua` unit rather than appending to `Core.lua`.
- **Copy to live install after every change:** copy shipped files to `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\LegacyVendor`.
- **Changelog:** every user-facing change recorded in `CHANGELOG.md` (CurseForge release notes).
- **Commit style:** Conventional Commits. Work on branch `feat/filter-ui-simplification`.

## File Structure

- **Create `Filters.lua`** — pure policy module. Owns: schema migration, source-skip decision, active-filter resolution (global vs per-expansion override), and the readout-text builder. No WoW API calls. Loaded before `Core.lua` in the `.toc`. Target < 250 lines.
- **Modify `Core.lua`** — `ShouldSellItem` delegates source/resolution decisions to `Filters.lua`; remove the inline `filterBySource` master-gate branch; call `addon.MigrateDB` on load.
- **Modify `Config.lua`** — rebuild `CreateSimpleConfig` sections for the new model; reduce native `CreateOptionsPanel` to a launcher; readout consumes `addon.BuildActiveSummary`.
- **Create `tests/wow_stub.lua`** — minimal globals so pure modules load headless.
- **Create `tests/run.lua`** — bare assert-based runner (no external test lib).
- **Create `tests/test_filters.lua`** — tests for migration, source-skip, resolution, readout.
- **Modify `LegacyVendor.toc`** (and the `_Mists`/`_TBC`/`_Vanilla` variants) — add `Filters.lua` before `Core.lua`; bump `## Version`.
- **Modify `CHANGELOG.md`, `README.md`** — document the new model.

---

### Task 1: Headless Lua test harness

**Files:**
- Create: `tests/wow_stub.lua`
- Create: `tests/run.lua`
- Create: `tests/test_filters.lua` (placeholder asserting harness works)

**Interfaces:**
- Produces: a runnable `lua tests/run.lua` command that loads a module list and executes registered test functions, exiting non-zero on failure.

- [ ] **Step 1: Ensure a Lua interpreter is available**

Run:
```bash
command -v lua lua5.4 luajit 2>/dev/null || winget install --id DEVCOM.Lua --accept-source-agreements --accept-package-agreements
```
Expected: a `lua`/`lua5.4`/`luajit` path is printed, or winget installs one. If winget cannot install, fall back to any Lua 5.1+ binary on PATH. Record the working binary as `LUA` for later steps (e.g. `LUA=lua5.4`).

- [ ] **Step 2: Write the WoW globals stub**

`tests/wow_stub.lua`:
```lua
-- Minimal stubs so pure addon modules load outside the WoW client.
-- Only what Filters.lua touches. NOT shipped.
_G.LegacyVendorDB = _G.LegacyVendorDB or nil

local function noop() end
_G.C_Timer = { After = function(_, f) if f then f() end end }
_G.CreateFrame = _G.CreateFrame or function() return setmetatable({}, {__index = function() return noop end}) end

-- Addon namespace vararg emulation: modules are loaded as chunks with (name, addon).
return function(addonTable)
  return "LegacyVendor", addonTable
end
```

- [ ] **Step 3: Write the runner**

`tests/run.lua`:
```lua
-- Bare test runner: no external deps.
local tests = {}
local T = { test = function(name, fn) tests[#tests + 1] = { name = name, fn = fn } end }

local function eq(a, b, msg)
  if a ~= b then error((msg or "assert eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
T.eq = eq

-- Shared addon table + stub loader available to test files.
local makeArgs = dofile("tests/wow_stub.lua")
local addon = {}
_G.__LV_ADDON = addon
_G.__LV_ARGS = function() return makeArgs(addon) end
_G.__LV_TEST = T

dofile("tests/test_filters.lua")

local failed = 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then print("PASS " .. t.name) else failed = failed + 1; print("FAIL " .. t.name .. "\n  " .. tostring(err)) end
end
print(("%d test(s), %d failed"):format(#tests, failed))
os.exit(failed == 0 and 0 or 1)
```

- [ ] **Step 4: Write a placeholder test**

`tests/test_filters.lua`:
```lua
local T = _G.__LV_TEST
T.test("harness runs", function() T.eq(1 + 1, 2) end)
```

- [ ] **Step 5: Run the harness**

Run: `${LUA:-lua} tests/run.lua`
Expected: prints `PASS harness runs` then `1 test(s), 0 failed`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add tests/
git commit -m "test: add headless Lua test harness"
```

---

### Task 2: `Filters.lua` — schema migration (pure)

**Files:**
- Create: `Filters.lua`
- Test: `tests/test_filters.lua`

**Interfaces:**
- Produces:
  - `addon.SCHEMA_VERSION` (number) = `2`.
  - `addon.MigrateDB(db) -> db` — idempotent. Sets `db.settingsSchemaVersion`, adds `db.sellMode` (`"everything"|"matching"`), converts each source set (global `db.itemSources` and every `db.expansionProfiles[i].itemSources`) from the old include-list to the new **skip-list**, and adds a per-expansion override flag by keeping `expansionProfiles[i].useDetailedFilters` as the override switch. Leaves rarity/slot/type/bind sets untouched.
- Consumes: nothing from other tasks.

**Migration rules (exact):**
- `db.sellMode`: if absent, derive from `db.expansionSellAllMode`: `true`(or nil)→`"everything"`, `false`→`"matching"`.
- Source skip conversion for a scope with old include-set `src` and old gate `gate`:
  - if `gate` is falsy → new skip-set is `{}` (nothing skipped; preserves "no source filtering").
  - if `gate` is truthy → for every known source key `k`, `skip[k] = (src[k] ~= true)` (old behavior sold only explicitly-true sources; skipping everything else preserves that outcome).
- Idempotency: if `db.settingsSchemaVersion == addon.SCHEMA_VERSION`, return `db` unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_filters.lua`:
```lua
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
```

*Note:* `__sourceKeys` in the test injects the known-source key list so the pure module needs no `addon.ITEM_SOURCES` table under test. In production the module reads `addon.ITEM_SOURCES`; the test override takes precedence (see Step 3).

- [ ] **Step 2: Run to verify failure**

Run: `${LUA:-lua} tests/run.lua`
Expected: FAIL — `Filters.lua` not found / `MigrateDB` nil.

- [ ] **Step 3: Implement migration in `Filters.lua`**

```lua
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
    for _, k in ipairs(keys) do skipInto[k] = nil end
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
```

- [ ] **Step 4: Run to verify pass**

Run: `${LUA:-lua} tests/run.lua`
Expected: all migration tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Filters.lua tests/test_filters.lua
git commit -m "feat: add schema migration to single-global filter model"
```

---

### Task 3: Source skip-list decision + active-filter resolution (pure)

**Files:**
- Modify: `Filters.lua`
- Test: `tests/test_filters.lua`

**Interfaces:**
- Produces:
  - `addon.SourceSkipped(skipSet, source) -> boolean` — `true` when `skipSet[source] == true`. `nil` source or absent key → not skipped.
  - `addon.ResolveActiveFilters(db, expansionID) -> table` with fields `mode` (`"everything"|"matching"`), `rarities`, `equipSlots`, `itemTypes`, `bindTypes`, `itemSources` (skip-set), `onlyLowerIlvl`, `usedOverride` (boolean). When `db.sellMode == "matching"` and `db.expansionProfiles[expansionID].useDetailedFilters` is true, values come from that profile (override) and `usedOverride = true`; otherwise from the global `db.*` set.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_filters.lua`:
```lua
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
```

- [ ] **Step 2: Run to verify failure**

Run: `${LUA:-lua} tests/run.lua`
Expected: FAIL — `SourceSkipped` / `ResolveActiveFilters` nil.

- [ ] **Step 3: Implement in `Filters.lua`**

```lua
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
```

- [ ] **Step 4: Run to verify pass**

Run: `${LUA:-lua} tests/run.lua`
Expected: all resolution tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Filters.lua tests/test_filters.lua
git commit -m "feat: pure source-skip and active-filter resolution"
```

---

### Task 4: Readout builder (pure)

**Files:**
- Modify: `Filters.lua`
- Test: `tests/test_filters.lua`

**Interfaces:**
- Produces: `addon.BuildActiveSummary(db) -> { headline=string, chips={string,...}, mode=string }`.
  - `headline`: plain-English sentence. `"everything"` mode → `"Selling everything from <expansions>."`; `"matching"` → `"Selling <rarities> gear from <expansions><, source note>."`. No expansions enabled → `"Nothing will sell — no expansions enabled."`.
  - `chips`: dimension rows for the detail area (empty in `"everything"` mode).
  - Reads expansion/rarity display names from `addon.EXPANSIONS` / `addon.RARITIES`, or from `db.__names` when provided (test injection).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_filters.lua`:
```lua
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
```

- [ ] **Step 2: Run to verify failure**

Run: `${LUA:-lua} tests/run.lua`
Expected: FAIL — `BuildActiveSummary` nil.

- [ ] **Step 3: Implement in `Filters.lua`**

```lua
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

  local expID = db.selectedExpansionProfileID or exps[1] and nil
  local resolved = addon.ResolveActiveFilters(db, db.selectedExpansionProfileID or 0)

  local rarNames = {}
  for id = 0, 7 do if resolved.rarities[id] then rarNames[#rarNames + 1] = rarName(db, id) end end
  local rarText = (#rarNames > 0) and joinList(rarNames) or "all"

  local skipped = {}
  for k, v in pairs(resolved.itemSources) do if v == true then skipped[#skipped + 1] = SOURCE_LABELS[k] or k end end
  table.sort(skipped)
  local skipNote = (#skipped > 0) and (" (skipping " .. joinList(skipped) .. ")") or ""

  local chips = {
    "Rarity ▸ " .. rarText,
    "Source ▸ " .. ((#skipped > 0) and ("skip " .. joinList(skipped)) or "all"),
    "Expansions ▸ " .. expText,
  }
  return { mode = mode, chips = chips, headline = "Selling " .. rarText .. " gear from " .. expText .. skipNote .. "." }
end
```

- [ ] **Step 4: Run to verify pass**

Run: `${LUA:-lua} tests/run.lua`
Expected: all summary tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Filters.lua tests/test_filters.lua
git commit -m "feat: derived active-filter readout builder"
```

---

### Task 5: Wire `Filters.lua` into Core + load/migrate

**Files:**
- Modify: `LegacyVendor.toc`, `LegacyVendor_Mists.toc`, `LegacyVendor_TBC.toc`, `LegacyVendor_Vanilla.toc`
- Modify: `Core.lua:699-730` (source-filter branch), `Core.lua:1697-1744` (load path)

**Interfaces:**
- Consumes: `addon.MigrateDB`, `addon.SourceSkipped`, `addon.ResolveActiveFilters` from Tasks 2-3.

- [ ] **Step 1: Add `Filters.lua` to every `.toc` before `Core.lua`**

In each `.toc`, change the load list so `Filters.lua` precedes `Core.lua`. Example for `LegacyVendor.toc`:
```
Compat.lua
Filters.lua
Core.lua
Config.lua
```

- [ ] **Step 2: Call migration on load**

In `Core.lua` ADDON_LOADED handler, immediately after the `LegacyVendorDB` init/merge block and before `EnsureExpansionProfiles(LegacyVendorDB)` (currently [Core.lua:1744](../../../Core.lua#L1744)), insert:
```lua
            if addon.MigrateDB then addon.MigrateDB(LegacyVendorDB) end
```

- [ ] **Step 3: Replace the source branch in `ShouldSellItem`**

In `Core.lua`, replace the `PassesSourceFilter` local (currently [Core.lua:699-720](../../../Core.lua#L699)) and the resolver lines (currently [Core.lua:695-696](../../../Core.lua#L695)) so source uses the skip-list via `Filters.lua`. New `PassesSourceFilter`:
```lua
    local resolved = addon.ResolveActiveFilters(db, filterExpansionID)
    local function PassesSourceFilter()
        if db.sellMode ~= "matching" then return true end
        local itemSource = GetItemSource(itemID, bag, slot)
        DebugPrint("Item source for", itemLink, ":", itemSource or "nil")
        if addon.SourceSkipped(resolved.itemSources, itemSource) then
            DebugPrint("Source skipped:", itemSource, itemLink)
            return false
        end
        return true
    end
```
Then update the downstream `activeRarities`/`activeBindTypes`/`activeEquipSlots`/`activeItemTypes`/`activeOnlyLowerIlvl` locals (currently [Core.lua:687-697](../../../Core.lua#L687)) to read from `resolved` (`resolved.rarities`, `resolved.bindTypes`, `resolved.equipSlots`, `resolved.itemTypes`, `resolved.onlyLowerIlvl`), and change the meta-mode branch condition (currently [Core.lua:724](../../../Core.lua#L724)) from `if db.expansionSellAllMode and not useDetailedFilters then` to `if db.sellMode == "everything" then`.

- [ ] **Step 4: Syntax-check the changed shipped files**

Run: `${LUA:-lua} -e "assert(loadfile('Core.lua')); assert(loadfile('Filters.lua')); print('ok')"`
Expected: prints `ok` (compiles; WoW globals are only referenced at call time, not load time). If a `luac` is available, also run `luac -p Core.lua Filters.lua`.

- [ ] **Step 5: Re-run the pure test suite (regression)**

Run: `${LUA:-lua} tests/run.lua`
Expected: all tests PASS (no behavioral regression in pure modules).

- [ ] **Step 6: Commit**

```bash
git add LegacyVendor*.toc Core.lua
git commit -m "feat: route sell decision through Filters.lua skip-list model"
```

---

### Task 6: Rebuild `CreateSimpleConfig` for the new model

**Files:**
- Modify: `Config.lua:393-1086` (`CreateSimpleConfig`)

**Interfaces:**
- Consumes: `addon.BuildActiveSummary` (Task 4), `addon.ResolveActiveFilters` (Task 3).

This task is UI (WoW frames) and is verified by the in-game checklist in Step 6, not headless tests. Reuse the existing helpers unchanged where noted (`CreateCheckbox`, `CreateCheckbox2Col`, `AddHeader`, `AddSep`, `Flush2Col`, `MakeBtn`, search box, scroll frame) — do not re-transcribe them.

- [ ] **Step 1: Replace the two-toggle mode with one radio at the top of General Settings**

Remove the "Expansion Meta Mode" checkbox ([Config.lua:756-759](../../../Config.lua#L756)) and the per-expansion "Use Detailed Filters For This Expansion" checkbox ([Config.lua:839-842](../../../Config.lua#L839)). In their place, at the top of the General section, add two radio-style checkboxes bound to `LegacyVendorDB.sellMode` (mutually exclusive; clicking one sets the mode and calls `RefreshButton()` + `RefreshSummary()` + `RefreshDetailGrey()`):
```lua
    local function SetMode(m)
        LegacyVendorDB.sellMode = m
        RefreshButton(); RefreshSummary(); RefreshConfigFrame()
    end
    CreateCheckbox(content, "Sell EVERYTHING from enabled expansions",
        "Ignore detailed filters; sell all legacy items from the expansions you tick below.",
        function() return LegacyVendorDB.sellMode == "everything" end,
        function() SetMode("everything") end)
    CreateCheckbox(content, "Only sell items MATCHING my filters",
        "Use the rarity / source / slot / type / bind filters below.",
        function() return LegacyVendorDB.sellMode == "matching" end,
        function() SetMode("matching") end)
```

- [ ] **Step 2: Make the expansion list a plain checklist**

Remove the inline badge logic ([Config.lua:863-872](../../../Config.lua#L863)) so each expansion is a plain `CreateCheckbox2Col` of `LegacyVendorDB.expansions[i]`. Keep the section header text but drop the `[detail]/[all]/[global]` legend.

- [ ] **Step 3: Point detailed sections at the GLOBAL set**

Change Rarity, Equipment Slot, and Item Type sections ([Config.lua:930-1012](../../../Config.lua#L930)) to read/write `LegacyVendorDB.rarities[id]`, `LegacyVendorDB.equipSlots[key]`, `LegacyVendorDB.itemTypes[id]` (global), not `GetSelectedProfile()`. Change Bind Type section ([Config.lua:886-900](../../../Config.lua#L886)) to write `LegacyVendorDB.sellBoP/sellBoE/sellUnbound`.

- [ ] **Step 4: Rebuild the Source section as a skip-list**

Replace the Source section ([Config.lua:904-925](../../../Config.lua#L904)). Delete the "Enable Source Filtering" master checkbox entirely. New header + boxes:
```lua
    AddHeader("|cFFFFD100Don't sell from these sources|r  |cFF888888(tick to SKIP)|r",
        "Ticked sources are never sold in 'matching' mode. Leave all unticked to allow every source.")
    local sourceOrder = { "consumable", "dungeon", "raid", "outdoor", "profession", "vendor", "pvp", "reputation", "housing", "unknown" }
    for _, sourceKey in ipairs(sourceOrder) do
        local source = addon.ITEM_SOURCES[sourceKey]
        if source then
            CreateCheckbox2Col(content, source.name, "SKIP " .. source.name .. " (never sell).",
                function() return LegacyVendorDB.itemSources[sourceKey] == true end,
                function(v) LegacyVendorDB.itemSources[sourceKey] = v and true or nil end, true)
        end
    end
    Flush2Col()
```

- [ ] **Step 5: Move per-expansion editor behind an "Advanced" collapsible**

Replace the always-visible Expansion Profile Editor (selector bar + Prev/Next + per-profile checkboxes, [Config.lua:791-847](../../../Config.lua#L791)) with a single collapsible header defaulting closed, backed by `LegacyVendorDB.showAdvanced` (default false/nil). When open, render the existing Prev/Next selector and the per-profile detailed checkboxes (rarity/slot/type/source/bind/ilvl bound to `GetSelectedProfile()`), plus the per-expansion override switch bound to `GetSelectedProfile().useDetailedFilters`. When closed, render nothing but the header. Toggling calls `RefreshConfigFrame()`.
```lua
    local advOpen = LegacyVendorDB.showAdvanced == true
    AddHeader((advOpen and "|cFFFFD100▼ Advanced: per-expansion overrides|r"
                        or "|cFF888888▶ Advanced: per-expansion overrides (click to expand)|r"),
        "Optional. Override the global filters for one specific expansion.")
    -- Make the header clickable via an invisible button over its row; on click:
    --   LegacyVendorDB.showAdvanced = not advOpen; RefreshConfigFrame()
    -- if advOpen then ... render selector + per-profile checkboxes ... end
```

- [ ] **Step 6: Wire the hybrid readout + grey-out**

Replace `BuildActiveSummary`/`RefreshSummary` ([Config.lua:538-596](../../../Config.lua#L538)) to consume the pure builder and drive both the headline and a detail (chips) line, greying detail when not in matching mode:
```lua
    local function RefreshSummary()
        local s = addon.BuildActiveSummary(LegacyVendorDB)
        topSummaryText:SetText("|cFF44FF44✔ " .. s.headline .. "|r")
        local detail = (#s.chips > 0) and table.concat(s.chips, "   ") or ""
        bottomSummaryText:SetText(detail)
        bottomSummaryText:SetTextColor(s.mode == "matching" and 0.8 or 0.4,
                                       s.mode == "matching" and 0.9 or 0.4, 0.5)
    end
```
Also add a `RefreshDetailGrey()` that greys the detailed section frames (store their frames in a list as they are created) when `LegacyVendorDB.sellMode ~= "matching"`; call it from `RefreshSummary` and after `SetMode`.

- [ ] **Step 7: Copy to the live install and test in-game**

Copy shipped files:
```bash
cp Compat.lua Core.lua Config.lua Filters.lua LegacyVendor*.toc \
  "/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/LegacyVendor/"
```
In-game checklist (`/reload`, `/lv config`):
1. Toggle mode radios — detail sections grey in "everything", active in "matching"; only one radio checked at a time.
2. Enable Wrath + Legion; readout says "Selling everything from Wrath & Legion." in everything mode.
3. Switch to matching, tick Rare; headline updates to "Selling Rare gear from Wrath & Legion."
4. Tick **Consumable** under "Don't sell from these sources"; visit a vendor with an old potion in bags → it is NOT in the sell scan (`/lv scan`); headline shows "(skipping Consumables)". This is the reported bug fixed.
5. Expand Advanced → per-expansion override still available; toggling it changes only that expansion.
6. `/lv reset` → returns to safe defaults, readout shows "Nothing will sell — no expansions enabled." (or default expansions per defaults).

- [ ] **Step 8: Commit**

```bash
git add Config.lua
git commit -m "feat: rebuild config UI around single-mode filter model and hybrid readout"
```

---

### Task 7: Reduce the duplicate native Settings panel to a launcher

**Files:**
- Modify: `Config.lua:14-390` (`CreateOptionsPanel`)

**Interfaces:**
- Consumes: `addon.OpenConfig` (existing).

The native `CreateOptionsPanel` currently duplicates a subset of controls against the *global* fields, competing with the custom frame. Reduce it to a master enable + a launch button so there is one real config surface.

- [ ] **Step 1: Strip the panel body**

In `CreateOptionsPanel`, remove the Source Filter section ([Config.lua:223-260](../../../Config.lua#L223)) and the rarity/slot/type initializers, keeping only: the header, the "Enable LegacyVendor" checkbox ([Config.lua:26-38](../../../Config.lua#L26)), and a new button initializer whose click calls `addon.OpenConfig()` with label "Open Legacy Vendor Filters…".

- [ ] **Step 2: Syntax-check**

Run: `${LUA:-lua} -e "assert(loadfile('Config.lua')); print('ok')"`
Expected: prints `ok`.

- [ ] **Step 3: Copy to live install and verify**

Copy `Config.lua` to the live folder (command from Task 6 Step 7). `/reload`; open Blizzard AddOns settings → LegacyVendor shows only Enable + the launch button; clicking the button opens the custom frame.

- [ ] **Step 4: Commit**

```bash
git add Config.lua
git commit -m "refactor: reduce native settings panel to a launcher"
```

---

### Task 8: Docs, version bump, changelog, final deploy

**Files:**
- Modify: `CHANGELOG.md`, `README.md`, `LegacyVendor.toc` + variants (`## Version`)

- [ ] **Step 1: Bump version**

Set `## Version:` to `2.2.0` in `LegacyVendor.toc`, `LegacyVendor_Mists.toc`, `LegacyVendor_TBC.toc`, `LegacyVendor_Vanilla.toc`. Update the badge in `README.md`.

- [ ] **Step 2: Write the CHANGELOG entry**

Add a `## [2.2.0]` section to `CHANGELOG.md` (user-facing wording):
```markdown
## [2.2.0]
### Changed
- Simplified filtering: one clear choice — "Sell everything from enabled expansions" or
  "Only sell items matching my filters". No more hidden meta/detailed modes.
- Filters (rarity, source, slot, type, bind) are now one global set applied to every enabled
  expansion. Per-expansion tuning moved to an optional "Advanced" section (off by default).
- The settings panel now shows a plain-English summary of exactly what will sell, plus a detail
  line, and greys out filters that aren't in effect.
### Fixed
- Source filtering now works as expected. Ticking a source under "Don't sell from these sources"
  (e.g. Consumables) reliably stops those items from selling — previously the toggle could do
  nothing. Fixes the reported inability to stop selling PvP potions / consumables.
### Notes
- Your existing settings are migrated automatically; nothing new will sell without you seeing it
  in the summary. Use /lv reset to start fresh.
```

- [ ] **Step 3: Update README filter docs**

Update the "Filter Logic" and "Configuration Options" sections of `README.md` to describe the mode radio, the global filter set, the skip-list source section, and the Advanced override. Remove references to "Meta Mode" and per-expansion "Use Detailed Filters".

- [ ] **Step 4: Full deploy to live install**

```bash
cp Compat.lua Core.lua Config.lua Filters.lua LegacyVendor*.toc \
  "/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/LegacyVendor/"
```
`/reload` in-game; confirm version shows 2.2.0 in the addon list and the login message.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md README.md LegacyVendor*.toc
git commit -m "docs: document 2.2.0 filter simplification and bump version"
```

---

## Self-Review

**Spec coverage:**
- §3.1 one top-level mode → Task 6 Step 1. ✅
- §3.2 expansion checklist → Task 6 Step 2. ✅
- §3.3 one global detailed set → Task 6 Step 3 + Task 3 resolver. ✅
- §3.4 Advanced override door → Task 6 Step 5 + Task 3 override path. ✅
- §4 skip-list source semantics + delete master gate → Task 4/Task 5 Step 3 + Task 6 Step 4. ✅
- §5 hybrid derived readout + grey-out → Task 4 + Task 6 Step 6. ✅
- §6 migration + schema version → Task 2 + Task 5 Step 2. ✅
- §7 affected files incl. duplicate native panel → Task 5/6/7. ✅ (native panel dedupe added beyond spec, consistent with its intent.)
- §8 copy-to-live + changelog → Task 6 Step 7, Task 8. ✅

**Placeholder scan:** No "TBD/TODO"; the one intentionally-descriptive block (Task 6 Step 5 collapsible click wiring) includes the exact state field, default, and the toggle expression. UI reuse of existing helpers is called out by name and line rather than re-transcribed, per the "read tasks out of order" caveat — the helpers already exist in the file being modified, so there is no cross-task type dependency on them.

**Type consistency:** `MigrateDB`, `SourceSkipped(skipSet, source)`, `ResolveActiveFilters(db, expansionID) -> {rarities,equipSlots,itemTypes,bindTypes,itemSources,onlyLowerIlvl,mode,usedOverride}`, and `BuildActiveSummary(db) -> {headline,chips,mode}` are used with identical names/shapes in Tasks 5 and 6. `sellMode` values `"everything"|"matching"` are consistent across Tasks 2-6. Source skip representation (`true` = skip, `nil` = allow) is consistent between migration (Task 2), decision (Task 3), UI writes (Task 6 Step 4), and readout (Task 4).

**Risk note:** Task 2's `gate on` source conversion is the only outcome-preserving transform with real subtlety; it has a dedicated test ("source skip preserves include-list when gate on"). The `everything`-mode users (vast majority) get an empty skip-set, i.e. identical behavior.
