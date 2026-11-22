-- Loaded only by LegacyVendor_Forever.toc. Settings rows for the Forever-only
-- rules. Config.lua calls addon.RenderForeverOptions(ui) with its own layout
-- helpers, so these rows share the panel's spacing, search and live refresh:
--   ui.checkbox(label, tooltip, get, set)   ui.numberRow(label, get, set, suffix)
--   ui.subLabel(text)                       ui.rebuild()
local _, addon = ...

if not addon.isForever then return end

local RECOMMENDED = "  |cFF44FF44(recommended)|r"

local function RenderLevelRules(ui, db)
    ui.checkbox("Only sell gear I have out-levelled",
        "Gear only sells once its required level is well below yours. Leaves "
        .. "level-appropriate drops alone while you level.",
        function() return db.onlyOutgrownGear end,
        function(v) db.onlyOutgrownGear = v; ui.rebuild() end)

    if db.onlyOutgrownGear then
        ui.numberRow("Levels below me:",
            function() return db.outgrownLevels or 10 end,
            function(v) db.outgrownLevels = math.max(1, v) end,
            "or more")
    end
end

local function RenderIlvlRules(ui, db)
    ui.checkbox("Set the item level limit from my equipped gear" .. RECOMMENDED,
        "Replaces the fixed number with the average item level of the gear you are "
        .. "wearing (empty slots ignored), so the limit rises as you gear up. "
        .. "Anything at or above it is never sold.",
        function() return db.autoIlvlLimit end,
        function(v) db.autoIlvlLimit = v; ui.rebuild() end)
end

local function RenderClassRules(ui, db)
    ui.checkbox("Always sell soulbound gear my class can never use" .. RECOMMENDED,
        "Plate on a mage, shields on a rogue, wands on a warrior, class-restricted "
        .. "items for other classes. It can never be an upgrade, so it sells even when "
        .. "your rarity or item level filters would keep it. Never-sell list, equipment "
        .. "sets and collection protection still apply.",
        function() return db.sellUnusableGear end,
        function(v) db.sellUnusableGear = v end)

    ui.checkbox("Protect gear saved in equipment sets" .. RECOMMENDED,
        "Your off-spec set looks worse than what you are wearing, so without this "
        .. "the item level rules would sell it after a dual-spec swap.",
        function() return db.protectEquipmentSets end,
        function(v) db.protectEquipmentSets = v end)
end

local function RenderBagWarning(ui, db)
    ui.checkbox("Warn me when my bags are almost full",
        "Prints the cheapest items you could sell, once each time free space drops "
        .. "to the limit below.",
        function() return db.bagFullWarning end,
        function(v) db.bagFullWarning = v; ui.rebuild() end)

    if db.bagFullWarning then
        ui.numberRow("Warn at:",
            function() return db.bagFullSlots or 4 end,
            function(v) db.bagFullSlots = v end,
            "free slots or fewer")
    end
end

--- Renders every Forever-only option into the settings panel.
function addon.RenderForeverOptions(ui)
    local db = LegacyVendorDB
    ui.subLabel("WOW FOREVER")
    RenderIlvlRules(ui, db)
    RenderLevelRules(ui, db)
    RenderClassRules(ui, db)
    RenderBagWarning(ui, db)
end
