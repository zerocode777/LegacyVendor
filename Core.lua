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
-- WARNING: these are PRE-SQUISH values from before Midnight rescaled item levels.
-- On the current scale (character gear in the high 200s) nothing reaches them, so
-- this signal does not currently fire for any item. It is retained because it can
-- only ever ADD protection, never remove it, and because the numbers become correct
-- again for anyone still on an older client. The working guard on live is the
-- absolute ceiling in Settings (highIlvlThreshold), which is scale-independent
-- because the player sets it against gear they can actually see.
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
-- Current scale, not a historical one. Midnight character gear is in the high 200s,
-- so anything a legacy item scales to at/above this is current-season content.
addon.STRICT_SEASONAL_ILVL_FLOOR = 260

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
    -- Expansion-independent safety net. Uses EFFECTIVE item level, so scaled gear is
    -- judged on what it actually is rather than what it originally dropped as.
    protectHighIlvl = true,
    -- Tuned to the CURRENT item level scale, not a historical one. Midnight runs in
    -- the high 200s (character gear observed at 266-289), so 285 sits just under
    -- current-content gear. Raise it after an item level squish, lower it if current
    -- content starts dropping below this.
    highIlvlThreshold = 285,
    debug = false,
    sellDelay = 0.2, -- Delay between sells to avoid throttling
    itemSources = {}, -- Source filter settings (vendor, crafted, dropped, etc.)
    filterBySource = false, -- Whether to apply source filtering at all
    highlightItems = true, -- Highlight sellable items in bags
    highlightColor = { r = 0.68, g = 0.45, b = 1.0, a = 0.85 }, -- Light purple glow by default
    highlightStyle = "pulse", -- Visual style id, see addon.HIGHLIGHT_STYLES
    protectUncollected = true, -- Never sell uncollected appearances/mounts/toys/pets
    showTooltipInfo = true, -- Add a "will sell / keeping - why" line to item tooltips
    stats = { totalCopper = 0, totalItems = 0, byExpansion = {}, firstSale = nil, lastSale = nil },
    autoConfirmTradeTimer = false, -- Auto-accept "will become non-tradeable" prompts while selling
    sellWarbound = false, -- Warband/account-bound items are shared by every character: opt in explicitly
    profiles = {},      -- name -> { config = <share string>, saved = <time> }
    charProfiles = {},  -- "Name-Realm" -> profile name, loaded automatically at login
    activeProfile = nil,
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
local sessionSoldCopper = 0 -- value of items CONFIRMED sold this run

-- Debug log buffer, so the raw text can be exported via /lv exportlog instead of screenshots
local debugLogBuffer = {}
local MAX_DEBUG_LOG_LINES = 1000

-- Debug print function: buffers into the exportable log window (/lv exportlog)
-- instead of spamming the chat frame.
local function DebugPrint(...)
    if LegacyVendorDB and LegacyVendorDB.debug then
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        table.insert(debugLogBuffer, table.concat(parts, " "))
        if #debugLogBuffer > MAX_DEBUG_LOG_LINES then
            table.remove(debugLogBuffer, 1)
        end
    end
end

-- Print function
local function Print(...)
    print("|cFF00CCFF[LegacyVendor]|r", ...)
end

addon.Print = Print
addon.DebugPrint = DebugPrint

local exportLogFrame

local function ShowExportLog()
    local text = table.concat(debugLogBuffer, "\n")
    if text == "" then
        Print("Debug log is empty. Enable Debug Mode (/lv debug) and reproduce the issue first.")
        return
    end

    if not exportLogFrame then
        local f = CreateFrame("Frame", "LegacyVendorExportFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(640, 480)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", f.TitleBg or f, "TOP", 0, -5)
        f.title:SetText("LegacyVendor Debug Log - Ctrl+A then Ctrl+C to copy")

        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 12, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(576)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(f._lastText or "")
                self:HighlightText()
            end
        end)
        scrollFrame:SetScrollChild(editBox)
        f.editBox = editBox

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(100, 22)
        clearBtn:SetPoint("BOTTOMLEFT", 14, 10)
        clearBtn:SetText("Clear Log")
        clearBtn:SetScript("OnClick", function()
            wipe(debugLogBuffer)
            f:Hide()
            Print("Debug log cleared.")
        end)
        f.clearBtn = clearBtn

        exportLogFrame = f
    end

    exportLogFrame._lastText = text
    exportLogFrame.editBox:SetText(text)
    exportLogFrame.editBox:HighlightText()
    exportLogFrame.editBox:SetFocus()
    exportLogFrame:Show()
end

addon.ShowExportLog = ShowExportLog

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
    
    -- Warband / account binding (TWW). Enum values, with literals as the fallback
    -- for clients where Enum.ItemBind is absent:
    --   5 ToWoWAccount, 6 ToBnetAccount, 7 ToBnetAccountUntilEquipped
    local B = Enum and Enum.ItemBind
    local accountBinds = {
        [(B and B.ToWoWAccount) or 5] = true,
        [(B and B.ToBnetAccount) or 6] = true,
        [(B and B.ToBnetAccountUntilEquipped) or 7] = true,
    }

    -- Determine status
    if accountBinds[bindType] then
        -- Checked BEFORE the isBound test: these are shared across every character
        -- on the account, so selling one from here removes it for all of them. They
        -- previously fell through to "unbound", which meant enabling unbound selling
        -- would quietly sweep up warband items.
        return "warband"
    elseif not isBound then
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
-- An item's source bucket is an intrinsic property of the item, so it cannot change
-- during a session - itemID is a safe cache key with no invalidation needed. This
-- matters because the fallback path below runs a per-item tooltip scan, which is by
-- far the most expensive call in a bag scan; without this, rescanning on every bag
-- event would be genuinely heavy.
local itemSourceCache = {}
addon.itemSourceCache = itemSourceCache

local function GetItemSourceUncached(itemID, bag, slot)
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

local function GetItemSource(itemID, bag, slot)
    if not itemID then return "unknown" end

    local cached = itemSourceCache[itemID]
    if cached ~= nil then
        return cached
    end

    local source = GetItemSourceUncached(itemID, bag, slot)

    -- Only cache once the item's info is actually available. GetItemInfo returns nil
    -- for an uncached item, which would otherwise let a premature "unknown" stick
    -- permanently for the rest of the session.
    local infoReady = C_Item.GetItemInfo and C_Item.GetItemInfo(itemID) or GetItemInfo(itemID)
    if infoReady then
        itemSourceCache[itemID] = source
    end

    return source
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

    -- Source detection is a WEAK signal, not a gate. C_ItemSourceInfo frequently
    -- returns nothing and the tooltip heuristics rarely produce "dungeon", so most
    -- gear resolves to "unknown" - and while this was an early return, every item
    -- with an undetectable source skipped all four checks below and was sold. That
    -- is why current-season gear from refreshed dungeons (Kings' Rest, Temple of
    -- Sethraliss) slipped through with M+ protection switched on.
    --
    -- The item-level signals do not need the source: an item carrying a legacy
    -- expansion ID while scaled to current-season item level is suspicious however
    -- it was obtained. Source is now only used to bias toward protecting.
    local sourceBucket = GetItemSource(itemID, bag, slot)
    local sourceSuggestsInstance = (sourceBucket == "dungeon" or sourceBucket == "raid")

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
        -- No item level to reason about. Protect anyway if the source did say the
        -- item came out of an instance: unknown beats sold-by-mistake here.
        return sourceSuggestsInstance
    end

    -- Signal 2: expansion-specific ilvl ceiling (safe for most legacy expansions).
    local ilvlCeiling = addon.EXPANSION_ILVL_CEILING[expansionID]
    if ilvlCeiling and effectiveIlvl > ilvlCeiling then
        DebugPrint("Seasonal protection: ilvl", effectiveIlvl, "exceeds ceiling",
            ilvlCeiling, "for expansion", expansionID, itemLink)
        return true
    end

    -- Signal 3: large scaling delta between base and effective item level.
    -- Current-season scaling bonuses typically create a large gap.
    -- Threshold is proportional to the item level scale in use; on the current
    -- (squished) scale a 120-point gap is impossible, so this never fired.
    if baseItemLevel and baseItemLevel > 0 and (effectiveIlvl - baseItemLevel) >= 40 then
        DebugPrint("Seasonal protection: scaled +",
            effectiveIlvl - baseItemLevel, "above base", itemLink)
        return true
    end

    -- Signal 4: conservative hard floor for modern-season ilvl.
    -- Skip WoD/Legion here because pre-squish item levels can be unusually high.
    local hardFloor = addon.STRICT_SEASONAL_ILVL_FLOOR
    if hardFloor and expansionID ~= 5 and expansionID ~= 6 and effectiveIlvl >= hardFloor then
        DebugPrint("Seasonal protection: ilvl", effectiveIlvl, "at/above hard floor",
            hardFloor, itemLink)
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

-- ==========================================
-- UNCOLLECTED COLLECTIBLE PROTECTION
-- ==========================================
-- Legacy BoP gear is exactly the category where an item can be a character's only
-- source of an appearance, and selling one is unrecoverable in a way a mis-sold
-- stack of old food is not. Every check below is guarded for API availability so
-- this degrades to "no protection claimed" on Classic rather than erroring.

-- Cached per itemID: collection state only changes when the player learns something,
-- and CollectibleCacheReset() below wipes it on exactly those events.
local collectibleCache = {}

local function ResetCollectibleCache()
    wipe(collectibleCache)
end
addon.ResetCollectibleCache = ResetCollectibleCache

local function IsUncollectedAppearance(itemLink)
    if not itemLink then return false end
    local C = C_TransmogCollection
    if not (C and C.GetItemInfo) then return false end

    local ok, _, sourceID = pcall(C.GetItemInfo, itemLink)
    if not ok or not sourceID then return false end

    -- Only claim protection for appearances THIS character could actually learn -
    -- otherwise every legacy drop of another armour class reads as "uncollected"
    -- and the addon quietly stops selling most of what the user wants cleared.
    if C.PlayerCanCollectSource then
        local canOk, canCollect = pcall(C.PlayerCanCollectSource, sourceID)
        if not canOk or not canCollect then return false end
    end

    if C.PlayerHasTransmogItemModifiedAppearance then
        local hasOk, hasIt = pcall(C.PlayerHasTransmogItemModifiedAppearance, sourceID)
        if hasOk and hasIt == false then
            return true
        end
    end

    return false
end

local function IsUncollectedToy(itemID)
    if not (C_ToyBox and C_ToyBox.GetToyInfo and PlayerHasToy) then return false end
    local ok, toyItemID = pcall(C_ToyBox.GetToyInfo, itemID)
    if not ok or not toyItemID then return false end
    local hasOk, hasIt = pcall(PlayerHasToy, itemID)
    return hasOk and not hasIt
end

local function IsUncollectedMount(itemID)
    local M = C_MountJournal
    if not (M and M.GetMountFromItem and M.GetMountInfoByID) then return false end
    local ok, mountID = pcall(M.GetMountFromItem, itemID)
    if not ok or not mountID then return false end
    local infoOk, _, _, _, _, _, _, _, _, _, _, isCollected = pcall(M.GetMountInfoByID, mountID)
    return infoOk and isCollected == false
end

local function IsUncollectedPet(itemID)
    local P = C_PetJournal
    if not (P and P.GetPetInfoByItemID and P.GetNumCollectedInfo) then return false end
    local ok, _, _, _, _, _, _, _, _, _, _, _, speciesID = pcall(P.GetPetInfoByItemID, itemID)
    if not ok or not speciesID then return false end
    local numOk, numCollected = pcall(P.GetNumCollectedInfo, speciesID)
    return numOk and (numCollected == 0)
end

-- Returns reason string when the item is an uncollected collectible, else nil.
local function GetCollectibleProtection(itemID, itemLink)
    if not itemID then return nil end

    local cached = collectibleCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local reason = nil
    if IsUncollectedAppearance(itemLink) then
        reason = "uncollected appearance"
    elseif IsUncollectedToy(itemID) then
        reason = "uncollected toy"
    elseif IsUncollectedMount(itemID) then
        reason = "uncollected mount"
    elseif IsUncollectedPet(itemID) then
        reason = "uncollected pet"
    end

    collectibleCache[itemID] = reason or false
    return reason
end
addon.GetCollectibleProtection = GetCollectibleProtection

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
        return false, "you excluded this item"
    end
    
    -- Get item info using modern API
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
    if not containerInfo then return false end
    
    local itemLink = containerInfo.hyperlink
    local quality = containerInfo.quality
    local isLocked = containerInfo.isLocked
    local itemCount = containerInfo.stackCount
    
    -- Don't sell locked items
    if isLocked then return false, "item is locked" end

    -- === HARD STOP: uncollected collectibles ===
    -- Runs before every sell filter. Selling the only source of an appearance,
    -- mount, toy or pet is unrecoverable, so this outranks all sell rules.
    if db.protectUncollected ~= false then
        local collectibleReason = GetCollectibleProtection(itemID, itemLink)
        if collectibleReason then
            DebugPrint("Protected (" .. collectibleReason .. "):", itemLink)
            return false, collectibleReason
        end
    end

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
        return false, "expansion unknown"
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
            -- No exceptions. This used to be bypassed whenever the user was in
            -- "sell everything" mode with the current expansion ticked - which is
            -- the DEFAULT mode, so the protection silently did nothing for a large
            -- share of users despite the setting reading as on. The option promises
            -- "overrides every sell filter", so it has to actually do that; a
            -- safeguard with a hidden exception is worse than no safeguard, because
            -- people rely on it. Anyone who genuinely wants this gear sold can turn
            -- the protection off, which is explicit and visible.
            DebugPrint("Strict protection: skipping seasonal legacy item:", itemLink)
            return false, "current-season Mythic+ gear"
        end
    end

    -- === HARD STOP: item level ceiling ===
    -- Deliberately independent of expansion AND of source detection, which is what
    -- makes it a reliable backstop: the seasonal check above has to work out which
    -- expansion an item belongs to and where it came from, and either can fail. This
    -- one only asks "how good is this item, right now?".
    --
    -- Effective item level, not the base value, so a legacy piece scaled up by
    -- current-season bonus IDs is measured at its real strength.
    if db.protectHighIlvl and (db.highIlvlThreshold or 0) > 0 then
        local isGear = equipLoc and equipLoc ~= ""
        if isGear and GetDetailedItemLevelInfo then
            local effIlvl = GetDetailedItemLevelInfo(itemLink)
            if effIlvl and effIlvl >= db.highIlvlThreshold then
                DebugPrint("Item level protection:", effIlvl, ">=", db.highIlvlThreshold, itemLink)
                return false, ("item level %d is at or above your %d limit"):format(
                    effIlvl, db.highIlvlThreshold)
            end
        end
    end
    
    -- No sell price = can't sell
    if not sellPrice or sellPrice == 0 then
        DebugPrint("No sell price:", itemLink, "bag=", bag, "slot=", slot)
        return false, "vendors will not buy it"
    end

    -- Special handling for gray items - bypass most filters if sellGray is enabled
    if db.sellGray and quality == 0 then
        DebugPrint("Selling gray item:", itemLink)
        return true, itemLink, itemCount, sellPrice * itemCount, filterExpansionID
    end

    -- === FILTER 1: EXPANSION ===
    if not db.expansions[filterExpansionID] then
        local expName = (addon.EXPANSIONS[filterExpansionID] and (addon.EXPANSIONS[filterExpansionID].short or addon.EXPANSIONS[filterExpansionID].name)) or "that expansion"
        DebugPrint("Expansion disabled:", filterExpansionID, itemLink, "bag=", bag, "slot=", slot)
        return false, expName .. " is not selected"
    end

    -- Resolve against filterExpansionID (which GetFilterExpansionID may have redirected,
    -- e.g. a current-season item remapped to CURRENT_EXPANSION), not the raw expansionID.
    local resolved = addon.ResolveActiveFilters(db, filterExpansionID)
    local activeRarities = resolved.rarities
    local activeBindTypes = resolved.bindTypes
    local activeEquipSlots = resolved.equipSlots
    local activeItemTypes = resolved.itemTypes
    local activeOnlyLowerIlvl = resolved.onlyLowerIlvl

    local sourceRejectReason
    local function PassesSourceFilter()
        if db.sellMode ~= "matching" then return true end
        local itemSource = GetItemSource(itemID, bag, slot)
        DebugPrint("Item source for", itemLink, ":", itemSource or "nil")
        if addon.SourceSkipped(resolved.itemSources, itemSource) then
            DebugPrint("Source skipped:", itemSource, itemLink)
            local sn = (addon.Visuals and addon.Visuals.ShortLabel[itemSource]) or itemSource
            sourceRejectReason = "you never sell from " .. sn
            return false
        end
        return true
    end

    -- "Everything" mode: sell all legacy items from enabled expansions.
    -- Detailed filters (including source) intentionally do NOT apply here.
    if db.sellMode == "everything" then
        DebugPrint("Meta expansion sell-all matched:", filterExpansionID, itemLink)
        return true, itemLink, itemCount, sellPrice * itemCount, filterExpansionID
    end

    -- === FILTER 2: RARITY (Quality) ===
    if activeRarities and activeRarities[quality] ~= nil then
        if not activeRarities[quality] then
            DebugPrint("Rarity not enabled:", quality, itemLink)
            local rn = (addon.Visuals and addon.Visuals.RarityShort[quality])
                or (addon.RARITIES[quality] and addon.RARITIES[quality].name) or "that rarity"
            return false, rn .. " is not selected"
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
    elseif bindStatus == "warband" and db.sellWarbound then
        -- Its own opt-in, never covered by any other bind toggle.
        bindAllowed = true
    end

    if not bindAllowed then
        DebugPrint("Bind type not enabled:", bindStatus, itemLink)
        local bn = (addon.Visuals and addon.Visuals.ShortLabel[bindStatus]) or (bindStatus or "that bind type")
        return false, bn .. " is not selected"
    end
    
    -- === FILTER 4: EQUIPMENT SLOTS (for equippable items) ===
    local isEquipment = equipLoc and equipLoc ~= ""
    
    if isEquipment then
        -- Check if this equipment slot is enabled
        if activeEquipSlots and activeEquipSlots[equipLoc] ~= nil then
            if not activeEquipSlots[equipLoc] then
                DebugPrint("Equipment slot not enabled:", equipLoc, itemLink)
                local slotName = (addon.EQUIP_SLOTS[equipLoc] and addon.EQUIP_SLOTS[equipLoc].name) or "that slot"
                return false, slotName .. " is not selected"
            end
        end
    end
    
    -- === FILTER 5: ITEM TYPES (for non-equippable items) ===
    if not isEquipment then
        -- Consumables are controlled via source filters + bind filters to avoid duplicate controls.
        if classID ~= 0 and activeItemTypes and classID and activeItemTypes[classID] ~= nil then
            if not activeItemTypes[classID] then
                DebugPrint("Item type not enabled:", classID, "(class ID)", itemLink)
                local tn = (addon.Visuals and addon.Visuals.ItemTypeShort[classID])
                    or (addon.ITEM_TYPES[classID] and addon.ITEM_TYPES[classID].name) or "that item type"
                return false, tn .. " is not selected"
            end
        elseif classID and classID ~= 0 and classID ~= 2 and classID ~= 4 then
            -- Non-equippable item with unrecognized classID — skip by default.
            -- classID 2 = Weapon and 4 = Armor are handled by equipment slot filters.
            DebugPrint("Unrecognized non-equipment item type, skipping:", classID, itemLink)
            return false, "this kind of item is not in your filters"
        end
    end
    
    -- Check minimum item level
    local itemLevel = itemInfo[4] or 0
    if itemLevel < db.minItemLevel then
        DebugPrint("Below min item level:", itemLink)
        return false, "below your minimum item level"
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
        return false, sourceRejectReason or "excluded source"
    end
    
    DebugPrint("Will sell:", itemLink, "Expansion:", filterExpansionID, "Quality:", quality, "Bind:", bindStatus, "Class:", classID)
    return true, itemLink, itemCount, sellPrice * itemCount, filterExpansionID
end

-- Pure bag scan: builds a FRESH list and total, touching no module state.
-- Everything that only needs to know "what would sell right now" (the Sell (N)
-- button, /lv scan, the config panel) must use this rather than ScanBags(), because
-- ScanBags() overwrites the live sell queue - see CountSellable below.
local function CollectSellableItems()
    local items = {}
    local goldTotal = 0
    local limit = (LegacyVendorDB and LegacyVendorDB.maxSellPerVisit) or math.huge

    -- NUM_BAG_SLOTS is typically 4, plus bag 0 (backpack)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local shouldSell, itemLink, count, price, expID = ShouldSellItem(bag, slot)
            if shouldSell then
                if LegacyVendorDB and LegacyVendorDB.debug then
                    DebugPrint("ScanBags found:", itemLink, "bag=", bag, "slot=", slot)
                end
                items[#items + 1] = {
                    bag = bag,
                    slot = slot,
                    link = itemLink,
                    count = count,
                    price = price or 0,
                    expansion = expID,
                }
                goldTotal = goldTotal + (price or 0)

                -- Respect max sell limit
                if #items >= limit then
                    break
                end
            end
        end
        if #items >= limit then
            break
        end
    end

    return items, goldTotal
end

-- Read-only count for UI. Safe to call at any time, including mid-sell, because it
-- never touches itemsToSell / totalGoldEarned.
--
-- Cached for a fraction of a second: a bag addon can emit a burst of refreshes for
-- one user action, and re-scanning every slot per refresh would reintroduce the
-- exact cost we removed earlier. Bag and filter changes drop the cache explicitly.
local sellableCache, sellableCacheAt = nil, 0
local SELLABLE_CACHE_TTL = 0.25

local function InvalidateSellableCache()
    sellableCache = nil
end
addon.InvalidateSellableCache = InvalidateSellableCache

local function CountSellable(allowCache)
    local now = GetTime and GetTime() or 0
    if allowCache and sellableCache and (now - sellableCacheAt) < SELLABLE_CACHE_TTL then
        local c = sellableCache
        return #c.items, c.gold, c.items
    end

    local items, goldTotal = CollectSellableItems()
    sellableCache = { items = items, gold = goldTotal }
    sellableCacheAt = now
    return #items, goldTotal, items
end
addon.CountSellable = CountSellable

-- Builds the actual sell queue. Only the selling flow may call this: it deliberately
-- replaces itemsToSell / totalGoldEarned, so calling it while a sale is in progress
-- would discard the queue being consumed and reset the running gold total.
local function ScanBags()
    local items, goldTotal = CollectSellableItems()
    itemsToSell = items
    totalGoldEarned = goldTotal
    return itemsToSell
end

-- ==========================================
-- BAG ITEM HIGHLIGHTING
-- ==========================================

local activeBagHighlights = {}
local highlightUpdatePending = false
local highlightRetryCount = 0
local highlightRetryToken = 0
local ClearHighlightVisualParts -- assigned near the highlight style implementations below

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
        if hl then
            ClearHighlightVisualParts(hl)
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

-- ==========================================
-- HIGHLIGHT VISUAL STYLES
-- ==========================================
-- Each style builds a small set of Texture objects on a host frame (created once per
-- highlighted button, or once per config-panel preview swatch) and updates them on a
-- breathing/animated cycle. Adding a style: give it an id/name in HIGHLIGHT_STYLES,
-- then a build/color/update triple in HighlightStyleImpl keyed by that id.
addon.HIGHLIGHT_STYLES = {
    { id = "pulse",      name = "Pulsing Glow" },
    { id = "ants",       name = "Marching Ants (Classic)" },
    { id = "solid",      name = "Solid Border" },
    { id = "flash",      name = "Flash Pulse" },
    { id = "wash",       name = "Full Icon Wash" },
    { id = "corners",    name = "Soft Corners" },
    { id = "brackets",   name = "Corner Brackets" },
    { id = "doublering", name = "Double Ring" },
    { id = "spin",       name = "Spinning Accent" },
    { id = "dashed",     name = "Dashed Border" },
}

local DEFAULT_HIGHLIGHT_STYLE = "pulse"
addon.DEFAULT_HIGHLIGHT_STYLE = DEFAULT_HIGHLIGHT_STYLE

local function MakeBar(host, isHoriz, thickness)
    local tex = host:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetBlendMode("ADD")
    if isHoriz then
        tex:SetHeight(thickness)
    else
        tex:SetWidth(thickness)
    end
    return tex
end

local function AnchorEdge(tex, host, edge, inset)
    inset = inset or 0
    if edge == "top" then
        tex:SetPoint("TOPLEFT", host, "TOPLEFT", -inset, inset)
        tex:SetPoint("TOPRIGHT", host, "TOPRIGHT", inset, inset)
    elseif edge == "bottom" then
        tex:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -inset, -inset)
        tex:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", inset, -inset)
    elseif edge == "left" then
        tex:SetPoint("TOPLEFT", host, "TOPLEFT", -inset, inset)
        tex:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -inset, -inset)
    else -- "right"
        tex:SetPoint("TOPRIGHT", host, "TOPRIGHT", inset, inset)
        tex:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", inset, -inset)
    end
end

local function MakeWash(host, inset)
    local tex = host:CreateTexture(nil, "BACKGROUND")
    tex:SetPoint("TOPLEFT", host, "TOPLEFT", -(inset or 0), (inset or 0))
    tex:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", (inset or 0), -(inset or 0))
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetBlendMode("ADD")
    return tex
end

local function MakeDots(host, count, size)
    local dots = {}
    for i = 1, count do
        local d = host:CreateTexture(nil, "OVERLAY")
        d:SetSize(size, size)
        d:SetTexture("Interface\\Buttons\\WHITE8X8")
        d:SetBlendMode("ADD")
        dots[i] = d
    end
    return dots
end

-- Places `tex` at fraction t (0..1, wraps) around host's rectangular perimeter.
-- Returns the edge it landed on, for callers that want to orient the texture to match.
local function PlaceOnPerimeter(host, tex, t)
    local w = (host.GetWidth and host:GetWidth()) or 36
    local h = (host.GetHeight and host:GetHeight()) or 36
    local halfW, halfH = w * 0.5, h * 0.5
    local perimeter = (2 * w) + (2 * h)
    t = t - math.floor(t)
    local d = t * perimeter
    local x, y, edge

    if d < w then
        x, y, edge = -halfW + d, halfH, "top"
    elseif d < (w + h) then
        x, y, edge = halfW, halfH - (d - w), "right"
    elseif d < (2 * w + h) then
        x, y, edge = halfW - (d - (w + h)), -halfH, "bottom"
    else
        x, y, edge = -halfW, -halfH + (d - (2 * w + h)), "left"
    end

    tex:ClearAllPoints()
    tex:SetPoint("CENTER", host, "CENTER", x, y)
    return edge
end

local function ShowAll(list)
    for _, tex in ipairs(list) do
        tex:Show()
    end
end

local function ColorAll(list, r, g, b)
    for _, tex in ipairs(list) do
        tex:SetVertexColor(r, g, b, 1)
    end
end

local HighlightStyleImpl = {}
addon.HighlightStyleImpl = HighlightStyleImpl

HighlightStyleImpl.pulse = {
    animated = true,
    speed = 0.5, -- ~2 second breathing cycle
    build = function(hl, host)
        hl.wash = MakeWash(host, 3)
        hl.edgeTop = MakeBar(host, true, 2); AnchorEdge(hl.edgeTop, host, "top")
        hl.edgeBottom = MakeBar(host, true, 2); AnchorEdge(hl.edgeBottom, host, "bottom")
        hl.edgeLeft = MakeBar(host, false, 2); AnchorEdge(hl.edgeLeft, host, "left")
        hl.edgeRight = MakeBar(host, false, 2); AnchorEdge(hl.edgeRight, host, "right")
    end,
    color = function(hl, r, g, b)
        ColorAll({ hl.wash, hl.edgeTop, hl.edgeBottom, hl.edgeLeft, hl.edgeRight }, r, g, b)
        ShowAll({ hl.wash, hl.edgeTop, hl.edgeBottom, hl.edgeLeft, hl.edgeRight })
    end,
    update = function(hl, host, phase)
        local t = (math.sin(phase * math.pi * 2) + 1) * 0.5
        local edgeAlpha = 0.55 + (0.45 * t)
        hl.edgeTop:SetAlpha(edgeAlpha)
        hl.edgeBottom:SetAlpha(edgeAlpha)
        hl.edgeLeft:SetAlpha(edgeAlpha)
        hl.edgeRight:SetAlpha(edgeAlpha)
        hl.wash:SetAlpha(0.12 + (0.18 * t))
    end,
}

HighlightStyleImpl.solid = {
    animated = false,
    build = function(hl, host)
        hl.edgeTop = MakeBar(host, true, 2); AnchorEdge(hl.edgeTop, host, "top")
        hl.edgeBottom = MakeBar(host, true, 2); AnchorEdge(hl.edgeBottom, host, "bottom")
        hl.edgeLeft = MakeBar(host, false, 2); AnchorEdge(hl.edgeLeft, host, "left")
        hl.edgeRight = MakeBar(host, false, 2); AnchorEdge(hl.edgeRight, host, "right")
    end,
    color = function(hl, r, g, b)
        ColorAll({ hl.edgeTop, hl.edgeBottom, hl.edgeLeft, hl.edgeRight }, r, g, b)
        ShowAll({ hl.edgeTop, hl.edgeBottom, hl.edgeLeft, hl.edgeRight })
    end,
    update = function(hl, host, phase)
        hl.edgeTop:SetAlpha(0.95)
        hl.edgeBottom:SetAlpha(0.95)
        hl.edgeLeft:SetAlpha(0.95)
        hl.edgeRight:SetAlpha(0.95)
    end,
}

HighlightStyleImpl.flash = {
    animated = true,
    speed = 1.2,
    build = function(hl, host)
        hl.wash = MakeWash(host, 3)
        hl.edgeTop = MakeBar(host, true, 2); AnchorEdge(hl.edgeTop, host, "top")
        hl.edgeBottom = MakeBar(host, true, 2); AnchorEdge(hl.edgeBottom, host, "bottom")
        hl.edgeLeft = MakeBar(host, false, 2); AnchorEdge(hl.edgeLeft, host, "left")
        hl.edgeRight = MakeBar(host, false, 2); AnchorEdge(hl.edgeRight, host, "right")
    end,
    color = HighlightStyleImpl.pulse.color,
    update = function(hl, host, phase)
        local t = (phase % 1) < 0.5 and 1 or 0.2
        hl.edgeTop:SetAlpha(t)
        hl.edgeBottom:SetAlpha(t)
        hl.edgeLeft:SetAlpha(t)
        hl.edgeRight:SetAlpha(t)
        hl.wash:SetAlpha(t * 0.25)
    end,
}

HighlightStyleImpl.wash = {
    animated = true,
    speed = 0.5,
    build = function(hl, host)
        hl.wash = MakeWash(host, 0)
    end,
    color = function(hl, r, g, b)
        hl.wash:SetVertexColor(r, g, b, 1)
        hl.wash:Show()
    end,
    update = function(hl, host, phase)
        local t = (math.sin(phase * math.pi * 2) + 1) * 0.5
        hl.wash:SetAlpha(0.15 + (0.25 * t))
    end,
}

HighlightStyleImpl.corners = {
    animated = true,
    speed = 0.5,
    build = function(hl, host)
        hl.corners = {}
        local points = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
        for i, p in ipairs(points) do
            local tex = host:CreateTexture(nil, "OVERLAY")
            tex:SetSize(9, 9)
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            tex:SetBlendMode("ADD")
            tex:SetPoint("CENTER", host, p, 0, 0)
            hl.corners[i] = tex
        end
    end,
    color = function(hl, r, g, b)
        ColorAll(hl.corners, r, g, b)
        ShowAll(hl.corners)
    end,
    update = function(hl, host, phase)
        local t = (math.sin(phase * math.pi * 2) + 1) * 0.5
        local a = 0.4 + (0.6 * t)
        for _, tex in ipairs(hl.corners) do
            tex:SetAlpha(a)
        end
    end,
}

HighlightStyleImpl.brackets = {
    animated = true,
    speed = 0.5,
    build = function(hl, host)
        hl.corners = {}
        local legLen, thickness = 9, 2
        local points = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
        for _, p in ipairs(points) do
            local hBar = MakeBar(host, true, thickness)
            hBar:SetWidth(legLen)
            hBar:SetPoint(p, host, p, 0, 0)

            local vBar = MakeBar(host, false, thickness)
            vBar:SetHeight(legLen)
            vBar:SetPoint(p, host, p, 0, 0)

            hl.corners[#hl.corners + 1] = hBar
            hl.corners[#hl.corners + 1] = vBar
        end
    end,
    color = function(hl, r, g, b)
        ColorAll(hl.corners, r, g, b)
        ShowAll(hl.corners)
    end,
    update = function(hl, host, phase)
        local t = (math.sin(phase * math.pi * 2) + 1) * 0.5
        local a = 0.5 + (0.5 * t)
        for _, tex in ipairs(hl.corners) do
            tex:SetAlpha(a)
        end
    end,
}

HighlightStyleImpl.doublering = {
    animated = true,
    speed = 0.5,
    build = function(hl, host)
        hl.edgeTop = MakeBar(host, true, 2); AnchorEdge(hl.edgeTop, host, "top", 0)
        hl.edgeBottom = MakeBar(host, true, 2); AnchorEdge(hl.edgeBottom, host, "bottom", 0)
        hl.edgeLeft = MakeBar(host, false, 2); AnchorEdge(hl.edgeLeft, host, "left", 0)
        hl.edgeRight = MakeBar(host, false, 2); AnchorEdge(hl.edgeRight, host, "right", 0)

        hl.outerTop = MakeBar(host, true, 1); AnchorEdge(hl.outerTop, host, "top", 4)
        hl.outerBottom = MakeBar(host, true, 1); AnchorEdge(hl.outerBottom, host, "bottom", 4)
        hl.outerLeft = MakeBar(host, false, 1); AnchorEdge(hl.outerLeft, host, "left", 4)
        hl.outerRight = MakeBar(host, false, 1); AnchorEdge(hl.outerRight, host, "right", 4)
    end,
    color = function(hl, r, g, b)
        local all = { hl.edgeTop, hl.edgeBottom, hl.edgeLeft, hl.edgeRight,
                       hl.outerTop, hl.outerBottom, hl.outerLeft, hl.outerRight }
        ColorAll(all, r, g, b)
        ShowAll(all)
    end,
    update = function(hl, host, phase)
        local t = (math.sin(phase * math.pi * 2) + 1) * 0.5
        local innerA = 0.6 + (0.4 * t)
        local outerA = 0.15 + (0.3 * t)
        hl.edgeTop:SetAlpha(innerA); hl.edgeBottom:SetAlpha(innerA)
        hl.edgeLeft:SetAlpha(innerA); hl.edgeRight:SetAlpha(innerA)
        hl.outerTop:SetAlpha(outerA); hl.outerBottom:SetAlpha(outerA)
        hl.outerLeft:SetAlpha(outerA); hl.outerRight:SetAlpha(outerA)
    end,
}

HighlightStyleImpl.ants = {
    animated = true,
    speed = 0.9,
    build = function(hl, host)
        hl.dots = MakeDots(host, 34, 3)
    end,
    color = function(hl, r, g, b)
        ColorAll(hl.dots, r, g, b)
        ShowAll(hl.dots)
    end,
    update = function(hl, host, phase)
        local count = #hl.dots
        for i, d in ipairs(hl.dots) do
            PlaceOnPerimeter(host, d, ((i - 1) / count) + phase)
        end
    end,
}

HighlightStyleImpl.spin = {
    animated = true,
    speed = 1.4,
    build = function(hl, host)
        hl.dots = MakeDots(host, 5, 7)
    end,
    color = function(hl, r, g, b)
        ColorAll(hl.dots, r, g, b)
        ShowAll(hl.dots)
    end,
    update = function(hl, host, phase)
        local count = #hl.dots
        for i, d in ipairs(hl.dots) do
            PlaceOnPerimeter(host, d, ((i - 1) / count) + phase)
        end
    end,
}

HighlightStyleImpl.dashed = {
    animated = true,
    speed = 0.35,
    build = function(hl, host)
        hl.dots = {}
        for i = 1, 16 do
            local d = host:CreateTexture(nil, "OVERLAY")
            d:SetSize(7, 2)
            d:SetTexture("Interface\\Buttons\\WHITE8X8")
            d:SetBlendMode("ADD")
            hl.dots[i] = d
        end
    end,
    color = function(hl, r, g, b)
        ColorAll(hl.dots, r, g, b)
        ShowAll(hl.dots)
    end,
    update = function(hl, host, phase)
        local count = #hl.dots
        for i, d in ipairs(hl.dots) do
            local edge = PlaceOnPerimeter(host, d, ((i - 1) / count) + phase)
            if d.SetRotation then
                d:SetRotation((edge == "left" or edge == "right") and (math.pi / 2) or 0)
            end
        end
    end,
}

-- Hides every part any style might have created on `hl`, regardless of which style
-- built it - used both to clear an active highlight and to tear down a stale style's
-- parts before rebuilding for a newly selected one.
ClearHighlightVisualParts = function(hl)
    if not hl then
        return
    end
    local function H(t) if t then t:Hide() end end
    H(hl.wash)
    H(hl.edgeTop); H(hl.edgeBottom); H(hl.edgeLeft); H(hl.edgeRight)
    H(hl.outerTop); H(hl.outerBottom); H(hl.outerLeft); H(hl.outerRight)
    if hl.dots then
        for _, d in ipairs(hl.dots) do d:Hide() end
    end
    if hl.corners then
        for _, c in ipairs(hl.corners) do c:Hide() end
    end
end
addon.ClearHighlightVisualParts = ClearHighlightVisualParts

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

    local desiredStyle = (LegacyVendorDB and LegacyVendorDB.highlightStyle) or DEFAULT_HIGHLIGHT_STYLE
    if not HighlightStyleImpl[desiredStyle] then
        desiredStyle = DEFAULT_HIGHLIGHT_STYLE
    end

    local hl = button.LegacyVendorHighlight
    if hl and hl.style ~= desiredStyle then
        -- The user switched styles since this button was last highlighted: the cached
        -- part set belongs to the old style's shape, so tear it down and rebuild fresh
        -- rather than trying to reuse mismatched pieces.
        ClearHighlightVisualParts(hl)
        if hl.driver then
            hl.driver:SetScript("OnUpdate", nil)
        end
        if hl.host then
            hl.host:Hide()
        end
        hl = nil
        button.LegacyVendorHighlight = nil
    end

    if not hl then
        hl = { style = desiredStyle }

        -- Use a dedicated host frame above the item button so skin overlays (ElvUI/WindTools)
        -- do not hide our highlight textures.
        hl.host = CreateFrame("Frame", nil, button)
        local iconRegion = button.Icon or button.icon
        if iconRegion then
            hl.host:SetPoint("TOPLEFT", iconRegion, "TOPLEFT", -2, 2)
            hl.host:SetPoint("BOTTOMRIGHT", iconRegion, "BOTTOMRIGHT", 2, -2)
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

        HighlightStyleImpl[desiredStyle].build(hl, hl.host)

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

    hl.host:Show()

    local color = (LegacyVendorDB and LegacyVendorDB.highlightColor) or { r = 0.68, g = 0.45, b = 1.0, a = 0.85 }
    local r = color.r or 0.68
    local g = color.g or 0.45
    local b = color.b or 1.0

    local impl = HighlightStyleImpl[hl.style]
    impl.color(hl, r, g, b)

    if hl.border and hl.border.SetVertexColor then
        if hl.borderOrigColor then
            hl.border:SetVertexColor(hl.borderOrigColor.r, hl.borderOrigColor.g, hl.borderOrigColor.b, hl.borderOrigColor.a)
        end
    end

    if hl.icon and hl.icon.SetVertexColor and hl.iconOrigColor then
        hl.icon:SetVertexColor(hl.iconOrigColor.r, hl.iconOrigColor.g, hl.iconOrigColor.b, hl.iconOrigColor.a)
    end

    impl.update(hl, hl.host, hl.phase or 0)

    if impl.animated then
        local speed = impl.speed or 0.5
        hl.driver:SetScript("OnUpdate", function(_, elapsed)
            hl.accum = (hl.accum or 0) + elapsed
            if hl.accum < 0.03 then
                return
            end

            local dt = hl.accum
            hl.accum = 0
            hl.phase = ((hl.phase or 0) + (dt * speed)) % 1
            impl.update(hl, hl.host, hl.phase)
        end)
    else
        hl.driver:SetScript("OnUpdate", nil)
    end

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

-- The two whole-UI scans below (every frame in the game, every global variable)
-- are expensive. FindButtonForBagSlot used to redo both from scratch for every
-- single sellable item - with ~20 items and 12 retries, that was up to hundreds
-- of full UI walks per merchant visit, freezing the client for seconds. These
-- collect the raw candidate lists ONCE per highlight pass; FindButtonForBagSlot
-- then just filters/scores the (small) precomputed lists per bag/slot instead of
-- re-walking the whole UI each time.
local function CollectGlobalEnumCandidates()
    local list = {}
    local frame = EnumerateFrames()
    while frame do
        if frame.GetObjectType then
            local okType, objType = pcall(frame.GetObjectType, frame)
            if okType and (objType == "Button" or objType == "CheckButton" or objType == "ItemButton") then
                list[#list + 1] = frame
            end
        end
        frame = EnumerateFrames(frame)
    end
    return list
end

local function CollectLegacyNameCandidates()
    local list = {}
    for name, obj in pairs(_G) do
        if type(name) == "string" and type(obj) == "table" and obj.GetID and obj.IsShown then
            if name:find("ContainerFrame") and name:find("Item") then
                list[#list + 1] = obj
            end
        end
    end
    return list
end

local function FindButtonForBagSlot(bag, slot, globalEnumList, legacyNameList)
    local candidates = {}
    local seen = {}
    local isElvUILoaded = IsAddonLoadedSafe("ElvUI")

    local function AddCandidateImpl(button, source)
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

    -- A candidate frame belongs to another addon; an unrelated hook on a widget
    -- method it uses (e.g. buff-icon skinning) can throw when we merely inspect
    -- it. Isolate every call so one bad frame doesn't stop us finding the real target.
    local function AddCandidate(button, source)
        local ok, err = pcall(AddCandidateImpl, button, source)
        if not ok and LegacyVendorDB and LegacyVendorDB.debug then
            DebugPrint("AddCandidate error:", "source=", source, tostring(err))
        end
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
    -- NOTE: this Blizzard iterator's return shape has changed across client versions -
    -- some builds yield just the frame, others yield (index, frame) like ipairs. Only
    -- naming one loop variable silently binds it to whichever comes first (an index
    -- number on the ipairs-style builds), so pick whichever of the two is a table.
    if ContainerFrameUtil_EnumerateContainerFrames then
        for a, b in ContainerFrameUtil_EnumerateContainerFrames() do
            local containerFrame = (type(b) == "table" and b) or (type(a) == "table" and a) or nil
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

    -- Addon-agnostic frame enumeration. Use the precomputed list when the caller
    -- supplied one (the normal path - built once per highlight pass, not per item);
    -- only fall back to a live whole-UI walk if called without one.
    if globalEnumList then
        for _, frame in ipairs(globalEnumList) do
            AddCandidate(frame, "global-enum")
        end
    else
        local frame = EnumerateFrames()
        while frame do
            if frame.GetObjectType then
                local okType, objType = pcall(frame.GetObjectType, frame)
                if okType and (objType == "Button" or objType == "CheckButton" or objType == "ItemButton") then
                    AddCandidate(frame, "global-enum")
                end
            end
            frame = EnumerateFrames(frame)
        end
    end

    -- Legacy name scan fallback. Same caching approach as the frame walk above.
    if legacyNameList then
        for _, obj in ipairs(legacyNameList) do
            AddCandidate(obj, "legacy-name")
        end
    else
        for name, obj in pairs(_G) do
            if type(name) == "string" and type(obj) == "table" and obj.GetID and obj.IsShown then
                if name:find("ContainerFrame") and name:find("Item") then
                    AddCandidate(obj, "legacy-name")
                end
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

-- Bounded recursive walk of ONE known frame's own descendant tree (its bag window,
-- typically dozens to a few hundred frames) - NOT the whole UI. Used for bag-replacement
-- addons (like EllesmereUIBags) that build plain CreateFrame("ItemButton", ...) widgets
-- without exposing a `.Bags` lookup table the way ElvUI does.
local function CollectFrameTreeButtons(rootFrame, outButtons, seenButtons, maxDepth)
    if not rootFrame then
        return 0
    end

    local count = 0
    local visited = {}

    local function Visit(frame, depth)
        if not frame or visited[frame] or depth > maxDepth then
            return
        end
        visited[frame] = true

        if frame.GetObjectType and not seenButtons[frame] then
            local okType, objType = pcall(frame.GetObjectType, frame)
            if okType and (objType == "Button" or objType == "CheckButton" or objType == "ItemButton") then
                seenButtons[frame] = true
                outButtons[#outButtons + 1] = frame
                count = count + 1
            end
        end

        local numChildren = frame.GetNumChildren and frame:GetNumChildren() or 0
        if numChildren > 0 and frame.GetChildren then
            local okChildren, children = pcall(function() return { frame:GetChildren() } end)
            if okChildren then
                for _, child in ipairs(children) do
                    Visit(child, depth + 1)
                end
            end
        end
    end

    Visit(rootFrame, 0)
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

    -- EllesmereUI's bag replacement window: a single known root frame (EUI_Bags), walked
    -- directly instead of via the (much more expensive) whole-UI fallback.
    if scanned == 0 and IsAddonLoadedSafe("EllesmereUIBags") and _G.EUI_Bags then
        scanned = scanned + CollectFrameTreeButtons(_G.EUI_Bags, buttons, seen, 12)
        if scanned > 0 then
            source = "ellesmere"
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

-- Walks up from a bag button to whatever ScrollFrame contains it. Deliberately
-- generic: EllesmereUI, Blizzard and most bag addons all put their item grid in a
-- scroll child, so this needs no per-addon knowledge.
local function FindScrollFrameAncestor(frame)
    local f, depth = frame, 0
    while f and depth < 12 do
        if f.GetObjectType and f:GetObjectType() == "ScrollFrame" and f.SetVerticalScroll then
            return f
        end
        f = f.GetParent and f:GetParent() or nil
        depth = depth + 1
    end
    return nil
end

-- Scrolls a bag button into the middle of its scroll frame's viewport.
local function ScrollButtonIntoView(button)
    if not button then return false end

    local sf = FindScrollFrameAncestor(button)
    if not sf then return false end

    local child = sf.GetScrollChild and sf:GetScrollChild()
    if not child then return false end

    local childTop = child.GetTop and child:GetTop()
    local btnTop = button.GetTop and button:GetTop()
    if not (childTop and btnTop) then return false end

    -- Offset of the button from the top of the scrolling content, biased so the
    -- target lands partway down the viewport rather than flush against the edge.
    local viewHeight = (sf.GetHeight and sf:GetHeight()) or 0
    local target = (childTop - btnTop) - (viewHeight * 0.4)

    local range = (sf.GetVerticalScrollRange and sf:GetVerticalScrollRange()) or 0
    target = math.max(0, math.min(target, range))

    sf:SetVerticalScroll(target)
    return true
end

-- Buttons highlighted by the last pass, in bag order, for "find next match".
local highlightedButtons = {}
local findNextIndex = 0

-- Cycles through matching items, scrolling each into view. Lets a player reach the
-- matches that are laid out past the edge of the bag window's viewport, which no
-- amount of highlighting can make visible on its own.
function addon.ScrollToNextMatch()
    if #highlightedButtons == 0 then
        Print("No matching items to jump to.")
        return
    end

    for _ = 1, #highlightedButtons do
        findNextIndex = (findNextIndex % #highlightedButtons) + 1
        local entry = highlightedButtons[findNextIndex]
        if entry and entry.button and entry.button.IsVisible and entry.button:IsVisible() then
            if ScrollButtonIntoView(entry.button) then
                Print(("Showing %s  (%d of %d)"):format(
                    entry.link or "match", findNextIndex, #highlightedButtons))
                return
            end
        end
    end

    Print("Could not scroll your bag window - is it open?")
end

UpdateBagHighlightsBody = function()
    -- The sellable list is AUTHORITATIVE. Previously this walked the bag addon's
    -- buttons and asked "should this one sell?", while the Sell (N) button and the
    -- chat summary walked bag slots - two different traversals that could disagree,
    -- which is exactly how you got "Sell (6)" next to two highlighted items.
    -- Driving both from the same list makes them agree by construction.
    local _, _, items = CountSellable(true)

    if #items == 0 then
        if LegacyVendorDB and LegacyVendorDB.debug then
            DebugPrint("Highlight pass: nothing sellable.")
        end
        return
    end

    -- Index whatever buttons the active bag addon exposes by bag:slot, so the common
    -- case is a table lookup per item rather than a UI walk.
    --
    -- Bag addons pool buttons heavily - EllesmereUI reports ~220 buttons for ~150
    -- items - and a recycled button keeps the bag/slot ID of whatever it displayed
    -- last. So several buttons can claim the same bag:slot while only one is really
    -- showing that item. Two rules disambiguate:
    --   1. IsVisible(), not IsShown(). IsShown() is true for a button inside a
    --      hidden category container, so it happily matches parked pool entries.
    --   2. The displayed icon must match the icon of the item actually in that slot,
    --      which catches a recycled button that has not been re-rendered yet.
    local function ButtonDisplaysSlotItem(btn, bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not (info and info.iconFileID) then return true end
        local iconRegion = btn.icon or btn.Icon
        if not (iconRegion and iconRegion.GetTexture) then return true end
        local shown = iconRegion:GetTexture()
        if not shown then return false end
        return shown == info.iconFileID
    end

    local buttonBySlot = {}
    local customButtons, customSource, customScanned = CollectCustomBagButtons()
    for _, btn in ipairs(customButtons) do
        local b, sl = GetButtonBagAndSlot(btn)
        if b ~= nil and sl ~= nil and sl > 0 then
            local visible = btn.IsVisible and btn:IsVisible()
            if visible then
                local key = b .. ":" .. sl
                local existing = buttonBySlot[key]
                -- An icon-verified button always wins over an unverified one.
                if not existing then
                    buttonBySlot[key] = btn
                elseif not existing._lvVerified and ButtonDisplaysSlotItem(btn, b, sl) then
                    buttonBySlot[key] = btn
                end
                if buttonBySlot[key] == btn then
                    btn._lvVerified = ButtonDisplaysSlotItem(btn, b, sl) or nil
                end
            end
        end
    end

    local applied, missing, verified, offscreen = 0, 0, 0, 0
    wipe(highlightedButtons)
    findNextIndex = 0
    local globalEnumList, legacyNameList

    if LegacyVendorDB and LegacyVendorDB.debug then
        local sw = UIParent and UIParent:GetWidth() or 0
        local sh = UIParent and UIParent:GetHeight() or 0
        DebugPrint(string.format("Screen is %.0f x %.0f - anything outside that is off-screen:", sw, sh))
    end

    for _, item in ipairs(items) do
        local button = buttonBySlot[item.bag .. ":" .. item.slot]

        -- No bag-addon button for this slot: fall back to the generic search, but
        -- only build the expensive whole-UI lists if we actually get here.
        if not button then
            if not globalEnumList and #customButtons == 0 then
                globalEnumList = CollectGlobalEnumCandidates()
                legacyNameList = CollectLegacyNameCandidates()
            end
            if globalEnumList then
                local ok, found = pcall(FindButtonForBagSlot, item.bag, item.slot, globalEnumList, legacyNameList)
                button = ok and found or nil
            end
        end

        if button then
            if button._lvVerified then verified = verified + 1 end
            local shown = button.IsVisible and button:IsVisible()

            -- Where did this button actually end up on screen? IsVisible() is true
            -- for a button scrolled outside its parent scroll frame's viewport, so a
            -- correctly-placed highlight can still be somewhere the player cannot
            -- see. Coordinates make that case self-evident instead of a guess.
            if LegacyVendorDB and LegacyVendorDB.debug then
                local cx, cy = button:GetCenter()
                local alpha = button.GetEffectiveAlpha and button:GetEffectiveAlpha() or -1
                local w = button.GetWidth and button:GetWidth() or -1
                DebugPrint(string.format("  -> %s  bag=%d slot=%d  at(%.0f,%.0f) size=%.0f alpha=%.2f visible=%s",
                    tostring(item.link or "?"), item.bag, item.slot,
                    cx or -1, cy or -1, w, alpha, tostring(shown)))
            end

            if shown then
                -- A button can be "visible" yet sit outside the bag window's scroll
                -- viewport - EllesmereUI lays its list out past the screen edge, so
                -- these come back with negative screen coordinates. The highlight is
                -- applied correctly; the player just cannot see it without scrolling,
                -- so it is counted and surfaced rather than silently lost.
                local cx, cy = button:GetCenter()
                local sw = UIParent and UIParent:GetWidth() or 0
                local sh = UIParent and UIParent:GetHeight() or 0
                if not cx or not cy or cx < 0 or cy < 0 or cx > sw or cy > sh then
                    offscreen = offscreen + 1
                end

                local ok, err = pcall(ApplyHighlight, button)
                if ok then
                    applied = applied + 1
                    highlightedButtons[#highlightedButtons + 1] = { button = button, link = item.link }
                else
                    missing = missing + 1
                    if LegacyVendorDB and LegacyVendorDB.debug then
                        DebugPrint("ApplyHighlight error:", "bag=", item.bag, "slot=", item.slot, tostring(err))
                    end
                end
            else
                missing = missing + 1
            end
        else
            missing = missing + 1
            if LegacyVendorDB and LegacyVendorDB.debug then
                DebugPrint("No button found for sellable slot:", "bag=", item.bag, "slot=", item.slot,
                    (item.link or "?"))
            end
        end
    end

    addon.highlightOffscreenCount = offscreen

    if LegacyVendorDB and LegacyVendorDB.debug then
        DebugPrint(("Highlight pass: %d sellable, %d highlighted (%d icon-verified), %d off-screen, %d without a visible button (source=%s, buttons=%d)")
            :format(#items, applied, verified, offscreen, missing, tostring(customSource), customScanned or 0))
    end
end

-- Bag replacement addons recycle their item buttons on every re-render, which
-- silently invalidates every highlight we placed - the button we decorated now
-- shows a different item, or is parked back in the pool. Nothing told us to redo
-- the pass, so highlights drifted out of sync with the Sell (N) count after any
-- scroll, category change or bag refresh.
local bagRefreshHooked = false

local function InstallBagRefreshHooks()
    if bagRefreshHooked then return end

    local hookedAny = false

    -- EllesmereUI: RefreshBags() is its public rebuild entry point.
    local euiWindow = _G.EUI_BagsWindow
    if euiWindow and euiWindow.RefreshBags then
        hooksecurefunc(euiWindow, "RefreshBags", function()
            if LegacyVendorDB and LegacyVendorDB.enabled and LegacyVendorDB.highlightItems
                and MerchantFrame and MerchantFrame:IsShown() then
                if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
            end
        end)
        hookedAny = true
    end

    -- Blizzard's own container frames, for players not running a bag addon.
    if type(_G.ContainerFrame_Update) == "function" then
        hooksecurefunc("ContainerFrame_Update", function()
            if LegacyVendorDB and LegacyVendorDB.enabled and LegacyVendorDB.highlightItems
                and MerchantFrame and MerchantFrame:IsShown() then
                if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
            end
        end)
        hookedAny = true
    end

    -- Only latch once something was actually there to hook; the bag addon may not
    -- have created its frames yet the first time a merchant opens.
    if hookedAny then
        bagRefreshHooked = true
        DebugPrint("Installed bag-refresh hooks.")
    end
end
addon.InstallBagRefreshHooks = InstallBagRefreshHooks

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
-- Lifetime "gold reclaimed" tracking. Recorded per confirmed sale rather than from
-- the queue, so failed or skipped items never inflate it.
local function RecordSale(item)
    if not LegacyVendorDB then return end

    local st = LegacyVendorDB.stats
    if type(st) ~= "table" then
        st = { totalCopper = 0, totalItems = 0, byExpansion = {} }
        LegacyVendorDB.stats = st
    end
    st.byExpansion = st.byExpansion or {}

    local value = item and item.price or 0
    st.totalCopper = (st.totalCopper or 0) + value
    st.totalItems = (st.totalItems or 0) + 1

    local expID = item and item.expansion
    if expID then
        local row = st.byExpansion[expID]
        if not row then
            row = { copper = 0, items = 0 }
            st.byExpansion[expID] = row
        end
        row.copper = row.copper + value
        row.items = row.items + 1
    end

    local now = time and time() or nil
    st.firstSale = st.firstSale or now
    st.lastSale = now
end
addon.RecordSale = RecordSale

-- The item handed to UseContainerItem on the previous tick, awaiting verification.
local pendingSale = nil
-- Items the game refused to sell without a manual confirmation.
local blockedSales = {}
addon.blockedSales = blockedSales

-- UseContainerItem reports nothing about whether the sale actually happened, and a
-- pcall around it only catches Lua errors. A rare item still inside its group-trade
-- window raises a Blizzard confirmation ("will make it non-tradeable") that silently
-- stops the sale, so "the call did not error" is not evidence of anything. The only
-- reliable test is whether the item left the slot.
local function VerifyPendingSale()
    if not pendingSale then return end

    local item = pendingSale
    pendingSale = nil

    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    local stillThere = info and info.hyperlink and info.hyperlink == item.link

    if stillThere then
        blockedSales[#blockedSales + 1] = item
        DebugPrint("NOT sold (still in bag):", item.link or "?", "bag=", item.bag, "slot=", item.slot)
    else
        itemsSoldCount = itemsSoldCount + 1
        sessionSoldCopper = sessionSoldCopper + (item.price or 0)
        RecordSale(item)
        DebugPrint("Confirmed sold:", item.link or "?")
    end
end

-- WoW raises "selling this will make it non-tradeable, even if you buy it back"
-- for loot still inside its group-trade window. That prompt exists so a player does
-- not vendor something a raidmate could still be given, so it is opt-in and off by
-- default: accepting it on someone's behalf removes a warning the game deliberately
-- showed them. Only ever acts during one of our own sell runs.
local function TryAutoConfirmTradeTimer()
    if not isSelling then return end
    if not (LegacyVendorDB and LegacyVendorDB.autoConfirmTradeTimer) then return end

    local count = STATICPOPUP_NUMDIALOGS or 4
    for i = 1, count do
        local dialog = _G["StaticPopup" .. i]
        if dialog and dialog:IsShown() and type(dialog.which) == "string"
            and dialog.which:find("TRADE_TIMER", 1, true) then
            DebugPrint("Auto-confirming trade-timer prompt:", dialog.which)
            if StaticPopup_OnClick then
                StaticPopup_OnClick(dialog, 1)
            elseif dialog.button1 and dialog.button1:IsShown() then
                dialog.button1:Click()
            end
            return true
        end
    end
end

local function SellNextItem()
    -- A confirmation from the previous attempt may still be on screen.
    TryAutoConfirmTradeTimer()

    -- Settle the previous attempt before doing anything else.
    VerifyPendingSale()

    if not isSelling or #itemsToSell == 0 then
        isSelling = false
        if itemsSoldCount > 0 and LegacyVendorDB.showSummary then
            Print(string.format("Sold %d legacy item(s) for %s", itemsSoldCount, FormatMoney(sessionSoldCopper)))
        elseif itemsSoldCount == 0 and #blockedSales == 0 and LegacyVendorDB.showSummary then
            Print("No items were sold - items may have been moved or filters changed")
        end

        -- Never claim an item sold while it is still sitting in the bag.
        if #blockedSales > 0 then
            Print(string.format("|cFFFFCC00%d item(s) still need confirming:|r", #blockedSales))
            for i, it in ipairs(blockedSales) do
                if i <= 5 then print("   " .. (it.link or "?")) end
            end
            if #blockedSales > 5 then
                print(string.format("   ...and %d more", #blockedSales - 5))
            end
            Print("|cFF888888WoW warns before selling items still tradeable to your group. Click Sell again and accept, or enable auto-confirm in Settings.|r")
        end

        wipe(blockedSales)
        itemsSoldCount = 0
        sessionSoldCopper = 0
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
            -- Counted only once the slot is confirmed empty, on the next tick.
            item.link = containerInfo.hyperlink
            pendingSale = item
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

    wipe(blockedSales)
    pendingSale = nil
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
    
    DebugPrint(string.format("Starting sell: found %d items", #itemsToSell))

    if #itemsToSell == 0 then
        Print("Nothing matches your filters right now.")
        return
    end

    -- The full list goes to the debug log only. On screen it was duplicating the
    -- confirmation dialog, the Sell (N) button and the bag highlights all at once.
    for i, item in ipairs(itemsToSell) do
        DebugPrint(string.format("  %d. %s", i, item.link or "Unknown"))
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

                -- The item level ceiling first shipped at 620, a pre-squish number
                -- that cannot be reached on the current scale - so a saved 620 is
                -- protecting nothing at all. Changing the default alone does not
                -- help anyone who already has a value stored, which is everyone who
                -- ran a build before this one.
                if LegacyVendorDB.highIlvlThreshold == 620 then
                    LegacyVendorDB.highIlvlThreshold = 285
                end

                -- Same story for the seasonal hard floor, which is not user-facing
                -- but is read from the saved table if an old value is present.
                if LegacyVendorDB.strictSeasonalIlvlFloor == 620 then
                    LegacyVendorDB.strictSeasonalIlvlFloor = nil
                end

                -- One-time migration: an existing save may still have the old red
                -- highlight color baked in from before the light-purple redesign.
                -- Upgrade it if it looks untouched (exactly the old default); leave
                -- alone if it was ever customized.
                if LegacyVendorDB.highlightColor
                    and LegacyVendorDB.highlightColor.r == 1
                    and LegacyVendorDB.highlightColor.g == 0.2
                    and LegacyVendorDB.highlightColor.b == 0.2 then
                    LegacyVendorDB.highlightColor = { r = 0.68, g = 0.45, b = 1.0, a = 0.85 }
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
            
            -- A character bound to a profile gets it applied before anything is
            -- scanned, so the very first vendor visit already uses the right rules.
            if addon.Profiles and addon.Profiles.ApplyForCharacter then
                pcall(addon.Profiles.ApplyForCharacter)
            end

            -- Show loaded message with version info
            local versionInfo = addon.compatInfo or "Retail"
            Print("Loaded (" .. versionInfo .. "). Type /lv for options.")
            frame:UnregisterEvent("ADDON_LOADED")
        end
        
    elseif event == "MERCHANT_SHOW" then
        if LegacyVendorDB and LegacyVendorDB.enabled then
            -- Show/update the sell button on merchant frame
            InstallBagRefreshHooks()
            InvalidateSellableCache()
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
                    local _, _, items = CountSellable()
                    if #items > 0 then
                        -- Short, and only if the user wants chat output at all: the
                        -- Sell (N) button and the bag highlights already say this.
                        if LegacyVendorDB.showSummary then
                            Print(string.format("%d item(s) ready to sell.", #items))
                        end
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
        if addon.findButton then
            addon.findButton:Hide()
        end
        if addon.UpdateBagHighlights then
            addon.UpdateBagHighlights()
        end

    elseif event == "TRANSMOG_COLLECTION_SOURCE_ADDED" or event == "TRANSMOG_COLLECTION_SOURCE_REMOVED"
        or event == "NEW_TOY_ADDED" or event == "NEW_MOUNT_ADDED" or event == "NEW_PET_ADDED" then
        ResetCollectibleCache()
        if LegacyVendorDB and LegacyVendorDB.enabled and MerchantFrame and MerchantFrame:IsShown() then
            addon.ScheduleMerchantButtonUpdate()
            addon.ScheduleHighlightUpdate()
        end

    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        local merchantShown = MerchantFrame and MerchantFrame:IsShown()
        -- Only trace when the merchant is actually open. Logging every bag event
        -- during normal play floods the export log into uselessness.
        if LegacyVendorDB and LegacyVendorDB.debug and merchantShown then
            DebugPrint("Bag event:", event, "-> recount queued")
        end
        InvalidateSellableCache()
        if LegacyVendorDB and LegacyVendorDB.enabled and merchantShown then
            addon.ScheduleMerchantButtonUpdate()
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

        -- Explain the difference between the count on this button and the number of
        -- highlights actually on screen, rather than leaving it looking like a bug.
        local off = addon.highlightOffscreenCount or 0
        if off > 0 and LegacyVendorDB and LegacyVendorDB.highlightItems then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("|cFFFFCC00%d of these are further down in your bags|r"):format(off), 1, 1, 1, true)
            GameTooltip:AddLine("Scroll your bags to see them highlighted.", 0.7, 0.7, 0.7, true)
        end

        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    addon.sellButton = btn

    -- Jump-to-match button. Only appears when some matching items are laid out
    -- past the edge of the bag window's viewport, where a highlight cannot be seen.
    local find = CreateFrame("Button", "LegacyVendorFindButton", MerchantFrame, "UIPanelButtonTemplate")
    find:SetSize(24, 24)
    find:SetPoint("LEFT", btn, "RIGHT", 2, 0)
    find:SetText("v")
    find:Hide()
    find:SetScript("OnClick", function()
        if addon.ScrollToNextMatch then addon.ScrollToNextMatch() end
    end)
    find:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("|cFFFFD100Find next match|r")
        GameTooltip:AddLine(("%d matching item(s) are further down in your bags."):format(
            addon.highlightOffscreenCount or 0), 1, 1, 1, true)
        GameTooltip:AddLine("Click to scroll your bags to the next one.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    find:SetScript("OnLeave", function() GameTooltip:Hide() end)
    addon.findButton = find
end

function addon.UpdateMerchantButton()
    -- Create button if it doesn't exist
    if not addon.sellButton then
        CreateSellButton()
    end

    if not addon.sellButton then return end

    -- While a sale is running, the button reflects what's left in the queue being
    -- consumed rather than a fresh scan - a rescan mid-sale would race the sell loop
    -- and can briefly disagree with it while items are still locked/in flight.
    local count
    if isSelling then
        count = #itemsToSell
    else
        -- Read-only count: must NOT be ScanBags(), which would clobber the sell queue.
        local startTime = LegacyVendorDB and LegacyVendorDB.debug and debugprofilestop() or nil
        count = CountSellable()
        if startTime then
            DebugPrint(string.format("CountSellable took %.2f ms (%d sellable)", debugprofilestop() - startTime, count))
        end
    end

    addon.sellButton:SetText(string.format("Sell (%d)", count))

    if count > 0 then
        addon.sellButton:Enable()
    else
        addon.sellButton:Disable()
    end

    addon.sellButton:Show()

    if addon.findButton then
        local off = addon.highlightOffscreenCount or 0
        addon.findButton:SetShown(off > 0 and LegacyVendorDB and LegacyVendorDB.highlightItems and true or false)
    end
end

-- BAG_UPDATE fires once per bag, so a single vendored item can emit several events
-- back to back. Coalesce them into one recount so the button updates immediately to
-- a human without rescanning bags several times per action.
local merchantButtonUpdatePending = false
function addon.ScheduleMerchantButtonUpdate()
    if merchantButtonUpdatePending then
        return
    end
    merchantButtonUpdatePending = true
    C_Timer.After(0.05, function()
        merchantButtonUpdatePending = false
        if LegacyVendorDB and LegacyVendorDB.enabled and MerchantFrame and MerchantFrame:IsShown() then
            addon.UpdateMerchantButton()
        end
    end)
end

-- ==========================================
-- TOOLTIP INTEGRATION
-- ==========================================
-- Puts the sell decision, and the reason for it, on the item itself. All of this
-- reasoning already existed inside ShouldSellItem; until now it was only visible in
-- debug mode, so a user had no way to ask "why is this one not selling?".

local tooltipBusy = false

local function AppendSellLine(tooltip, bag, slot)
    if not LegacyVendorDB or not LegacyVendorDB.enabled then return end
    if LegacyVendorDB.showTooltipInfo == false then return end
    if not tooltip or not tooltip.AddLine then return end

    -- ShouldSellItem can itself read tooltip data (source detection), so guard
    -- against re-entering this hook from inside our own evaluation.
    if tooltipBusy then return end
    tooltipBusy = true

    -- ShouldSellItem returns (true, itemLink, count, price) when it will sell, and
    -- (false, reason) when it will not - so the second slot means different things.
    local ok, willSell, second, _third, fourth = pcall(ShouldSellItem, bag, slot)

    tooltipBusy = false
    if not ok then return end

    if willSell then
        local price = fourth
        local text = "|cFF00CCFFLegacy Vendor:|r |cFF44FF44will sell|r"
        if price and price > 0 then
            text = text .. " |cFF888888(" .. FormatMoney(price) .. ")|r"
        end
        tooltip:AddLine(text)
    elseif second then
        tooltip:AddLine("|cFF00CCFFLegacy Vendor:|r |cFFFFCC00keeping|r |cFF888888- " .. second .. "|r")
    else
        return
    end

    tooltip:Show()
end

do
    -- SetBagItem is the one call that gives us bag+slot directly, which is what the
    -- filters need; hooking it covers bag, bank and most bag-addon tooltips.
    if GameTooltip and GameTooltip.SetBagItem then
        hooksecurefunc(GameTooltip, "SetBagItem", function(self, bag, slot)
            AppendSellLine(self, bag, slot)
        end)
    end
    if ItemRefTooltip and ItemRefTooltip.SetBagItem then
        hooksecurefunc(ItemRefTooltip, "SetBagItem", function(self, bag, slot)
            AppendSellLine(self, bag, slot)
        end)
    end
end

-- Register events
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
-- Collection state changed: drop the cached "is this uncollected" answers so a newly
-- learned appearance/mount/toy/pet stops being protected straight away.
frame:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED")
frame:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_REMOVED")
frame:RegisterEvent("NEW_TOY_ADDED")
frame:RegisterEvent("NEW_MOUNT_ADDED")
frame:RegisterEvent("NEW_PET_ADDED")

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
        Print("  /lv setup - Guided setup: three questions instead of forty options")
        Print("  /lv protected - Manage the never-sell list")
        Print("  /lv find - Scroll your bags to the next matching item")
        Print("  /lv stats - How much gold you have reclaimed, by expansion")
        Print("  /lv export | /lv import - Share your filter setup as a string")
        Print("  /lv profiles - Save and switch between named filter setups")
        Print("  /lv exportlog - Open a copyable window with the debug log")
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
        local _, scanGold, items = CountSellable()
        if #items == 0 then
            Print("No legacy BoP items found to sell.")
        else
            Print(string.format("Found %d item(s) worth approximately %s:", #items, FormatMoney(scanGold)))
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
            Print("Hover over an item and use /lv exclude to toggle it, or /lv protected to manage the list.")
        end
        
    elseif msg == "reset" then
        LegacyVendorDB = CopyTable(defaults)
        Print("Settings reset to default.")
        
    elseif msg == "debug" then
        LegacyVendorDB.debug = not LegacyVendorDB.debug
        Print("Debug mode " .. (LegacyVendorDB.debug and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r") .. " - use /lv exportlog to view/copy the log.")

    elseif msg == "profiles" or msg == "profile" then
        if addon.Profiles then addon.Profiles.Open() end

    elseif msg == "export" then
        if addon.Share then addon.Share.Open("export") end

    elseif msg == "import" then
        if addon.Share then addon.Share.Open("import") end

    elseif msg == "stats" then
        local st = LegacyVendorDB.stats
        if not st or (st.totalItems or 0) == 0 then
            Print("You have not sold anything with LegacyVendor yet.")
        else
            Print(string.format("Reclaimed |cFFFFD100%s|r from |cFFFFD100%d|r old item(s).",
                FormatMoney(st.totalCopper or 0), st.totalItems or 0))

            -- Per-expansion breakdown, biggest earner first: this is the part a
            -- generic gold tracker cannot tell you.
            local rows = {}
            for expID, row in pairs(st.byExpansion or {}) do
                rows[#rows + 1] = { id = expID, copper = row.copper or 0, items = row.items or 0 }
            end
            table.sort(rows, function(a, b) return a.copper > b.copper end)

            for i, row in ipairs(rows) do
                if i > 8 then break end
                local exp = addon.EXPANSIONS[row.id]
                local name = exp and (exp.short or exp.name) or ("Exp " .. tostring(row.id))
                print(string.format("   %-10s %s  |cFF888888(%d items)|r",
                    name, FormatMoney(row.copper), row.items))
            end

            if st.firstSale and date then
                print("|cFF888888   since " .. date("%d %b %Y", st.firstSale) .. "|r")
            end
        end

    elseif msg == "resetstats" then
        LegacyVendorDB.stats = { totalCopper = 0, totalItems = 0, byExpansion = {} }
        Print("Lifetime totals cleared.")

    elseif msg == "find" or msg == "next" then
        if addon.ScrollToNextMatch then addon.ScrollToNextMatch() end

    elseif msg == "protected" or msg == "exclusions" then
        if addon.Exclusions then addon.Exclusions.Open() end

    elseif msg == "setup" or msg == "wizard" then
        if addon.Wizard then addon.Wizard.Open() end

    elseif msg == "exportlog" or msg == "log" then
        if addon.ShowExportLog then addon.ShowExportLog() end

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
        local st = LegacyVendorDB.stats
        if st and (st.totalCopper or 0) > 0 then
            GameTooltip:AddLine(string.format("Reclaimed %s from %d old item(s)",
                FormatMoney(st.totalCopper), st.totalItems or 0), 1, 0.82, 0)
        end
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
