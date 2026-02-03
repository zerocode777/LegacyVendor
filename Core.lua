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
    [11] = { id = 11, name = "Midnight", short = "MN", enabled = false }, -- Current expansion - always excluded
}

-- Current expansion ID - will be overridden by Compat.lua if loaded
if not addon.CURRENT_EXPANSION then
    addon.CURRENT_EXPANSION = 11
end

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

-- Non-Equippable Item Types (classID from GetItemInfoInstant)
addon.ITEM_TYPES = {
    [0] = { name = "Consumables (Food/Potions)", enabled = false },  -- Consumable
    [1] = { name = "Containers (Bags)", enabled = false },           -- Container
    [5] = { name = "Reagents (Crafting)", enabled = false },         -- Reagent
    [7] = { name = "Trade Goods (Materials)", enabled = false },     -- Tradeskill
    [9] = { name = "Recipes", enabled = false },                     -- Recipe
    [12] = { name = "Quest Items", enabled = false },                -- Quest
    [13] = { name = "Keys", enabled = false },                       -- Key
    [15] = { name = "Miscellaneous", enabled = false },              -- Miscellaneous
}

-- Bind Types for filtering
addon.BIND_TYPES = {
    bop = { name = "Bind on Pickup (Soulbound)", enabled = true },
    boe = { name = "Bind on Equip (Bound)", enabled = false },
    unbound = { name = "Not Bound (Food, Reagents)", enabled = false },
}

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
    highlightItems = true, -- Highlight sellable items in bags
    highlightColor = { r = 1, g = 0.2, b = 0.2, a = 0.8 }, -- Red glow by default
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

-- Legacy function for backwards compatibility
local function IsBindOnPickup(bag, slot)
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not itemLocation:IsValid() then return false end
    local itemID = C_Item.GetItemID(itemLocation)
    if not itemID then return false end
    return GetItemBindStatus(bag, slot, itemID) == "bop"
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
    
    -- === FILTER 1: RARITY (Quality) ===
    if db.rarities and db.rarities[quality] ~= nil then
        if not db.rarities[quality] then
            DebugPrint("Rarity not enabled:", quality, itemLink)
            return false
        end
    end
    
    -- === FILTER 2: BIND STATUS ===
    local bindStatus = GetItemBindStatus(bag, slot, itemID)
    DebugPrint("Bind status for", itemLink, ":", bindStatus or "nil")
    
    local bindAllowed = false
    if bindStatus == "bop" and db.sellBoP then
        bindAllowed = true
    elseif bindStatus == "boe" and db.sellBoE then
        bindAllowed = true
    elseif bindStatus == "unbound" and db.sellUnbound then
        bindAllowed = true
    elseif bindStatus == "bou" and db.sellUnbound then
        -- Bind on Use items treated as unbound
        bindAllowed = true
    end
    
    if not bindAllowed then
        DebugPrint("Bind type not enabled:", bindStatus, itemLink)
        return false
    end
    
    -- === FILTER 3: EXPANSION ===
    local expansionID = GetItemExpansionID(itemID)
    if not expansionID then 
        DebugPrint("Could not determine expansion:", itemLink)
        return false 
    end
    
    -- Check if expansion is enabled for selling
    if not db.expansions[expansionID] then
        DebugPrint("Expansion disabled:", expansionID, itemLink)
        return false
    end
    
    -- Never sell items from current expansion or newer
    if expansionID >= addon.CURRENT_EXPANSION then
        DebugPrint("Current expansion item, skipping:", itemLink)
        return false
    end
    
    -- === FILTER 4: EQUIPMENT SLOTS (for equippable items) ===
    local isEquipment = equipLoc and equipLoc ~= ""
    
    if isEquipment then
        -- Check if this equipment slot is enabled
        if db.equipSlots and db.equipSlots[equipLoc] ~= nil then
            if not db.equipSlots[equipLoc] then
                DebugPrint("Equipment slot not enabled:", equipLoc, itemLink)
                return false
            end
        end
    end
    
    -- === FILTER 5: ITEM TYPES (for non-equippable items) ===
    if not isEquipment then
        -- For consumables, reagents, etc. - check if this item type is enabled
        if db.itemTypes and classID and db.itemTypes[classID] ~= nil then
            if not db.itemTypes[classID] then
                DebugPrint("Item type not enabled:", classID, "(class ID)", itemLink)
                return false
            end
        elseif classID and classID ~= 2 and classID ~= 4 then
            -- Non-equippable item with a classID not in our filter list
            -- classID 2 = Weapon, 4 = Armor (handled by equipSlots)
            -- If it's not in our itemTypes list, skip it unless itemTypes filter is empty/disabled
            local hasAnyItemTypeEnabled = false
            if db.itemTypes then
                for typeID, enabled in pairs(db.itemTypes) do
                    if enabled then
                        hasAnyItemTypeEnabled = true
                        break
                    end
                end
            end
            if hasAnyItemTypeEnabled then
                DebugPrint("Non-equipment item type not in enabled list:", classID, itemLink)
                return false
            end
        end
    end
    
    -- Check minimum item level
    local itemLevel = itemInfo[4] or 0
    if itemLevel < db.minItemLevel then
        DebugPrint("Below min item level:", itemLink)
        return false
    end
    
    DebugPrint("Will sell:", itemLink, "Expansion:", expansionID, "Quality:", quality, "Bind:", bindStatus, "Class:", classID)
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
-- BAG ITEM HIGHLIGHTING (DISABLED - NEEDS MORE TESTING)
-- ==========================================
-- This feature is temporarily disabled as it causes issues on some WoW versions
-- The highlighting code has been commented out for stability

local function UpdateBagHighlights()
    -- Disabled for now
end

local function ScheduleHighlightUpdate()
    -- Disabled for now
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
    Print(string.format("Attempting to sell: %s (bag %d, slot %d)", item.link or "Unknown", item.bag, item.slot))
    
    -- Verify item is still there (using modern API)
    local containerInfo = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if containerInfo and containerInfo.hyperlink then
        Print("  Item verified in slot, selling...")
        -- Use the container API for selling
        -- This works when merchant window is open
        local success, err = pcall(function()
            C_Container.UseContainerItem(item.bag, item.slot)
        end)
        
        if success then
            itemsSoldCount = itemsSoldCount + 1
            Print("  Sold successfully!")
        else
            Print("  FAILED to sell: " .. (err or "unknown error"))
        end
    else
        Print("  Item no longer in slot, skipping")
    end
    
    -- Schedule next sell with delay to avoid API throttling
    local delay = LegacyVendorDB.sellDelay or 0.2
    C_Timer.After(delay, SellNextItem)
end

-- Start selling process
local function StartSelling()
    if isSelling then return end
    
    ScanBags()
    
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
            end
            
            -- Show loaded message with version info
            local versionInfo = addon.compatInfo or "Retail"
            Print("Loaded (" .. versionInfo .. "). Type /lv for options.")
            frame:UnregisterEvent("ADDON_LOADED")
        end
        
    elseif event == "MERCHANT_SHOW" then
        if LegacyVendorDB and LegacyVendorDB.enabled then
            -- Show/update the sell button on merchant frame
            addon.UpdateMerchantButton()
            
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
        if addon.sellButton then
            addon.sellButton:Hide()
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
        local itemLink = GameTooltip:GetItem()
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
                print(string.format("  %d. %s %s", i, exp.name, status))
            end
        end
        Print("Use '/lv exp <number>' to toggle an expansion.")
        
    elseif msg == "minimap" then
        if LegacyVendorDB.minimapButton then
            LegacyVendorDB.minimapButton.hide = not LegacyVendorDB.minimapButton.hide
            if LegacyVendorDB.minimapButton.hide then
                addon.minimapButton:Hide()
                Print("Minimap button hidden. Use /lv minimap to show.")
            else
                addon.minimapButton:Show()
                Print("Minimap button shown.")
            end
        end
        
    elseif msg == "resetbutton" then
        if LegacyVendorDB.minimapButton then
            -- Reset to default minimap-attached position
            LegacyVendorDB.minimapButton.freeform = false
            LegacyVendorDB.minimapButton.minimapPos = 220
            LegacyVendorDB.minimapButton.freeformX = nil
            LegacyVendorDB.minimapButton.freeformY = nil
            if addon.minimapButton and addon.minimapButton.UpdatePosition then
                addon.minimapButton.UpdatePosition()
            end
            Print("Minimap button reset to default position around minimap.")
        end
        
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
local function GetMinimapShape()
    -- Check if a minimap addon has defined a custom shape function
    if GetMinimapShape then
        return GetMinimapShape()
    end
    -- Default to circular (ROUND)
    return "ROUND"
end

-- Calculate the radius for button positioning based on minimap shape and size
-- For square minimaps, we need different radius at corners vs edges
local function GetMinimapRadius(angle)
    local shape = GetMinimapShape()
    
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
    
    local button = CreateFrame("Button", "LegacyVendorMinimapButton", UIParent)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
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
            -- Freeform mode: position anywhere on screen
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
            -- Circular/minimap-attached mode
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
