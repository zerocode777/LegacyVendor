-- LegacyVendor - Automatically sell legacy expansion BoP items
-- Compatible with all WoW versions: Retail, Cataclysm Classic, Classic Era

local addonName, addon = ...

-- Expansion IDs and names (full list for Retail, filtered for Classic)
-- All expansions default to false - user must explicitly choose which to sell
addon.EXPANSIONS = {
    [0] = { id = 0, name = "Classic", short = "Vanilla", enabled = false },
    [1] = { id = 1, name = "The Burning Crusade", short = "TBC", enabled = false },
    [2] = { id = 2, name = "Wrath of the Lich King", short = "WotLK", enabled = false },
    [3] = { id = 3, name = "Cataclysm", short = "Cata", enabled = false },
    [4] = { id = 4, name = "Mists of Pandaria", short = "MoP", enabled = false },
    [5] = { id = 5, name = "Warlords of Draenor", short = "WoD", enabled = false },
    [6] = { id = 6, name = "Legion", short = "Legion", enabled = false },
    [7] = { id = 7, name = "Battle for Azeroth", short = "BfA", enabled = false },
    [8] = { id = 8, name = "Shadowlands", short = "SL", enabled = false },
    [9] = { id = 9, name = "Dragonflight", short = "DF", enabled = false },
    [10] = { id = 10, name = "The War Within", short = "TWW", enabled = false },
    [11] = { id = 11, name = "Midnight", short = "MN", enabled = false },
}

-- Current expansion ID - will be overridden by Compat.lua if loaded
if not addon.CURRENT_EXPANSION then
    addon.CURRENT_EXPANSION = 11
end

-- Historical item level ceiling for each expansion.
-- Items whose effective ilvl (with bonus IDs applied) exceeds this value were
-- almost certainly scaled up by current-season M+ bonus IDs.
-- NOTE: WoD (5) and Legion (6) ceilings are ABOVE current content ilvl due to
-- pre-squish inflation — rely on SEASONAL_LEGACY_DUNGEON_INSTANCES for those.
addon.EXPANSION_ILVL_CEILING = {
    [0] = 90,    -- Classic (Naxxramas 40-man)
    [1] = 170,   -- The Burning Crusade (Sunwell Plateau)
    [2] = 300,   -- Wrath of the Lich King (ICC Heroic 25)
    [3] = 420,   -- Cataclysm (Dragon Soul Heroic 25)
    [4] = 580,   -- Mists of Pandaria (Siege of Orgrimmar Heroic 25)
    [5] = 745,   -- Warlords of Draenor (pre-squish peak) — use instance table instead
    [6] = 1010,  -- Legion (pre-squish peak) — use instance table instead
    [7] = 495,   -- Battle for Azeroth (Ny'alotha Heroic, post-squish)
    [8] = 290,   -- Shadowlands (Sepulcher Heroic, post-squish)
    [9] = 540,   -- Dragonflight (Amirdrassil Heroic)
    [10] = 690,  -- The War Within (update each season as the ceiling rises)
}

-- EJ (Encounter Journal) instance IDs for legacy expansion dungeons currently
-- in the seasonal M0/M+ rotation. Items from these instances bear old expansion
-- IDs but drop at current-tier ilvl and must never be auto-sold.
--
-- HOW TO FIND INSTANCE IDs:
--   1. /lv debug      (enable debug output)
--   2. Open a vendor with the suspicious item in your bags
--   3. Look for "Item source instanceID: X" lines in chat
--   4. Add the ID here and report it on the addon page
--
-- TWW Season 3 (patch 11.x, 2026) — update when the rotation changes:
addon.SEASONAL_LEGACY_DUNGEON_INSTANCES = {
    [226] = true,   -- Pit of Saron (Wrath of the Lich King)
    [585] = true,   -- Skyreach (Warlords of Draenor)
    -- Report additional instance IDs via the addon page if items slip through
}

-- Hard floor used by strict seasonal protection.
-- If a legacy item reaches this effective ilvl, treat it as current-season scaled
-- content and never sell it.
addon.STRICT_SEASONAL_ILVL_FLOOR = 620

-- Item Rarities (Quality)
addon.RARITIES = {
    [0] = { id = 0, name = "Poor (Gray)", color = "9d9d9d", enabled = true },
    [1] = { id = 1, name = "Common (White)", color = "ffffff", enabled = false },
    [2] = { id = 2, name = "Uncommon (Green)", color = "1eff00", enabled = true },
    [3] = { id = 3, name = "Rare (Blue)", color = "0070dd", enabled = true },
    [4] = { id = 4, name = "Epic (Purple)", color = "a335ee", enabled = true },
    [5] = { id = 5, name = "Legendary (Orange)", color = "ff8000", enabled = false },
    -- Note: Artifact (6) and Heirloom (7) cannot be sold, so not included
}

-- Equipment Slots (invType from GetItemInfo)
addon.EQUIP_SLOTS = {
    ["INVTYPE_HEAD"] = { name = "Head", enabled = true },
    ["INVTYPE_NECK"] = { name = "Neck", enabled = true },
    ["INVTYPE_SHOULDER"] = { name = "Shoulder", enabled = true },
    ["INVTYPE_BODY"] = { name = "Shirt", enabled = false },
    ["INVTYPE_CHEST"] = { name = "Chest", enabled = true },
    ["INVTYPE_WAIST"] = { name = "Waist", enabled = true },
    ["INVTYPE_LEGS"] = { name = "Legs", enabled = true },
    ["INVTYPE_FEET"] = { name = "Feet", enabled = true },
    ["INVTYPE_WRIST"] = { name = "Wrist", enabled = true },
    ["INVTYPE_HAND"] = { name = "Hands", enabled = true },
    ["INVTYPE_FINGER"] = { name = "Ring", enabled = true },
    ["INVTYPE_TRINKET"] = { name = "Trinket", enabled = true },
    ["INVTYPE_CLOAK"] = { name = "Back/Cloak", enabled = true },
    ["INVTYPE_WEAPON"] = { name = "One-Hand Weapon", enabled = true },
    ["INVTYPE_SHIELD"] = { name = "Shield", enabled = true },
    ["INVTYPE_2HWEAPON"] = { name = "Two-Hand Weapon", enabled = true },
    ["INVTYPE_WEAPONMAINHAND"] = { name = "Main Hand", enabled = true },
    ["INVTYPE_WEAPONOFFHAND"] = { name = "Off Hand", enabled = true },
    ["INVTYPE_HOLDABLE"] = { name = "Held In Off-Hand", enabled = true },
    ["INVTYPE_RANGED"] = { name = "Ranged", enabled = true },
    ["INVTYPE_RANGEDRIGHT"] = { name = "Ranged (Wand/Gun/Bow)", enabled = true },
    ["INVTYPE_TABARD"] = { name = "Tabard", enabled = false },
}

-- Mapping from equipLoc to inventory slot IDs for GetInventoryItemLink
-- Some slots map to two IDs (e.g. rings, trinkets, weapons)
addon.EQUIP_LOC_TO_SLOT = {
    ["INVTYPE_HEAD"]           = { 1 },
    ["INVTYPE_NECK"]           = { 2 },
    ["INVTYPE_SHOULDER"]       = { 3 },
    ["INVTYPE_BODY"]           = { 4 },
    ["INVTYPE_CHEST"]          = { 5 },
    ["INVTYPE_ROBE"]           = { 5 },
    ["INVTYPE_WAIST"]          = { 6 },
    ["INVTYPE_LEGS"]           = { 7 },
    ["INVTYPE_FEET"]           = { 8 },
    ["INVTYPE_WRIST"]          = { 9 },
    ["INVTYPE_HAND"]           = { 10 },
    ["INVTYPE_FINGER"]         = { 11, 12 },
    ["INVTYPE_TRINKET"]        = { 13, 14 },
    ["INVTYPE_CLOAK"]          = { 15 },
    ["INVTYPE_WEAPON"]         = { 16, 17 },
    ["INVTYPE_SHIELD"]         = { 17 },
    ["INVTYPE_2HWEAPON"]       = { 16 },
    ["INVTYPE_WEAPONMAINHAND"] = { 16 },
    ["INVTYPE_WEAPONOFFHAND"]  = { 17 },
    ["INVTYPE_HOLDABLE"]       = { 17 },
    ["INVTYPE_RANGED"]         = { 18 },
    ["INVTYPE_RANGEDRIGHT"]    = { 18 },
    ["INVTYPE_TABARD"]         = { 19 },
}

-- Non-Equippable Item Types (classID from GetItemInfoInstant)
addon.ITEM_TYPES = {
    [0] = { name = "Consumables (Food/Potions)", enabled = false },   -- Consumable
    [1] = { name = "Containers (Bags)", enabled = false },            -- Container
    [3] = { name = "Gems", enabled = false },                         -- Gem (crafting)
    [5] = { name = "Reagents (Crafting Materials)", enabled = false },-- Reagent
    [7] = { name = "Trade Goods (Vellums, Mats)", enabled = false },  -- Tradeskill
    [9] = { name = "Recipes", enabled = false },                      -- Recipe
    [12] = { name = "Quest Items", enabled = false },                 -- Quest
    [13] = { name = "Keys", enabled = false },                        -- Key
    [15] = { name = "Miscellaneous", enabled = false },               -- Miscellaneous
}

-- Bind Types for filtering
addon.BIND_TYPES = {
    bop = { name = "Bind on Pickup (Soulbound)", enabled = true },
    boe = { name = "Bind on Equip (Bound)", enabled = false },
    unbound = { name = "Not Bound (Food, Reagents)", enabled = false },
}

-- Item Source Types for filtering
-- Allows filtering by where items came from (dungeons, raids, professions, etc.)
addon.ITEM_SOURCES = {
    consumable = { name = "Consumables (Food, Potions, Oils)", enabled = false },
    dungeon = { name = "Dungeons", enabled = false },
    raid = { name = "Raids", enabled = false },
    outdoor = { name = "Outdoor/World (Quests, World Drops)", enabled = false },
    profession = { name = "Professions (Crafted)", enabled = false },
    vendor = { name = "Vendors (Purchased from NPCs)", enabled = false },
    pvp = { name = "PvP (Battlegrounds, Arena)", enabled = false },
    reputation = { name = "Reputation Rewards", enabled = false },
    housing = { name = "Housing/Delves", enabled = false },
    unknown = { name = "Unknown/Other", enabled = false },
}

local function CreateDefaultExpansionProfile()
    local profile = {
        useDetailedFilters = false,
        filterBySource = false,
        onlySellLowerIlvl = false,
        bindTypes = {
            bop = addon.BIND_TYPES.bop.enabled,
            boe = addon.BIND_TYPES.boe.enabled,
            unbound = addon.BIND_TYPES.unbound.enabled,
        },
        rarities = {},
        equipSlots = {},
        itemTypes = {},
        itemSources = {},
    }
    for rarityID, rarityData in pairs(addon.RARITIES) do
        profile.rarities[rarityID] = rarityData.enabled
    end
    for slotKey, slotData in pairs(addon.EQUIP_SLOTS) do
        profile.equipSlots[slotKey] = slotData.enabled
    end
    for typeID, typeData in pairs(addon.ITEM_TYPES) do
        profile.itemTypes[typeID] = typeData.enabled
    end
    for sourceKey, sourceData in pairs(addon.ITEM_SOURCES) do
        profile.itemSources[sourceKey] = sourceData.enabled
    end
    return profile
end

-- Default settings
local defaults = {
    enabled = true,
    autoSell = false,  -- Manual mode by default (safer with API restrictions)
    showSummary = true,
    confirmSell = true, -- Confirm by default for safety
    maxSellPerVisit = 50,
    sellGray = true,
    sellBoP = true,      -- Sell Bind on Pickup items
    sellBoE = false,     -- Sell Bind on Equip items (that are bound)
    sellUnbound = false, -- Sell unbound items (food, reagents, etc.)
    expansions = {},
    rarities = {},
    equipSlots = {},
    itemTypes = {},
    excludedItems = {},
    minItemLevel = 0,
    debug = false,
    sellDelay = 0.2, -- Delay between sells to avoid throttling
    itemSources = {}, -- Source filter settings (vendor, crafted, dropped, etc.)
    filterBySource = false, -- Whether to apply source filtering at all
    highlightItems = true, -- Highlight sellable items in bags
    highlightColor = { r = 1, g = 0.2, b = 0.2, a = 0.8 }, -- Red glow by default
    onlySellLowerIlvl = false, -- Only sell equippable items whose ilvl is lower than the currently equipped item
    strictSeasonalProtection = true, -- Hard-protect current-season scaled legacy dungeon items
    expansionSellAllMode = true, -- Checked expansions sell everything from that expansion
    sellMode = "everything", -- "everything" | "matching" — single source of truth for sell mode
    expansionProfiles = {}, -- Per-expansion nested filter profiles
}

-- Initialize default expansion settings
for expID, expData in pairs(addon.EXPANSIONS) do
    defaults.expansions[expID] = expData.enabled
end

-- Initialize default rarity settings
for rarityID, rarityData in pairs(addon.RARITIES) do
    defaults.rarities[rarityID] = rarityData.enabled
end

-- Initialize default equipment slot settings
for slotKey, slotData in pairs(addon.EQUIP_SLOTS) do
    defaults.equipSlots[slotKey] = slotData.enabled
end

-- Initialize default item type settings
for typeID, typeData in pairs(addon.ITEM_TYPES) do
    defaults.itemTypes[typeID] = typeData.enabled
end

-- Initialize default item source settings
for sourceKey, sourceData in pairs(addon.ITEM_SOURCES) do
    defaults.itemSources[sourceKey] = sourceData.enabled
end

for expID, _ in pairs(addon.EXPANSIONS) do
    defaults.expansionProfiles[expID] = CreateDefaultExpansionProfile()
end

-- Local references for performance
local C_Container = C_Container
local C_Item = C_Item
local GetItemInfo = C_Item.GetItemInfo or GetItemInfo
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo

-- Frame for event handling
local frame = CreateFrame("Frame", "LegacyVendorFrame")
addon.frame = frame

-- Variables
local isSelling = false
local itemsToSell = {}
local totalGoldEarned = 0
local itemsSoldCount = 0

-- Debug print function
local function DebugPrint(...)
    if LegacyVendorDB and LegacyVendorDB.debug then
        print("|cFF00FF00[LegacyVendor Debug]|r", ...)
    end
end

-- Print function
local function Print(...)
    print("|cFF00CCFF[LegacyVendor]|r", ...)
end

addon.Print = Print
addon.DebugPrint = DebugPrint

local function EnsureExpansionProfiles(db)
    if not db.expansionProfiles then
        db.expansionProfiles = {}
    end

    local maxExp = addon.MAX_EXPANSION or addon.CURRENT_EXPANSION
    for expID, _ in pairs(addon.EXPANSIONS) do
        if expID <= maxExp and not db.expansionProfiles[expID] then
            local profile = CreateDefaultExpansionProfile()
            profile.bindTypes.bop = db.sellBoP
            profile.bindTypes.boe = db.sellBoE
            profile.bindTypes.unbound = db.sellUnbound
            profile.filterBySource = db.filterBySource
            profile.onlySellLowerIlvl = db.onlySellLowerIlvl

            for rarityID, enabled in pairs(db.rarities or {}) do
                profile.rarities[rarityID] = enabled
            end
            for slotKey, enabled in pairs(db.equipSlots or {}) do
                profile.equipSlots[slotKey] = enabled
            end
            for typeID, enabled in pairs(db.itemTypes or {}) do
                profile.itemTypes[typeID] = enabled
            end
            for sourceKey, enabled in pairs(db.itemSources or {}) do
                profile.itemSources[sourceKey] = enabled
            end

            db.expansionProfiles[expID] = profile
        end
    end
end

addon.CreateDefaultExpansionProfile = CreateDefaultExpansionProfile
addon.EnsureExpansionProfiles = EnsureExpansionProfiles

-- Get expansion ID from item (uses compat layer if available)
local function GetItemExpansionID(itemID)
    if not itemID then return nil end
    
    -- Use compatibility function if available (handles Classic/Retail differences)
    if addon.GetItemExpansionCompat then
        return addon.GetItemExpansionCompat(itemID)
    end
    
    -- Fallback for Retail
    local itemInfo
    if C_Item and C_Item.GetItemInfo then
        itemInfo = { C_Item.GetItemInfo(itemID) }
    else
        itemInfo = { GetItemInfo(itemID) }
    end
    
    if not itemInfo or not itemInfo[1] then return nil end
    
    -- itemInfo[15] is the expansion ID in retail WoW
    local expansionID = itemInfo[15]
    
    -- Fallback: estimate expansion from item level if expansion ID not available
    if not expansionID then
        local itemLevel = itemInfo[4] or 0
        if itemLevel <= 66 then expansionID = 0        -- Classic
        elseif itemLevel <= 164 then expansionID = 1   -- TBC
        elseif itemLevel <= 284 then expansionID = 2   -- WotLK
        elseif itemLevel <= 416 then expansionID = 3   -- Cataclysm
        elseif itemLevel <= 616 then expansionID = 4   -- MoP
        elseif itemLevel <= 750 then expansionID = 5   -- WoD
        elseif itemLevel <= 1000 then expansionID = 6  -- Legion
        elseif itemLevel <= 475 then expansionID = 7   -- BfA (scaled)
        elseif itemLevel <= 252 then expansionID = 8   -- Shadowlands (scaled)
        elseif itemLevel <= 528 then expansionID = 9   -- Dragonflight
        elseif itemLevel <= 680 then expansionID = 10  -- The War Within
        else expansionID = 11                          -- Midnight
        end
    end
    
    return expansionID
end

-- Get item bind status - returns: "bop", "boe", "unbound", or nil
local function GetItemBindStatus(bag, slot, itemID)
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not itemLocation:IsValid() then return nil end
    
    -- Check if item is currently bound
    local isBound = C_Item.IsBound(itemLocation)
    
    -- Get item's original binding type from item info
    local bindType
    if C_Item.GetItemInfo then
        local info = { C_Item.GetItemInfo(itemID) }
        bindType = info[14] -- Bind type: 1 = BoP, 2 = BoE, 3 = BoU, 4 = Quest, 0 or nil = no bind
    else
        local _, _, _, _, _, _, _, _, _, _, _, _, _, itemBindType = GetItemInfo(itemID)
        bindType = itemBindType
    end
    
    -- Determine status
    if not isBound then
        return "unbound"  -- Item is not bound (food, reagents, etc.)
    elseif bindType == 1 then
        return "bop"      -- Bind on Pickup
    elseif bindType == 2 then
        return "boe"      -- Bind on Equip (but currently bound)
    elseif bindType == 3 then
        return "bou"      -- Bind on Use
    elseif bindType == 4 then
        return "quest"    -- Quest item
    else
        return "unbound"  -- No bind type info, treat as unbound
    end
end

-- Get item source type - returns: "consumable", "dungeon", "raid", "outdoor", "profession", "vendor", "pvp", "reputation", "housing", "unknown"
-- Uses C_ItemSourceInfo API on Retail, falls back to heuristics on Classic
local function GetItemSource(itemID, bag, slot)
    if not itemID then return "unknown" end

    local itemInfo
    if C_Item.GetItemInfo then
        itemInfo = { C_Item.GetItemInfo(itemID) }
    else
        itemInfo = { GetItemInfo(itemID) }
    end

    -- Consumables are treated as their own source bucket regardless of where they dropped.
    -- This prevents dungeon-source filtering from sweeping up food/potions/oils.
    local classID = itemInfo and itemInfo[12]
    if classID == 0 then
        return "consumable"
    end
    
    -- Try to use Retail's C_ItemSourceInfo API first (most accurate)
    if C_ItemSourceInfo and C_ItemSourceInfo.GetItemSourceInfo then
        local sourceInfo = C_ItemSourceInfo.GetItemSourceInfo(itemID)
        if sourceInfo and sourceInfo.sourceType then
            -- Map Blizzard source types to our categories
            -- Source types: 1=Drop, 2=Vendor, 3=Quest, 4=Profession, 5=Achievement, etc.
            local sourceType = sourceInfo.sourceType
            
            if sourceType == 1 then
                -- Drop - need to check if it's dungeon, raid, or outdoor
                if sourceInfo.encounterID or sourceInfo.instanceID then
                    -- Check instance type
                    if sourceInfo.difficultyID then
                        local diffName = GetDifficultyInfo and GetDifficultyInfo(sourceInfo.difficultyID)
                        if diffName and (diffName:find("Raid") or diffName:find("raid")) then
                            return "raid"
                        end
                    end
                    return "dungeon"
                end
                return "outdoor"
            elseif sourceType == 2 then
                return "vendor"
            elseif sourceType == 3 then
                return "outdoor" -- Quest rewards go to outdoor/world
            elseif sourceType == 4 then
                return "profession"
            elseif sourceType == 5 then
                return "outdoor" -- Achievement rewards
            end
        end
    end
    
    -- Alternative: Try tooltip scanning for "Made by" (crafted items)
    local tooltipData
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        tooltipData = C_TooltipInfo.GetBagItem(bag, slot)
        if tooltipData and tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                local text = line.leftText or ""
                if text:find("Made by") or text:find("Crafted by") then
                    return "profession"
                end
                if text:find("Vendor") or text:find("Purchased") then
                    return "vendor"
                end
                if text:find("PvP") or text:find("Arena") or text:find("Battleground") or text:find("Honor") or text:find("Conquest") then
                    return "pvp"
                end
                if text:find("Reputation") or text:find("Exalted") or text:find("Revered") then
                    return "reputation"
                end
                if text:find("Delve") or text:find("Housing") then
                    return "housing"
                end
            end
        end
    end
    
    -- Fallback: Use item info heuristics
    if itemInfo and itemInfo[1] then
        local itemName = itemInfo[1]
        local subClassID = itemInfo[13]
        
        -- classID 7 = Tradeskill (crafting materials are often crafted)
        -- Check recipe-created items
        if classID == 7 then
            return "profession"
        end
        
        -- Check item name patterns (localization-dependent, but helpful)
        if itemName then
            -- PvP gear patterns
            if itemName:find("Gladiator") or itemName:find("Combatant") or itemName:find("Aspirant") then
                return "pvp"
            end
            -- Housing/Delve patterns (TWW+)
            if itemName:find("Delver") or itemName:find("Coffer") then
                return "housing"
            end
        end
    end
    
    -- Default to unknown if we can't determine source
    return "unknown"
end

-- Legacy function for backwards compatibility
local function IsBindOnPickup(bag, slot)
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not itemLocation:IsValid() then return false end
    local itemID = C_Item.GetItemID(itemLocation)
    if not itemID then return false end
    return GetItemBindStatus(bag, slot, itemID) == "bop"
end

-- Returns true if an item appears to be current-season scaled gear from a legacy
-- dungeon and should be hard-protected from vendor selling.
local function IsCurrentSeasonLegacyItem(itemID, itemLink, expansionID, baseItemLevel, classID, equipLoc, bag, slot)
    if not itemID or not itemLink or not expansionID then
        return false
    end

    -- Only legacy expansions can be seasonal legacy dungeon candidates.
    if expansionID >= addon.CURRENT_EXPANSION then
        return false
    end

    -- Strict seasonal guard is only for dungeon gear, not consumables.
    local isEquipment = equipLoc and equipLoc ~= ""
    if not isEquipment and classID ~= 2 and classID ~= 4 then
        return false
    end

    local sourceBucket = GetItemSource(itemID, bag, slot)
    if sourceBucket ~= "dungeon" and sourceBucket ~= "raid" then
        return false
    end

    -- Signal 1: explicit instance allowlist for current seasonal rotation.
    if C_ItemSourceInfo and C_ItemSourceInfo.GetItemSourceInfo then
        local sourceInfo = C_ItemSourceInfo.GetItemSourceInfo(itemID)
        if sourceInfo and sourceInfo.instanceID then
            DebugPrint("Item source instanceID:", sourceInfo.instanceID, "for", itemLink)
            if addon.SEASONAL_LEGACY_DUNGEON_INSTANCES[sourceInfo.instanceID] then
                return true
            end
        end
    end

    local effectiveIlvl = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(itemLink)
    if not effectiveIlvl then
        return false
    end

    -- Signal 2: expansion-specific ilvl ceiling (safe for most legacy expansions).
    local ilvlCeiling = addon.EXPANSION_ILVL_CEILING[expansionID]
    if ilvlCeiling and effectiveIlvl > ilvlCeiling then
        return true
    end

    -- Signal 3: large scaling delta between base and effective item level.
    -- Current-season scaling bonuses typically create a large gap.
    if baseItemLevel and baseItemLevel > 0 and (effectiveIlvl - baseItemLevel) >= 120 then
        return true
    end

    -- Signal 4: conservative hard floor for modern-season ilvl.
    -- Skip WoD/Legion here because pre-squish item levels can be unusually high.
    local hardFloor = addon.STRICT_SEASONAL_ILVL_FLOOR
    if hardFloor and expansionID ~= 5 and expansionID ~= 6 and effectiveIlvl >= hardFloor then
        return true
    end

    return false
end

-- Returns the expansion bucket used for filtering.
-- Current-season legacy dungeon gear can optionally be treated as current expansion.
local function GetFilterExpansionID(itemID, itemLink, expansionID, baseItemLevel, classID, equipLoc, bag, slot)
    if not expansionID then
        return nil
    end

    if LegacyVendorDB and LegacyVendorDB.sellMode == "everything" then
        if IsCurrentSeasonLegacyItem(itemID, itemLink, expansionID, baseItemLevel, classID, equipLoc, bag, slot) then
            return addon.CURRENT_EXPANSION
        end
    end

    return expansionID
end

-- Check if item should be sold
local function ShouldSellItem(bag, slot)
    local db = LegacyVendorDB
    if not db.enabled then return false end
    
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not itemLocation:IsValid() then return false end
    
    local itemID = C_Item.GetItemID(itemLocation)
    if not itemID then return false end
    
    -- Check if item is excluded
    if db.excludedItems[itemID] then
        DebugPrint("Item excluded:", itemID)
        return false
    end
    
    -- Get item info using modern API
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
    if not containerInfo then return false end
    
    local itemLink = containerInfo.hyperlink
    local quality = containerInfo.quality
    local isLocked = containerInfo.isLocked
    local itemCount = containerInfo.stackCount
    
    -- Don't sell locked items
    if isLocked then return false end
    
    -- Get detailed item info
    local itemInfo
    if C_Item.GetItemInfo then
        itemInfo = { C_Item.GetItemInfo(itemID) }
    else
        itemInfo = { GetItemInfo(itemID) }
    end
    
    if not itemInfo[1] then return false end
    
    local itemName = itemInfo[1]
    local itemType = itemInfo[6]        -- Item type string
    local itemSubType = itemInfo[7]     -- Item subtype string
    local equipLoc = itemInfo[9]        -- Equipment location (INVTYPE_HEAD, etc.)
    local sellPrice = itemInfo[11]
    local classID = itemInfo[12]        -- Item class ID (Armor, Weapon, Consumable, etc.)
    local subClassID = itemInfo[13]     -- Item subclass ID

    local expansionID = GetItemExpansionID(itemID)
    if not expansionID then
        DebugPrint("Could not determine expansion:", itemLink)
        return false
    end

    local filterExpansionID = GetFilterExpansionID(itemID, itemLink, expansionID, itemInfo[4], classID, equipLoc, bag, slot)
    if not filterExpansionID then
        DebugPrint("Could not determine filter expansion:", itemLink)
        return false
    end

    -- === STRICT SEASONAL PROTECTION (hard stop) ===
    -- When enabled, this check runs before every other sell filter and immediately
    -- blocks current-season scaled legacy dungeon gear.
    if db.strictSeasonalProtection ~= false then
        if IsCurrentSeasonLegacyItem(itemID, itemLink, expansionID, itemInfo[4], classID, equipLoc, bag, slot) then
            -- Explicit opt-in: if current expansion is checked in meta sell-all mode,
            -- allow current-season dungeon items to flow through as current expansion.
            if not (db.sellMode == "everything" and db.expansions and db.expansions[addon.CURRENT_EXPANSION]) then
                DebugPrint("Strict protection: skipping seasonal legacy item:", itemLink)
                return false
            end
        end
    end
    
    -- No sell price = can't sell
    if not sellPrice or sellPrice == 0 then 
        DebugPrint("No sell price:", itemLink)
        return false 
    end
    
    -- Special handling for gray items - bypass most filters if sellGray is enabled
    if db.sellGray and quality == 0 then
        DebugPrint("Selling gray item:", itemLink)
        return true, itemLink, itemCount, sellPrice * itemCount
    end
    
    -- === FILTER 1: EXPANSION ===
    if not db.expansions[filterExpansionID] then
        DebugPrint("Expansion disabled:", filterExpansionID, itemLink)
        return false
    end

    -- Resolve against filterExpansionID (which GetFilterExpansionID may have redirected,
    -- e.g. a current-season item remapped to CURRENT_EXPANSION), not the raw expansionID.
    local resolved = addon.ResolveActiveFilters(db, filterExpansionID)
    local activeRarities = resolved.rarities
    local activeBindTypes = resolved.bindTypes
    local activeEquipSlots = resolved.equipSlots
    local activeItemTypes = resolved.itemTypes
    local activeOnlyLowerIlvl = resolved.onlyLowerIlvl

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

    -- "Everything" mode: sell all legacy items from enabled expansions.
    -- Detailed filters (including source) intentionally do NOT apply here.
    if db.sellMode == "everything" then
        DebugPrint("Meta expansion sell-all matched:", filterExpansionID, itemLink)
        return true, itemLink, itemCount, sellPrice * itemCount
    end

    -- === FILTER 2: RARITY (Quality) ===
    if activeRarities and activeRarities[quality] ~= nil then
        if not activeRarities[quality] then
            DebugPrint("Rarity not enabled:", quality, itemLink)
            return false
        end
    end

    -- === FILTER 3: BIND STATUS ===
    local bindStatus = GetItemBindStatus(bag, slot, itemID)
    DebugPrint("Bind status for", itemLink, ":", bindStatus or "nil")

    local bindAllowed = false
    if bindStatus == "bop" and activeBindTypes.bop then
        bindAllowed = true
    elseif bindStatus == "boe" and activeBindTypes.boe then
        bindAllowed = true
    elseif bindStatus == "unbound" and activeBindTypes.unbound then
        bindAllowed = true
    elseif bindStatus == "bou" and activeBindTypes.unbound then
        bindAllowed = true
    end

    if not bindAllowed then
        DebugPrint("Bind type not enabled:", bindStatus, itemLink)
        return false
    end
    
    -- === FILTER 4: EQUIPMENT SLOTS (for equippable items) ===
    local isEquipment = equipLoc and equipLoc ~= ""
    
    if isEquipment then
        -- Check if this equipment slot is enabled
        if activeEquipSlots and activeEquipSlots[equipLoc] ~= nil then
            if not activeEquipSlots[equipLoc] then
                DebugPrint("Equipment slot not enabled:", equipLoc, itemLink)
                return false
            end
        end
    end
    
    -- === FILTER 5: ITEM TYPES (for non-equippable items) ===
    if not isEquipment then
        -- Consumables are controlled via source filters + bind filters to avoid duplicate controls.
        if classID ~= 0 and activeItemTypes and classID and activeItemTypes[classID] ~= nil then
            if not activeItemTypes[classID] then
                DebugPrint("Item type not enabled:", classID, "(class ID)", itemLink)
                return false
            end
        elseif classID and classID ~= 0 and classID ~= 2 and classID ~= 4 then
            -- Non-equippable item with unrecognized classID — skip by default.
            -- classID 2 = Weapon and 4 = Armor are handled by equipment slot filters.
            DebugPrint("Unrecognized non-equipment item type, skipping:", classID, itemLink)
            return false
        end
    end
    
    -- Check minimum item level
    local itemLevel = itemInfo[4] or 0
    if itemLevel < db.minItemLevel then
        DebugPrint("Below min item level:", itemLink)
        return false
    end

    -- === FILTER 6: ONLY SELL IF LOWER ILVL THAN EQUIPPED ===
    if activeOnlyLowerIlvl and isEquipment then
        local slotIDs = addon.EQUIP_LOC_TO_SLOT[equipLoc]
        if slotIDs then
            local dominated = false
            for _, invSlotID in ipairs(slotIDs) do
                local equippedLink = GetInventoryItemLink("player", invSlotID)
                if equippedLink then
                    local equippedIlvl
                    if GetDetailedItemLevelInfo then
                        equippedIlvl = GetDetailedItemLevelInfo(equippedLink)
                    end
                    if not equippedIlvl then
                        -- Fallback: parse from GetItemInfo
                        local eInfo = { GetItemInfo(equippedLink) }
                        equippedIlvl = eInfo[4] or 0
                    end
                    if itemLevel < equippedIlvl then
                        dominated = true
                        break
                    end
                else
                    -- Nothing equipped in this slot; bag item is better by default
                    dominated = false
                    break
                end
            end
            if not dominated then
                DebugPrint("Item level not lower than equipped, skipping:", itemLink, "(", itemLevel, ")")
                return false
            end
        end
    end
    
    -- === FILTER 7: ITEM SOURCE (skip-list) ===
    -- In "matching" mode, items whose source is in the skip-set (via addon.SourceSkipped)
    -- are never sold; leaving the skip-set empty allows every source.
    if not PassesSourceFilter() then
        return false
    end
    
    DebugPrint("Will sell:", itemLink, "Expansion:", filterExpansionID, "Quality:", quality, "Bind:", bindStatus, "Class:", classID)
    return true, itemLink, itemCount, sellPrice * itemCount
end

-- Scan bags for items to sell
local function ScanBags()
    itemsToSell = {}
    totalGoldEarned = 0
    
    -- NUM_BAG_SLOTS is typically 4, plus bag 0 (backpack)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local shouldSell, itemLink, count, price = ShouldSellItem(bag, slot)
            if shouldSell then
                table.insert(itemsToSell, {
                    bag = bag,
                    slot = slot,
                    link = itemLink,
                    count = count,
                    price = price or 0
                })
                totalGoldEarned = totalGoldEarned + (price or 0)
                
                -- Respect max sell limit
                if #itemsToSell >= LegacyVendorDB.maxSellPerVisit then
                    break
                end
            end
        end
        if #itemsToSell >= LegacyVendorDB.maxSellPerVisit then
            break
        end
    end
    
    return itemsToSell
end

-- ==========================================
-- BAG ITEM HIGHLIGHTING
-- ==========================================

local activeBagHighlights = {}
local highlightUpdatePending = false
local highlightRetryCount = 0
local highlightRetryToken = 0

local function StartHighlightRetries()
    highlightRetryToken = highlightRetryToken + 1
    highlightRetryCount = 0
    local myToken = highlightRetryToken

    local function Tick()
        if myToken ~= highlightRetryToken then
            return
        end
        if not LegacyVendorDB or not LegacyVendorDB.enabled or not LegacyVendorDB.highlightItems then
            return
        end
        if not MerchantFrame or not MerchantFrame:IsShown() then
            return
        end

        if addon and addon.ScheduleHighlightUpdate then
            addon.ScheduleHighlightUpdate()
        end

        highlightRetryCount = highlightRetryCount + 1
        if highlightRetryCount < 12 then
            C_Timer.After(0.25, Tick)
        end
    end

    Tick()
end

local function StopHighlightRetries()
    highlightRetryToken = highlightRetryToken + 1
    highlightRetryCount = 0
end

local function ClearBagHighlights()
    for button, hl in pairs(activeBagHighlights) do
        if hl and hl.driver then
            hl.driver:SetScript("OnUpdate", nil)
        end
        if hl and hl.ants then
            for _, ant in ipairs(hl.ants) do
                ant:Hide()
            end
        end
        if hl and hl.fill then
            hl.fill:Hide()
        end
        if hl and hl.border and hl.border.SetVertexColor then
            if hl.borderOrigColor then
                hl.border:SetVertexColor(hl.borderOrigColor.r, hl.borderOrigColor.g, hl.borderOrigColor.b, hl.borderOrigColor.a)
            else
                hl.border:SetVertexColor(1, 1, 1, 1)
            end
            if hl.borderOrigShown == false and hl.border.Hide then
                hl.border:Hide()
            end
        end
        if hl and hl.icon and hl.icon.SetVertexColor then
            if hl.iconOrigColor then
                hl.icon:SetVertexColor(hl.iconOrigColor.r, hl.iconOrigColor.g, hl.iconOrigColor.b, hl.iconOrigColor.a)
            else
                hl.icon:SetVertexColor(1, 1, 1, 1)
            end
            if hl.iconOrigDesaturated ~= nil and hl.icon.SetDesaturated then
                hl.icon:SetDesaturated(hl.iconOrigDesaturated)
            end
        end
    end
    wipe(activeBagHighlights)
end

local function GetButtonBagAndSlot(button)
    if not button then
        return nil, nil
    end

    local bag = nil
    local slot = nil

    if button.GetBagID then
        bag = button:GetBagID()
    end
    if not bag and button.bagID ~= nil then
        bag = button.bagID
    end
    if bag == nil and button.BagID ~= nil then
        bag = button.BagID
    end
    if bag == nil and button.bag ~= nil then
        bag = button.bag
    end
    if bag == nil and button.GetSlotAndBagID then
        local _, b = button:GetSlotAndBagID()
        bag = b
    end
    if bag == nil and button.GetAttribute then
        bag = button:GetAttribute("bag")
            or button:GetAttribute("bagID")
            or button:GetAttribute("bagid")
    end

    slot = button:GetID()
    if (not slot or slot == 0) and button.GetSlotAndBagID then
        local s = button:GetSlotAndBagID()
        slot = s
    end
    if (not slot or slot == 0) and button.slotID ~= nil then
        slot = button.slotID
    end
    if (not slot or slot == 0) and button.SlotID ~= nil then
        slot = button.SlotID
    end
    if (not slot or slot == 0) and button.slot ~= nil then
        slot = button.slot
    end
    if (not slot or slot == 0) and button.slotIndex ~= nil then
        slot = button.slotIndex
    end
    if (slot == nil or slot == 0) and button.GetAttribute then
        slot = button:GetAttribute("slot")
            or button:GetAttribute("slotID")
            or button:GetAttribute("slotid")
    end

    if (bag == nil or slot == nil or slot == 0) then
        local itemLocation = nil
        if button.GetItemLocation then
            itemLocation = button:GetItemLocation()
        elseif button.itemLocation then
            itemLocation = button.itemLocation
        end
        if itemLocation then
            if itemLocation.GetBagAndSlot then
                local b, s = itemLocation:GetBagAndSlot()
                if bag == nil then bag = b end
                if slot == nil or slot == 0 then slot = s end
            else
                if bag == nil then
                    bag = itemLocation.bagID or itemLocation.bag
                end
                if slot == nil or slot == 0 then
                    slot = itemLocation.slotID or itemLocation.slotIndex or itemLocation.slot
                end
            end
        end
    end

    return tonumber(bag), tonumber(slot)
end

local function LayoutMarchingAnts(button, hl, phase, count)
    local w = (button:GetWidth() or 36) + 8
    local h = (button:GetHeight() or 36) + 8
    local halfW = w * 0.5
    local halfH = h * 0.5
    local perimeter = (2 * w) + (2 * h)

    for i = 1, count do
        local ant = hl.ants[i]
        local t = ((i - 1) / count) + phase
        t = t - math.floor(t)
        local d = t * perimeter
        local x, y

        if d < w then
            x = -halfW + d
            y = halfH
        elseif d < (w + h) then
            x = halfW
            y = halfH - (d - w)
        elseif d < (2 * w + h) then
            x = halfW - (d - (w + h))
            y = -halfH
        else
            x = -halfW
            y = -halfH + (d - (2 * w + h))
        end

        ant:ClearAllPoints()
        ant:SetPoint("CENTER", button, "CENTER", x, y)
    end
end

local function IsLikelyItemButton(button)
    if not button then
        return false
    end

    if button.GetItemLocation or button.SlotID ~= nil or button.slotID ~= nil or button.BagID ~= nil or button.bagID ~= nil then
        return true
    end

    if button.Icon or button.icon or button.Count or button.Cooldown or button.IconBorder then
        return true
    end

    local name = button.GetName and button:GetName()
    if type(name) == "string" and name:find("Item", 1, true) then
        return true
    end

    return false
end

local function ApplyHighlight(button)
    if not button then
        return
    end

    if not IsLikelyItemButton(button) then
        return
    end

    local hl = button.LegacyVendorHighlight
    if not hl then
        hl = {}

        -- Use a dedicated host frame above the item button so skin overlays (ElvUI/WindTools)
        -- do not hide our highlight textures.
        hl.host = CreateFrame("Frame", nil, button)
        local iconRegion = button.Icon or button.icon
        if iconRegion then
            hl.host:SetPoint("TOPLEFT", iconRegion, "TOPLEFT", -1, 1)
            hl.host:SetPoint("BOTTOMRIGHT", iconRegion, "BOTTOMRIGHT", 1, -1)
        else
            hl.host:SetAllPoints(button)
        end
        hl.host:SetFrameStrata("TOOLTIP")
        local baseLevel = (button.GetFrameLevel and button:GetFrameLevel()) or 1
        hl.host:SetFrameLevel(baseLevel + 20)
        hl.host:EnableMouse(false)
        if hl.host.SetIgnoreParentAlpha then
            hl.host:SetIgnoreParentAlpha(true)
        end

        hl.fill = hl.host:CreateTexture(nil, "OVERLAY")
        hl.fill:SetPoint("TOPLEFT", hl.host, "TOPLEFT", 0, 0)
        hl.fill:SetPoint("BOTTOMRIGHT", hl.host, "BOTTOMRIGHT", 0, 0)
        hl.fill:SetBlendMode("ADD")

        hl.ants = {}
        local antCount = 34
        hl.antCount = antCount
        for i = 1, antCount do
            local ant = hl.host:CreateTexture(nil, "OVERLAY")
            ant:SetSize(3, 3)
            ant:SetTexture("Interface\\Buttons\\WHITE8X8")
            ant:SetBlendMode("ADD")
            hl.ants[i] = ant
        end

        hl.driver = CreateFrame("Frame", nil, hl.host)
        hl.phase = 0
        hl.accum = 0

        hl.border = button.IconBorder or button.iconBorder
        if hl.border and hl.border.GetVertexColor then
            local br, bg, bb, ba = hl.border:GetVertexColor()
            hl.borderOrigColor = { r = br or 1, g = bg or 1, b = bb or 1, a = ba or 1 }
            hl.borderOrigShown = hl.border.IsShown and hl.border:IsShown() or nil
        end

        hl.icon = button.Icon or button.icon
        if hl.icon and hl.icon.GetVertexColor then
            local ir, ig, ib, ia = hl.icon:GetVertexColor()
            hl.iconOrigColor = { r = ir or 1, g = ig or 1, b = ib or 1, a = ia or 1 }
            if hl.icon.IsDesaturated then
                hl.iconOrigDesaturated = hl.icon:IsDesaturated()
            end
        end

        button.LegacyVendorHighlight = hl
    end

    local color = (LegacyVendorDB and LegacyVendorDB.highlightColor) or { r = 1, g = 0.2, b = 0.2, a = 0.8 }
    local r = color.r or 1
    local g = color.g or 0.2
    local b = color.b or 0.2
    local a = color.a or 0.8

    hl.fill:SetColorTexture(r, g, b, 0)

    for _, ant in ipairs(hl.ants) do
        ant:SetVertexColor(r, g, b, 1)
        ant:Show()
    end

    if hl.border and hl.border.SetVertexColor then
        if hl.borderOrigColor then
            hl.border:SetVertexColor(hl.borderOrigColor.r, hl.borderOrigColor.g, hl.borderOrigColor.b, hl.borderOrigColor.a)
        end
    end

    if hl.icon and hl.icon.SetVertexColor and hl.iconOrigColor then
        hl.icon:SetVertexColor(hl.iconOrigColor.r, hl.iconOrigColor.g, hl.iconOrigColor.b, hl.iconOrigColor.a)
    end

    hl.fill:Hide()

    LayoutMarchingAnts(hl.host, hl, hl.phase or 0, hl.antCount)
    hl.driver:SetScript("OnUpdate", function(_, elapsed)
        hl.accum = (hl.accum or 0) + elapsed
        if hl.accum < 0.03 then
            return
        end

        local dt = hl.accum
        hl.accum = 0
        hl.phase = ((hl.phase or 0) + (dt * 0.9)) % 1
        LayoutMarchingAnts(hl.host, hl, hl.phase, hl.antCount)
    end)

    activeBagHighlights[button] = hl
end

local function IsBagSlotMatch(foundBag, foundSlot, targetBag, targetSlot)
    if foundBag ~= targetBag then
        return false
    end
    return foundSlot == targetSlot or (foundSlot and (foundSlot + 1) == targetSlot)
end

local function IsAddonLoadedSafe(name)
    if not name then
        return false
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

local function IsValidButtonCandidate(button, bag, slot)
    if not IsLikelyItemButton(button) then
        return false
    end

    local b, s = GetButtonBagAndSlot(button)
    if not IsBagSlotMatch(b, s, bag, slot) then
        return false
    end

    -- If both expose item links, ensure it is the exact bag-slot item.
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local slotLink = info and info.hyperlink
    if slotLink then
        local buttonLink = button.itemLink or button.link or button.ItemLink or button.hyperlink
        if buttonLink and buttonLink ~= slotLink then
            return false
        end
    end

    return true
end

local function FindElvUIBagButtonForBagSlot(bag, slot)
    if not (IsAddonLoadedSafe("ElvUI") and ElvUI and ElvUI[1]) then
        return nil
    end

    local E = ElvUI[1]
    if not (E and E.GetModule) then
        return nil
    end

    local Bags = E:GetModule("Bags", true)
    if not Bags then
        return nil
    end

    local function ScanElvFrame(frame)
        if not (frame and frame.Bags) then
            return nil
        end

        local bagTable = frame.Bags[bag]
        if type(bagTable) == "table" then
            local direct = bagTable[slot]
            if direct then
                return direct
            end

            for _, btn in pairs(bagTable) do
                if type(btn) == "table" and btn.GetObjectType then
                    local b, s = GetButtonBagAndSlot(btn)
                    if IsBagSlotMatch(b, s, bag, slot) then
                        return btn
                    end
                end
            end
        end

        return nil
    end

    return ScanElvFrame(Bags.BagFrame) or ScanElvFrame(Bags.BankFrame)
end

local function FindButtonForBagSlot(bag, slot)
    local candidates = {}
    local seen = {}
    local isElvUILoaded = IsAddonLoadedSafe("ElvUI")

    local function AddCandidate(button, source)
        if not button or seen[button] then
            return
        end
        seen[button] = true

        if not IsValidButtonCandidate(button, bag, slot) then
            return
        end

        local shown = (button.IsShown and button:IsShown()) or (button.IsVisible and button:IsVisible())
        if not shown then
            return
        end

        local alpha = (button.GetEffectiveAlpha and button:GetEffectiveAlpha()) or 1
        if alpha <= 0.05 then
            return
        end

        local w = (button.GetWidth and button:GetWidth()) or 0
        local h = (button.GetHeight and button:GetHeight()) or 0
        if w < 8 or h < 8 then
            return
        end

        local cx, cy = button:GetCenter()
        if not cx or not cy then
            return
        end

        local score = 0
        local name = button.GetName and button:GetName() or ""
        local parent = button.GetParent and button:GetParent() or nil
        local parentName = (parent and parent.GetName and parent:GetName()) or ""

        if source == "elvui-table" then score = score + 80 end
        if source == "elvui-tree" then score = score + 55 end
        if source == "container-util" then score = score + 35 end
        if source == "global-enum" then score = score + 20 end
        if source == "legacy-name" then score = score + 10 end

        if name and name:find("ElvUI", 1, true) then score = score + 35 end
        if parentName and parentName:find("ElvUI", 1, true) then score = score + 20 end
        if button.BagID ~= nil or button.SlotID ~= nil then score = score + 20 end
        if button.Icon or button.icon then score = score + 10 end

        if isElvUILoaded and name and name:find("ContainerFrame", 1, true) then
            score = score - 40
        end

        score = score + (alpha * 10)
        score = score + (math.min(w, h) * 0.2)

        table.insert(candidates, { button = button, score = score })
    end

    -- Deterministic ElvUI path first.
    local elvButton = FindElvUIBagButtonForBagSlot(bag, slot)
    if elvButton then
        AddCandidate(elvButton, "elvui-table")
    end

    -- Retail helper for direct mapping.
    if ContainerFrameUtil_GetItemButtonAndContainer then
        local r1, r2 = ContainerFrameUtil_GetItemButtonAndContainer(bag, slot)
        AddCandidate(r1, "container-util")
        AddCandidate(r2, "container-util")
    end

    -- Modern bag frames using itemButtonPool.
    if ContainerFrameUtil_EnumerateContainerFrames then
        for containerFrame in ContainerFrameUtil_EnumerateContainerFrames() do
            if containerFrame and containerFrame.itemButtonPool and containerFrame.itemButtonPool.EnumerateActive then
                for button in containerFrame.itemButtonPool:EnumerateActive() do
                    AddCandidate(button, "container-util")
                end
            end
        end
    end

    -- ElvUI frame-tree fallback.
    if isElvUILoaded and ElvUI and ElvUI[1] then
        local E = ElvUI[1]
        if E and E.GetModule then
            local Bags = E:GetModule("Bags", true)
            if Bags and Bags.BagFrame then
                local visited = {}
                local function Visit(frame, depth)
                    if not frame or visited[frame] or depth > 6 then
                        return
                    end
                    visited[frame] = true
                    AddCandidate(frame, "elvui-tree")
                    local numChildren = frame.GetNumChildren and frame:GetNumChildren() or 0
                    if numChildren > 0 and frame.GetChildren then
                        local children = { frame:GetChildren() }
                        for _, child in ipairs(children) do
                            Visit(child, depth + 1)
                        end
                    end
                end
                Visit(Bags.BagFrame, 0)
            end
        end
    end

    -- Addon-agnostic frame enumeration.
    local frame = EnumerateFrames()
    while frame do
        if frame.GetObjectType then
            local objType = frame:GetObjectType()
            if objType == "Button" or objType == "CheckButton" or objType == "ItemButton" then
                AddCandidate(frame, "global-enum")
            end
        end
        frame = EnumerateFrames(frame)
    end

    -- Legacy name scan fallback.
    for name, obj in pairs(_G) do
        if type(name) == "string" and type(obj) == "table" and obj.GetID and obj.IsShown then
            if name:find("ContainerFrame") and name:find("Item") then
                AddCandidate(obj, "legacy-name")
            end
        end
    end

    if #candidates == 0 then
        return nil
    end

    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)

    return candidates[1].button
end

local function CollectButtonsFromBagFrame(frame, outButtons, seenButtons)
    if not (frame and frame.Bags and type(frame.Bags) == "table") then
        return 0
    end

    local count = 0
    for _, bagObj in pairs(frame.Bags) do
        if type(bagObj) == "table" then
            for _, btn in pairs(bagObj) do
                if type(btn) == "table" and btn.GetObjectType and not seenButtons[btn] then
                    seenButtons[btn] = true
                    table.insert(outButtons, btn)
                    count = count + 1
                end
            end
        end
    end

    return count
end

local function CollectCustomBagButtons()
    local buttons = {}
    local seen = {}
    local source = "none"
    local scanned = 0

    if IsAddonLoadedSafe("ElvUI") and ElvUI and ElvUI[1] then
        local E = ElvUI[1]
        local Bags = E and E.GetModule and E:GetModule("Bags", true)
        if Bags then
            scanned = scanned + CollectButtonsFromBagFrame(Bags.BagFrame, buttons, seen)
            scanned = scanned + CollectButtonsFromBagFrame(Bags.BankFrame, buttons, seen)
            if scanned > 0 then
                source = "elvui"
            end
        end
    end

    -- WindTools/custom wrappers may expose additional bag frame tables.
    if scanned == 0 then
        for name, obj in pairs(_G) do
            if type(name) == "string" and type(obj) == "table" and name:find("Bag", 1, true) and obj.Bags then
                scanned = scanned + CollectButtonsFromBagFrame(obj, buttons, seen)
            end
        end
        if scanned > 0 then
            source = "custom-bag-frame"
        end
    end

    return buttons, source, scanned
end

local UpdateBagHighlightsBody

local function UpdateBagHighlights()
    ClearBagHighlights()

    if LegacyVendorDB and LegacyVendorDB.debug then
        DebugPrint("UpdateBagHighlights: enter, enabled=", tostring(LegacyVendorDB and LegacyVendorDB.enabled),
            "highlightItems=", tostring(LegacyVendorDB and LegacyVendorDB.highlightItems),
            "merchantShown=", tostring(MerchantFrame and MerchantFrame:IsShown()))
    end

    if not LegacyVendorDB or not LegacyVendorDB.enabled or not LegacyVendorDB.highlightItems then
        return
    end

    if not MerchantFrame or not MerchantFrame:IsShown() then
        return
    end

    local ok, err = pcall(UpdateBagHighlightsBody)
    if not ok and LegacyVendorDB and LegacyVendorDB.debug then
        DebugPrint("UpdateBagHighlights: ERROR:", tostring(err))
    end
end

UpdateBagHighlightsBody = function()
    -- Custom UI direct path: evaluate custom bag slot buttons first (ElvUI, WindTools wrappers).
    local customButtons, customSource, customScanned = CollectCustomBagButtons()
    local customApplied = 0
    local fallbackApplied = 0
    local firstFallbackTargetLogged = false

    if LegacyVendorDB and LegacyVendorDB.debug then
        DebugPrint("Custom bag scan:", customSource, "scanned=", customScanned, "buttons=", #customButtons, "ElvUILoaded=", tostring(IsAddonLoadedSafe("ElvUI")), "WindToolsLoaded=", tostring(IsAddonLoadedSafe("ElvUI_WindTools")))
    end

    if #customButtons > 0 then
        for _, btn in ipairs(customButtons) do
            local b, s = GetButtonBagAndSlot(btn)
            if b ~= nil and s ~= nil and s > 0 then
                if IsValidButtonCandidate(btn, b, s) and ShouldSellItem(b, s) then
                    local shown = (btn.IsShown and btn:IsShown()) or (btn.IsVisible and btn:IsVisible())
                    if shown then
                        ApplyHighlight(btn)
                        customApplied = customApplied + 1
                    end
                end
            end
        end

        if LegacyVendorDB and LegacyVendorDB.debug then
            DebugPrint("Custom bag path:", customSource, "scanned=", customScanned, "applied=", customApplied, "ElvUILoaded=", tostring(IsAddonLoadedSafe("ElvUI")), "WindToolsLoaded=", tostring(IsAddonLoadedSafe("ElvUI_WindTools")))
        end

        if customApplied > 0 then
            return
        end
    end

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local shouldSell = ShouldSellItem(bag, slot)
            if shouldSell then
                local button = FindButtonForBagSlot(bag, slot)
                if LegacyVendorDB and LegacyVendorDB.debug and not firstFallbackTargetLogged then
                    local btnName = (button and button.GetName and button:GetName()) or "<anon>"
                    local btnType = (button and button.GetObjectType and button:GetObjectType()) or "<nil>"
                    local mb, ms = nil, nil
                    if button then
                        mb, ms = GetButtonBagAndSlot(button)
                    end
                    local hasIcon = button and (button.Icon or button.icon) and true or false
                    DebugPrint("First fallback target:", "slot=", bag, slot, "name=", tostring(btnName), "type=", tostring(btnType), "mapped=", tostring(mb), tostring(ms), "icon=", tostring(hasIcon))
                    firstFallbackTargetLogged = true
                end
                if button and ((button.IsShown and button:IsShown()) or (button.IsVisible and button:IsVisible())) then
                    ApplyHighlight(button)
                    fallbackApplied = fallbackApplied + 1
                end
            end
        end
    end

    if LegacyVendorDB and LegacyVendorDB.debug then
        DebugPrint("Fallback bag path applied=", fallbackApplied)
    end
end

local function ScheduleHighlightUpdate()
    if highlightUpdatePending then
        return
    end

    highlightUpdatePending = true
    C_Timer.After(0.05, function()
        highlightUpdatePending = false
        UpdateBagHighlights()
    end)
end

addon.UpdateBagHighlights = UpdateBagHighlights
addon.ScheduleHighlightUpdate = ScheduleHighlightUpdate

-- Format gold amount
local function FormatMoney(copper)
    if not copper or copper == 0 then return "0c" end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperLeft = copper % 100

    local result = ""
    if gold > 0 then result = result .. gold .. "g " end
    if silver > 0 then result = result .. silver .. "s " end
    if copperLeft > 0 or result == "" then result = result .. copperLeft .. "c" end

    return result:trim()
end

-- Sell next item in queue
local function SellNextItem()
    if not isSelling or #itemsToSell == 0 then
        isSelling = false
        if itemsSoldCount > 0 and LegacyVendorDB.showSummary then
            Print(string.format("Sold %d legacy item(s) for %s", itemsSoldCount, FormatMoney(totalGoldEarned)))
        elseif itemsSoldCount == 0 and LegacyVendorDB.showSummary then
            Print("No items were sold - items may have been moved or filters changed")
        end
        itemsSoldCount = 0
        totalGoldEarned = 0
        
        -- Update button to reflect new count
        if addon.UpdateMerchantButton then
            addon.UpdateMerchantButton()
        end
        return
    end
    
    -- Verify merchant is still open
    if not MerchantFrame or not MerchantFrame:IsShown() then
        isSelling = false
        Print("Merchant closed, stopping sale.")
        return
    end
    
    local item = table.remove(itemsToSell, 1)
    DebugPrint(string.format("Attempting to sell: %s (bag %d, slot %d)", item.link or "Unknown", item.bag, item.slot))
    
    -- Verify item is still there (using modern API)
    local containerInfo = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if containerInfo and containerInfo.hyperlink then
        DebugPrint("  Item verified in slot, selling...")
        -- Use the container API for selling
        -- This works when merchant window is open
        local success, err = pcall(function()
            C_Container.UseContainerItem(item.bag, item.slot)
        end)
        
        if success then
            itemsSoldCount = itemsSoldCount + 1
            DebugPrint("  Sold successfully!")
        else
            Print("  FAILED to sell: " .. (err or "unknown error"))
        end
    else
        DebugPrint("  Item no longer in slot, skipping")
    end
    
    -- Schedule next sell with delay to avoid API throttling
    local delay = LegacyVendorDB.sellDelay or 0.2
    C_Timer.After(delay, SellNextItem)
end

-- Start selling process
local function StartSelling()
    if isSelling then return end
    
    ScanBags()
    
    -- Update button to reflect actual scan result
    if addon.sellButton then
        addon.sellButton:SetText(string.format("Sell (%d)", #itemsToSell))
        if #itemsToSell > 0 then
            addon.sellButton:Enable()
        else
            addon.sellButton:Disable()
        end
    end
    
    Print(string.format("Starting sell: found %d items", #itemsToSell))
    
    if #itemsToSell == 0 then
        Print("No legacy items to sell - check your filter settings with /lv debug")
        return
    end
    
    -- List items that will be sold
    for i, item in ipairs(itemsToSell) do
        if i <= 5 then
            Print(string.format("  %d. %s", i, item.link or "Unknown"))
        end
    end
    if #itemsToSell > 5 then
        Print(string.format("  ... and %d more", #itemsToSell - 5))
    end
    
    if LegacyVendorDB.confirmSell then
        -- Show confirmation dialog
        StaticPopupDialogs["LEGACYVENDOR_CONFIRM"] = {
            text = string.format("LegacyVendor: Sell %d legacy item(s) for approximately %s?", 
                #itemsToSell, FormatMoney(totalGoldEarned)),
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                isSelling = true
                SellNextItem()
            end,
            timeout = 0,
            whileDead = false,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("LEGACYVENDOR_CONFIRM")
    else
        isSelling = true
        SellNextItem()
    end
end

-- Event handlers
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- Initialize saved variables
            if not LegacyVendorDB then
                LegacyVendorDB = CopyTable(defaults)
            else
                -- Merge with defaults for any new settings
                for k, v in pairs(defaults) do
                    if LegacyVendorDB[k] == nil then
                        LegacyVendorDB[k] = v
                    end
                end
                -- Ensure all expansions have settings (only for available expansions)
                local maxExp = addon.MAX_EXPANSION or addon.CURRENT_EXPANSION
                for expID, expData in pairs(addon.EXPANSIONS) do
                    if expID <= maxExp and LegacyVendorDB.expansions[expID] == nil then
                        LegacyVendorDB.expansions[expID] = expData.enabled
                    end
                end
                -- Ensure all rarities have settings
                for rarityID, rarityData in pairs(addon.RARITIES) do
                    if LegacyVendorDB.rarities[rarityID] == nil then
                        LegacyVendorDB.rarities[rarityID] = rarityData.enabled
                    end
                end
                -- Ensure all equipment slots have settings
                for slotKey, slotData in pairs(addon.EQUIP_SLOTS) do
                    if LegacyVendorDB.equipSlots[slotKey] == nil then
                        LegacyVendorDB.equipSlots[slotKey] = slotData.enabled
                    end
                end
                -- Ensure all item types have settings
                for typeID, typeData in pairs(addon.ITEM_TYPES) do
                    if LegacyVendorDB.itemTypes[typeID] == nil then
                        LegacyVendorDB.itemTypes[typeID] = typeData.enabled
                    end
                end
                -- Ensure all item sources have settings
                for sourceKey, sourceData in pairs(addon.ITEM_SOURCES) do
                    if LegacyVendorDB.itemSources[sourceKey] == nil then
                        LegacyVendorDB.itemSources[sourceKey] = sourceData.enabled
                    end
                end
            end

            if addon.MigrateDB then addon.MigrateDB(LegacyVendorDB) end
            EnsureExpansionProfiles(LegacyVendorDB)
            
            -- Show loaded message with version info
            local versionInfo = addon.compatInfo or "Retail"
            Print("Loaded (" .. versionInfo .. "). Type /lv for options.")
            frame:UnregisterEvent("ADDON_LOADED")
        end
        
    elseif event == "MERCHANT_SHOW" then
        if LegacyVendorDB and LegacyVendorDB.enabled then
            -- Show/update the sell button on merchant frame
            addon.UpdateMerchantButton()
            addon.ScheduleHighlightUpdate()
            StartHighlightRetries()
            
            -- Only auto-sell if enabled (disabled by default for API safety)
            if LegacyVendorDB.autoSell then
                -- Small delay to ensure merchant frame is ready
                C_Timer.After(0.5, StartSelling)
            else
                -- Just scan and notify user
                C_Timer.After(0.3, function()
                    local items = ScanBags()
                    if #items > 0 then
                        Print(string.format("Found %d legacy item(s) to sell. Click the [Sell Legacy] button or use /lv sell", #items))
                    end
                end)
            end
        end
        
    elseif event == "MERCHANT_CLOSED" then
        isSelling = false
        itemsToSell = {}
        StopHighlightRetries()
        if addon.sellButton then
            addon.sellButton:Hide()
        end
        if addon.UpdateBagHighlights then
            addon.UpdateBagHighlights()
        end

    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        if LegacyVendorDB and LegacyVendorDB.enabled and MerchantFrame and MerchantFrame:IsShown() then
            addon.UpdateMerchantButton()
            addon.ScheduleHighlightUpdate()
        end
    end
end

-- Create sell button immediately (called after ADDON_LOADED)
local function CreateSellButton()
    if addon.sellButton then return end
    
    local btn = CreateFrame("Button", "LegacyVendorSellButton", MerchantFrame, "UIPanelButtonTemplate")
    btn:SetSize(70, 22)
    btn:SetText("Sell (0)")
    
    -- Anchor to the right of the Buyback tab
    if MerchantFrameTab2 then
        btn:SetPoint("LEFT", MerchantFrameTab2, "RIGHT", 5, 0)
    else
        btn:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 180, 50)
    end
    
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(100)
    
    btn:SetScript("OnClick", function()
        if MerchantFrame and MerchantFrame:IsShown() then
            StartSelling()
        else
            Print("Open a vendor first!")
        end
    end)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("|cFFFFD100LegacyVendor|r")
        GameTooltip:AddLine("Click to sell legacy items", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    addon.sellButton = btn
end

function addon.UpdateMerchantButton()
    -- Create button if it doesn't exist
    if not addon.sellButton then
        CreateSellButton()
    end
    
    if not addon.sellButton then return end
    
    -- Update count and show
    local items = ScanBags()
    local count = #items
    addon.sellButton:SetText(string.format("Sell (%d)", count))
    
    if count > 0 then
        addon.sellButton:Enable()
    else
        addon.sellButton:Disable()
    end
    
    addon.sellButton:Show()
end

-- Register events
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("BAG_UPDATE_DELAYED")

-- Slash commands
SLASH_LEGACYVENDOR1 = "/legacyvendor"
SLASH_LEGACYVENDOR2 = "/lv"

SlashCmdList["LEGACYVENDOR"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "" or msg == "help" then
        Print("Commands:")
        Print("  /lv toggle - Enable/disable addon")
        Print("  /lv auto - Toggle auto-sell mode (manual by default)")
        Print("  /lv config - Open configuration panel")
        Print("  /lv scan - Scan bags and show what would be sold")
        Print("  /lv sell - Manually trigger selling")
        Print("  /lv exclude - Exclude item you're hovering over")
        Print("  /lv expansions - List expansion filter settings")
        Print("  /lv minimap - Toggle minimap button")
        Print("  /lv resetbutton - Reset minimap button to default position")
        Print("  /lv highlight - Toggle bag highlighting")
        Print("  /lv reset - Reset settings to default")
        Print("  /lv debug - Toggle debug mode")
        Print("  /lv strict - Toggle strict seasonal protection")
        Print("  /lv meta - Toggle expansion sell-all mode")
        
    elseif msg == "toggle" then
        LegacyVendorDB.enabled = not LegacyVendorDB.enabled
        Print("Addon " .. (LegacyVendorDB.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        addon.ScheduleHighlightUpdate()
        
    elseif msg == "auto" then
        LegacyVendorDB.autoSell = not LegacyVendorDB.autoSell
        if LegacyVendorDB.autoSell then
            Print("Auto-sell |cFF00FF00enabled|r - Items will be sold automatically when visiting a vendor.")
        else
            Print("Auto-sell |cFFFF0000disabled|r - Click the [Sell Legacy] button at vendors to sell.")
        end
        
    elseif msg == "config" or msg == "options" then
        if addon.OpenConfig then
            addon.OpenConfig()
        else
            Print("Configuration panel not available. Use slash commands.")
        end
        
    elseif msg == "scan" then
        local items = ScanBags()
        if #items == 0 then
            Print("No legacy BoP items found to sell.")
        else
            Print(string.format("Found %d item(s) worth approximately %s:", #items, FormatMoney(totalGoldEarned)))
            for i, item in ipairs(items) do
                if i <= 10 then -- Limit display to 10 items
                    print("  " .. (item.link or "Unknown") .. " - " .. FormatMoney(item.price))
                end
            end
            if #items > 10 then
                print("  ... and " .. (#items - 10) .. " more items")
            end
        end
        
    elseif msg == "sell" then
        if MerchantFrame and MerchantFrame:IsShown() then
            StartSelling()
        else
            Print("You must be at a vendor to sell items.")
        end
        
    elseif msg == "exclude" then
        local _, itemLink = GameTooltip:GetItem()
        if itemLink then
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            if itemID then
                if LegacyVendorDB.excludedItems[itemID] then
                    LegacyVendorDB.excludedItems[itemID] = nil
                    Print("Removed from exclusion list: " .. itemLink)
                else
                    LegacyVendorDB.excludedItems[itemID] = true
                    Print("Added to exclusion list: " .. itemLink)
                end
            end
        else
            Print("Hover over an item and use /lv exclude to toggle exclusion.")
        end
        
    elseif msg == "reset" then
        LegacyVendorDB = CopyTable(defaults)
        Print("Settings reset to default.")
        
    elseif msg == "debug" then
        LegacyVendorDB.debug = not LegacyVendorDB.debug
        Print("Debug mode " .. (LegacyVendorDB.debug and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))

    elseif msg == "strict" then
        LegacyVendorDB.strictSeasonalProtection = not (LegacyVendorDB.strictSeasonalProtection ~= false)
        if LegacyVendorDB.strictSeasonalProtection then
            Print("Strict seasonal protection |cFF00FF00enabled|r - current-season scaled legacy dungeon items are always kept.")
        else
            Print("Strict seasonal protection |cFFFF0000disabled|r - fallback protections still apply, but rigid hard-stop mode is off.")
        end
        if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
            addon.UpdateMerchantButton()
        end

    elseif msg == "meta" then
        LegacyVendorDB.sellMode = (LegacyVendorDB.sellMode == "everything") and "matching" or "everything"
        if LegacyVendorDB.sellMode == "everything" then
            Print("Sell mode: |cFF00FF00Everything|r - checked expansions sell everything from that expansion.")
        else
            Print("Sell mode: |cFFFFFF00Matching filters|r - detailed filters are used instead.")
        end
        if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
            addon.UpdateMerchantButton()
        end
        
    elseif msg == "highlight" then
        LegacyVendorDB.highlightItems = not LegacyVendorDB.highlightItems
        Print("Bag highlighting " .. (LegacyVendorDB.highlightItems and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        addon.ScheduleHighlightUpdate()
        
    elseif msg:match("^exp%s*(%d+)$") then
        local expID = tonumber(msg:match("^exp%s*(%d+)$"))
        if addon.EXPANSIONS[expID] then
            LegacyVendorDB.expansions[expID] = not LegacyVendorDB.expansions[expID]
            local expName = addon.EXPANSIONS[expID].name
            local status = LegacyVendorDB.expansions[expID] and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
            Print(expName .. " items: " .. status)
        else
            Print("Invalid expansion ID. Use 0-11.")
        end
        
    elseif msg == "expansions" or msg == "list" then
        Print("Expansion filter settings:")
        for i = 0, 11 do
            local exp = addon.EXPANSIONS[i]
            if exp then
                local status = LegacyVendorDB.expansions[i] and "|cFF00FF00[SELL]|r" or "|cFFFF0000[KEEP]|r"
                local profile = LegacyVendorDB.expansionProfiles and LegacyVendorDB.expansionProfiles[i]
                local mode = "global filters"
                if LegacyVendorDB.sellMode == "everything" and LegacyVendorDB.expansions[i] then
                    mode = "sell all"
                end
                if profile and profile.useDetailedFilters and LegacyVendorDB.sellMode == "matching" then
                    mode = "detailed filters"
                end
                print(string.format("  %d. %s %s (%s)", i, exp.name, status, mode))
            end
        end
        Print("Use '/lv exp <number>' to toggle an expansion.")
        
    elseif msg == "minimap" then
        if not LegacyVendorDB.minimapButton then
            LegacyVendorDB.minimapButton = { hide = false, minimapPos = 220, freeform = false }
        end
        LegacyVendorDB.minimapButton.hide = not LegacyVendorDB.minimapButton.hide
        if LegacyVendorDB.minimapButton.hide then
            if addon.minimapButton then
                addon.minimapButton:Hide()
            end
            Print("Minimap button hidden. Use /lv minimap to show.")
        else
            if addon.minimapButton then
                addon.minimapButton:Show()
            end
            Print("Minimap button shown.")
        end
        
    elseif msg == "resetbutton" then
        if not LegacyVendorDB.minimapButton then
            LegacyVendorDB.minimapButton = { hide = false, minimapPos = 220, freeform = false }
        end
        -- Reset to default minimap-attached position
        LegacyVendorDB.minimapButton.freeform = false
        LegacyVendorDB.minimapButton.minimapPos = 220
        LegacyVendorDB.minimapButton.freeformX = nil
        LegacyVendorDB.minimapButton.freeformY = nil
        if addon.minimapButton and addon.minimapButton.UpdatePosition then
            addon.minimapButton.UpdatePosition()
        end
        Print("Minimap button reset to default position around minimap.")
        
    elseif msg == "button" then
        -- Force show button in center of screen for debugging
        if not addon.sellButton then
            Print("Creating button...")
            CreateSellButton()
        end
        if addon.sellButton then
            addon.sellButton:ClearAllPoints()
            addon.sellButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            addon.sellButton:Show()
            addon.sellButton:SetAlpha(1)
            Print("Button forced to CENTER of screen!")
        else
            Print("ERROR: Button still nil!")
        end
        
    elseif msg == "info" then
        Print("Debug information:")
        print("  sellButton exists: " .. tostring(addon.sellButton ~= nil))
        if addon.sellButton then
            print("  IsShown: " .. tostring(addon.sellButton:IsShown()))
            print("  IsVisible: " .. tostring(addon.sellButton:IsVisible()))
            print("  Alpha: " .. tostring(addon.sellButton:GetAlpha()))
            local p, r, rp, x, y = addon.sellButton:GetPoint()
            print("  Position: " .. tostring(p) .. " x=" .. tostring(x) .. " y=" .. tostring(y))
            print("  Width: " .. tostring(addon.sellButton:GetWidth()))
            print("  Height: " .. tostring(addon.sellButton:GetHeight()))
        end
        
    else
        Print("Unknown command. Type /lv help for a list of commands.")
    end
end

-- ==========================================
-- MINIMAP BUTTON
-- ==========================================

-- Minimap shape detection for compatibility with minimap addons
-- Many minimap addons (SexyMap, BasicMinimap, etc.) set GetMinimapShape() 
-- to indicate if the minimap is square or has different shapes
local function GetMinimapShapeCompat()
    -- Check if a minimap addon has defined a custom shape function (global)
    if _G.GetMinimapShape then
        return _G.GetMinimapShape()
    end
    -- Default to circular (ROUND)
    return "ROUND"
end

-- Calculate the radius for button positioning based on minimap shape and size
-- For square minimaps, we need different radius at corners vs edges
local function GetMinimapRadius(angle)
    local shape = GetMinimapShapeCompat()
    
    -- Get the actual minimap dimensions (handles resized minimaps)
    local width = Minimap:GetWidth() / 2
    local height = Minimap:GetHeight() / 2
    
    -- For circular minimap, use the standard radius
    if shape == "ROUND" then
        -- Use the smaller dimension + offset for circular minimaps
        return math.min(width, height) + 10
    end
    
    -- For square minimaps (SQUARE shape from addons like SexyMap, BasicMinimap)
    if shape == "SQUARE" then
        -- Calculate radius to always be on the square edge
        -- For a square, the distance to edge varies by angle
        local rad = math.rad(angle)
        local cos_a = math.abs(math.cos(rad))
        local sin_a = math.abs(math.sin(rad))
        
        -- Calculate the distance to the square edge at this angle
        local radius
        if cos_a > sin_a then
            radius = width / cos_a
        else
            radius = height / sin_a
        end
        
        -- Add small offset to place button just outside the edge
        return radius + 6
    end
    
    -- For other shapes (CORNER-TOPLEFT, etc.), fall back to circular
    -- but adjust for minimap size
    return math.min(width, height) + 10
end

local function CreateMinimapButton()
    -- Default minimap button settings
    if not LegacyVendorDB.minimapButton then
        LegacyVendorDB.minimapButton = {
            hide = false,
            minimapPos = 220, -- angle around minimap (used in circular mode)
            freeform = false, -- freeform positioning mode (drag anywhere)
            freeformX = nil,  -- screen X position (freeform mode)
            freeformY = nil,  -- screen Y position (freeform mode)
        }
    end
    
    -- Upgrade existing settings if freeform fields don't exist
    if LegacyVendorDB.minimapButton.freeform == nil then
        LegacyVendorDB.minimapButton.freeform = false
        LegacyVendorDB.minimapButton.freeformX = nil
        LegacyVendorDB.minimapButton.freeformY = nil
    end
    
    local button = CreateFrame("Button", "LegacyVendorMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 10) -- Ensure we're above minimap content
    button:EnableMouse(true)
    button:SetMovable(true)
    button:SetClampedToScreen(true) -- Prevent button from going off-screen
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    
    -- Button textures
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)
    
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("CENTER", 0, 1)
    
    -- Icon - using a gold coin icon (fits vendor theme)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetPoint("CENTER", 0, 1)
    button.icon = icon
    
    -- Highlight texture
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(24, 24)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("CENTER", 0, 1)
    
    -- Position button around minimap (adapts to minimap shape and size)
    -- Or use freeform positioning if enabled
    local function UpdatePosition()
        if LegacyVendorDB.minimapButton.freeform then
            -- Freeform mode: position anywhere on screen, parent to UIParent
            button:SetParent(UIParent)
            button:SetFrameStrata("MEDIUM")
            button:SetFrameLevel(100)
            local x = LegacyVendorDB.minimapButton.freeformX
            local y = LegacyVendorDB.minimapButton.freeformY
            if x and y then
                button:ClearAllPoints()
                button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            else
                -- Default freeform position near minimap
                button:ClearAllPoints()
                button:SetPoint("CENTER", Minimap, "CENTER", -60, -60)
            end
        else
            -- Circular/minimap-attached mode: parent to Minimap so we follow it
            button:SetParent(Minimap)
            button:SetFrameStrata("MEDIUM")
            button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
            local angle = LegacyVendorDB.minimapButton.minimapPos or 220
            local radius = GetMinimapRadius(angle)
            local rad = math.rad(angle)
            local x = math.cos(rad) * radius
            local y = math.sin(rad) * radius
            button:ClearAllPoints()
            button:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
    end
    
    -- Store UpdatePosition for external access (minimap addon compatibility)
    button.UpdatePosition = UpdatePosition
    
    -- Dragging functionality
    -- Shift+Drag to toggle between freeform and circular mode
    -- Regular drag moves the button in current mode
    local isDragging = false
    local dragMode = nil -- "freeform" or "circular"
    
    button:SetScript("OnDragStart", function(self)
        isDragging = true
        self:LockHighlight()
        
        -- Check if Shift is held to enter/stay in freeform mode
        if IsShiftKeyDown() then
            dragMode = "freeform"
            LegacyVendorDB.minimapButton.freeform = true
            -- Re-parent to UIParent for freeform dragging
            self:SetParent(UIParent)
            self:SetFrameStrata("MEDIUM")
            self:SetFrameLevel(100)
            self:StartMoving()
        elseif LegacyVendorDB.minimapButton.freeform then
            -- Already in freeform mode, continue freeform drag
            dragMode = "freeform"
            self:StartMoving()
        else
            -- Circular mode drag
            dragMode = "circular"
        end
    end)
    
    button:SetScript("OnDragStop", function(self)
        isDragging = false
        self:UnlockHighlight()
        
        if dragMode == "freeform" then
            self:StopMovingOrSizing()
            -- Save the freeform position
            local scale = UIParent:GetEffectiveScale()
            local x, y = self:GetCenter()
            LegacyVendorDB.minimapButton.freeformX = x
            LegacyVendorDB.minimapButton.freeformY = y
        else
            -- Circular mode: Calculate new angle based on cursor position
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            LegacyVendorDB.minimapButton.minimapPos = angle
            UpdatePosition()
        end
        
        dragMode = nil
    end)
    
    button:SetScript("OnUpdate", function(self)
        if isDragging and dragMode == "circular" then
            -- Only update position in circular mode
            -- Freeform mode uses StartMoving/StopMoving
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            LegacyVendorDB.minimapButton.minimapPos = angle
            UpdatePosition()
        end
    end)
    
    -- Update position when minimap size changes (for minimap addons that resize)
    button:SetScript("OnSizeChanged", function()
        if not isDragging then
            UpdatePosition()
        end
    end)
    
    -- Also update when the minimap itself changes size
    if Minimap.RegisterCallback then
        -- Some minimap addons provide callbacks
        Minimap:RegisterCallback("OnSizeChanged", UpdatePosition)
    end
    
    -- Click handlers
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            if addon.OpenConfig then
                addon.OpenConfig()
            end
        elseif btn == "RightButton" then
            -- Quick toggle addon on/off
            LegacyVendorDB.enabled = not LegacyVendorDB.enabled
            Print("Addon " .. (LegacyVendorDB.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cFFFFD100LegacyVendor|r", 1, 1, 1)
        GameTooltip:AddLine("Sell legacy BoP items at vendors", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF00FF00Left-Click:|r Open Settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFF00FF00Right-Click:|r Toggle Enable/Disable", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFF00FF00Drag:|r Move Button", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFF00FF00Shift+Drag:|r Freeform Position (anywhere)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFF00FF00/lv resetbutton:|r Reset to minimap", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        local status = LegacyVendorDB.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        GameTooltip:AddLine("Status: " .. status, 0.7, 0.7, 0.7)
        local posMode = LegacyVendorDB.minimapButton.freeform and "Freeform" or "Minimap-attached"
        GameTooltip:AddLine("Position Mode: " .. posMode, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Initial position
    UpdatePosition()
    
    -- Hide if setting says so
    if LegacyVendorDB.minimapButton.hide then
        button:Hide()
    end
    
    addon.minimapButton = button
    
    -- Hook Minimap:SetSize to update position when minimap addons resize
    hooksecurefunc(Minimap, "SetSize", function()
        C_Timer.After(0.1, function()
            if addon.minimapButton and addon.minimapButton.UpdatePosition then
                addon.minimapButton.UpdatePosition()
            end
        end)
    end)
    
    return button
end

-- Initialize minimap button after saved variables are loaded
local minimapLoader = CreateFrame("Frame")
minimapLoader:RegisterEvent("PLAYER_LOGIN")
minimapLoader:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, function()
        if LegacyVendorDB then
            CreateMinimapButton()
        end
    end)
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Export addon table
_G.LegacyVendor = addon
