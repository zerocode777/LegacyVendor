-- LegacyVendor - Chip-based filter sections
-- Renders each filter group as a wrapped row of icon/colour chips instead of a
-- vertical checkbox list, so a whole category can be read at a glance. Every
-- renderer takes (content, yOffset, ctx) and returns the new yOffset.

local addonName, addon = ...

local Sections = {}
addon.Sections = Sections

local W = nil -- addon.Widgets, resolved lazily (load order safe)
local V = nil -- addon.Visuals

local CHIP_AREA_WIDTH = 596
local CHIP_LEFT_INSET = 12

local function ensureRefs()
    W = W or addon.Widgets
    V = V or addon.Visuals
    return W and V
end

-- Bulk All / None row. Clicking 22 gear slots one at a time is the single most
-- tedious thing in the old panel; these make a whole group one click.
local function AddBulkRow(content, yOffset, specs, set, onChange, rebuild)
    if not ensureRefs() then return yOffset end

    local row = CreateFrame("Frame", nil, content)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", CHIP_LEFT_INSET, yOffset)
    row:SetSize(200, 20)

    local function applyAll(value)
        for _, spec in ipairs(specs) do set(spec.key, value) end
        if onChange then onChange() end
        if rebuild then rebuild() end
    end

    local all = W.CreatePresetButton(row, "All", "Turn every option in this group on.",
        function() applyAll(true) end)
    all:SetHeight(20)
    all:SetPoint("LEFT", row, "LEFT", 0, 0)

    local none = W.CreatePresetButton(row, "None", "Turn every option in this group off.",
        function() applyAll(false) end)
    none:SetHeight(20)
    none:SetPoint("LEFT", all, "RIGHT", 5, 0)

    return yOffset - 24, row
end

-- Generic chip group. specs is an array of:
--   { key, label, icon, color, tooltip }
-- get(key) -> bool, set(key, bool)
function Sections.RenderChipGroup(content, yOffset, specs, get, set, onChange, registry, rebuild)
    if not ensureRefs() then return yOffset end

    -- Groups big enough to be tedious get bulk controls; a three-chip row does not
    -- need them and the buttons would just add noise.
    if #specs >= 5 then
        local newY, row = AddBulkRow(content, yOffset, specs, set, onChange, rebuild)
        yOffset = newY
        if registry and row then registry[#registry + 1] = row end
    end

    local chips = {}
    for _, spec in ipairs(specs) do
        local key = spec.key
        local chip = W.CreateChip(content, spec,
            function() return get(key) end,
            function(v)
                set(key, v)
                if onChange then onChange() end
            end)
        chips[#chips + 1] = chip
        if registry then registry[#registry + 1] = chip end
    end

    return W.LayoutChips(content, chips, yOffset, CHIP_LEFT_INSET, CHIP_AREA_WIDTH)
end

-- Expansions: the primary filter, so it gets the widest, most prominent row.
function Sections.RenderExpansions(content, yOffset, maxExpansion, onChange, registry, rebuild)
    if not ensureRefs() then return yOffset end

    local specs = {}
    for i = 0, maxExpansion do
        local exp = addon.EXPANSIONS[i]
        if exp then
            specs[#specs + 1] = {
                key = i,
                label = exp.short or exp.name,
                icon = V.ExpansionIcon[i],
                tooltip = "Sell items from " .. exp.name .. ".",
            }
        end
    end

    return Sections.RenderChipGroup(content, yOffset, specs,
        function(key) return LegacyVendorDB.expansions[key] end,
        function(key, v) LegacyVendorDB.expansions[key] = v end,
        onChange, registry, rebuild)
end

-- Rarity chips carry the actual quality colour, which is the game's own visual
-- language for this exact concept.
function Sections.RenderRarities(content, yOffset, onChange, registry, rebuild)
    if not ensureRefs() then return yOffset end

    local specs = {}
    for id = 0, 5 do
        local r = addon.RARITIES[id]
        if r then
            specs[#specs + 1] = {
                key = id,
                label = V.RarityShort[id] or r.name,
                color = V.HexToRGB(r.color),
                tooltip = "Sell " .. r.name .. " items.",
            }
        end
    end

    return Sections.RenderChipGroup(content, yOffset, specs,
        function(key) return LegacyVendorDB.rarities[key] end,
        function(key, v) LegacyVendorDB.rarities[key] = v end,
        onChange, registry, rebuild)
end

function Sections.RenderBindTypes(content, yOffset, onChange, registry, rebuild)
    if not ensureRefs() then return yOffset end

    -- Bind settings live on their own db keys rather than a table, so map explicitly.
    local specs = {
        { key = "bop",     label = V.ShortLabel.bop,     icon = V.BindIcon.bop,
          tooltip = "Sell Bind on Pickup (soulbound) items." },
        { key = "boe",     label = V.ShortLabel.boe,     icon = V.BindIcon.boe,
          tooltip = "Sell Bind on Equip items that are already bound." },
        { key = "unbound", label = V.ShortLabel.unbound, icon = V.BindIcon.unbound,
          tooltip = "Sell items that never bound - old food, reagents. Be careful." },
    }

    local field = { bop = "sellBoP", boe = "sellBoE", unbound = "sellUnbound" }

    return Sections.RenderChipGroup(content, yOffset, specs,
        function(key) return LegacyVendorDB[field[key]] end,
        function(key, v) LegacyVendorDB[field[key]] = v end,
        onChange, registry, rebuild)
end

-- Sources are a SKIP list: an active chip means "never sell this". Rendered with
-- the same chip vocabulary but the label above makes the inversion explicit.
function Sections.RenderSources(content, yOffset, onChange, registry, rebuild)
    if not ensureRefs() then return yOffset end

    local order = { "consumable", "dungeon", "raid", "outdoor", "profession",
                    "vendor", "pvp", "reputation", "housing", "unknown" }

    local specs = {}
    for _, key in ipairs(order) do
        local src = addon.ITEM_SOURCES[key]
        if src then
            specs[#specs + 1] = {
                key = key,
                label = V.ShortLabel[key] or src.name,
                icon = V.SourceIcon[key],
                tooltip = "Never sell items from: " .. src.name,
            }
        end
    end

    return Sections.RenderChipGroup(content, yOffset, specs,
        function(key) return LegacyVendorDB.itemSources[key] == true end,
        function(key, v) LegacyVendorDB.itemSources[key] = v and true or nil end,
        onChange, registry, rebuild)
end

-- Equipment slots use the character sheet's own empty-slot art.
function Sections.RenderEquipSlots(content, yOffset, onChange, registry, rebuild)
    if not ensureRefs() then return yOffset end

    local order = {
        "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
        "INVTYPE_CHEST", "INVTYPE_BODY", "INVTYPE_WAIST", "INVTYPE_LEGS",
        "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER",
        "INVTYPE_TRINKET", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_SHIELD",
        "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE",
        "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_TABARD",
    }

    local specs = {}
    for _, key in ipairs(order) do
        local slot = addon.EQUIP_SLOTS[key]
        if slot then
            specs[#specs + 1] = {
                key = key,
                label = slot.name,
                icon = V.EquipSlotIcon[key],
                tooltip = "Sell items equipped in: " .. slot.name,
            }
        end
    end

    return Sections.RenderChipGroup(content, yOffset, specs,
        function(key) return LegacyVendorDB.equipSlots[key] end,
        function(key, v) LegacyVendorDB.equipSlots[key] = v end,
        onChange, registry, rebuild)
end

function Sections.RenderItemTypes(content, yOffset, onChange, registry, rebuild)
    if not ensureRefs() then return yOffset end

    local order = { 0, 1, 3, 5, 7, 9, 12, 13, 15 }

    local specs = {}
    for _, id in ipairs(order) do
        local t = addon.ITEM_TYPES[id]
        if t then
            specs[#specs + 1] = {
                key = id,
                label = V.ItemTypeShort[id] or t.name,
                icon = V.ItemTypeIcon[id],
                tooltip = "Sell: " .. t.name,
            }
        end
    end

    return Sections.RenderChipGroup(content, yOffset, specs,
        function(key) return LegacyVendorDB.itemTypes[key] end,
        function(key, v) LegacyVendorDB.itemTypes[key] = v end,
        onChange, registry, rebuild)
end

-- ==========================================
-- PRESETS
-- ==========================================
-- The fastest path from "installed" to "configured", which is the step most users
-- never finish. Each preset writes a complete, coherent filter set.
Sections.Presets = {
    {
        name = "Conservative",
        tooltip = "Only soulbound gear from expansions you pick. Leaves consumables, "
               .. "trade goods and unbound items alone. The safe starting point.",
        apply = function(db)
            db.sellMode = "matching"
            db.sellBoP, db.sellBoE, db.sellUnbound = true, false, false
            db.rarities = { [0] = true, [1] = false, [2] = true, [3] = true, [4] = false, [5] = false }
            db.itemSources = { consumable = true, profession = true }
            for id in pairs(addon.ITEM_TYPES) do db.itemTypes[id] = false end
        end,
    },
    {
        name = "Everything old",
        tooltip = "Sell all legacy items from the expansions you pick, ignoring the "
               .. "detailed filters. Fastest cleanup.",
        apply = function(db)
            db.sellMode = "everything"
        end,
    },
    {
        name = "Transmog-safe",
        tooltip = "Like Conservative, but also skips anything that could still be an "
               .. "appearance you have not collected. Uncollected protection is forced on.",
        apply = function(db)
            db.sellMode = "matching"
            db.protectUncollected = true
            db.sellBoP, db.sellBoE, db.sellUnbound = true, false, false
            db.rarities = { [0] = true, [1] = false, [2] = true, [3] = false, [4] = false, [5] = false }
            db.itemSources = { consumable = true, profession = true, raid = true }
            for id in pairs(addon.ITEM_TYPES) do db.itemTypes[id] = false end
        end,
    },
}
