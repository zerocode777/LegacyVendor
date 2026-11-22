-- Loaded only by LegacyVendor_Forever.toc, after Core.lua and the config files.
--
-- WoW: Forever is a single content tier (level 60, no expansions), so the addon's
-- "legacy expansion" model collapses: there is nothing to pick between, no
-- current-season Mythic+ scaling to guard against, and no housing or delves.
-- This file reshapes the shared data tables for that world and owns the rules
-- applied to the saved settings at login. Retail never loads it.
local _, addon = ...

if not addon.isForever then return end

-- The single tier every item resolves to (see Compat.lua: MAX_EXPANSION = 0).
addon.EXPANSIONS = {
    [0] = { id = 0, name = "WoW Forever", short = "Forever", enabled = true },
}

-- Sources that do not exist in Forever. Removing the key hides the chip everywhere
-- it is rendered, because every renderer skips keys missing from ITEM_SOURCES.
addon.ITEM_SOURCES.housing = nil

-- Slash commands that only make sense with several expansions or M+ seasons.
local DISABLED_COMMANDS = {
    expansions = true, list = true, meta = true, strict = true,
}

--- Returns true (after telling the user) when a slash command has no meaning on Forever.
function addon.ForeverBlocksCommand(msg)
    if not (DISABLED_COMMANDS[msg] or msg:match("^exp%s*%d+$")) then
        return false
    end
    addon.Print("That command is not used on WoW Forever - there are no expansions "
        .. "or Mythic+ seasons to filter by.")
    return true
end

-- One-time defaults for a fresh Forever install. Applied once per saved-variable
-- file, so anything the player changes afterwards sticks.
local function ApplyFirstRunDefaults(db)
    if db.foreverDefaultsApplied then return end
    db.foreverDefaultsApplied = true

    -- With no expansion gate, gear is only safe to sell when it is clearly worse
    -- than what is equipped - otherwise a fresh drop that is an upgrade would go.
    db.onlySellLowerIlvl = true

    -- Forever's transmog collection is new and account-wide. The check only blocks
    -- items whose appearance is genuinely missing, so the cost of being careful is
    -- low while collection-on-bind behaviour is still unverified there.
    db.protectUncollectedAppearances = true
end

--- Applies the Forever rules to the saved settings. Called by Core at ADDON_LOADED.
function addon.ApplyForeverRules(db)
    if not db then return end

    -- "Everything from those expansions" with no expansion gate would mean
    -- "everything with a sell price". Filters.EffectiveSellMode also enforces this
    -- at decision time, so imports and old profiles cannot switch it back on.
    db.sellMode = "matching"

    db.expansions = { [0] = true }
    db.selectedExpansionProfileID = 0

    -- Nothing in Forever is scaled by M+ bonus IDs; the check is inert there anyway
    -- (CURRENT_EXPANSION is 0), so keep the flag off to keep summaries honest.
    db.strictSeasonalProtection = false

    ApplyFirstRunDefaults(db)
end
