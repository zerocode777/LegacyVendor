-- LegacyVendor Compatibility Layer
-- Handles API differences between Retail, Classic, Cataclysm, etc.

local addonName, addon = ...

-- Detect WoW version
local tocVersion = select(4, GetBuildInfo())
addon.isRetail = tocVersion >= 100000
addon.isCata = tocVersion >= 40000 and tocVersion < 50000
addon.isWrath = tocVersion >= 30000 and tocVersion < 40000
addon.isClassicEra = tocVersion < 20000
addon.isClassic = not addon.isRetail

-- Version-specific expansion list
if addon.isClassicEra then
    -- Classic Era only has Vanilla
    addon.MAX_EXPANSION = 0
    addon.CURRENT_EXPANSION = 0
elseif addon.isCata then
    -- Cataclysm Classic
    addon.MAX_EXPANSION = 3
    addon.CURRENT_EXPANSION = 3
elseif addon.isWrath then
    -- WotLK Classic (if still exists)
    addon.MAX_EXPANSION = 2
    addon.CURRENT_EXPANSION = 2
else
    -- Retail - Midnight
    addon.MAX_EXPANSION = 11
    addon.CURRENT_EXPANSION = 11
end

-- ==========================================
-- CONTAINER API COMPATIBILITY
-- ==========================================

-- C_Container compatibility (doesn't exist in Classic)
if not C_Container then
    C_Container = {}
    
    C_Container.GetContainerNumSlots = function(bag)
        return GetContainerNumSlots(bag)
    end
    
    C_Container.GetContainerItemInfo = function(bag, slot)
        local texture, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID, isBound = GetContainerItemInfo(bag, slot)
        if not texture then return nil end
        return {
            iconFileID = texture,
            stackCount = itemCount,
            isLocked = locked,
            quality = quality,
            isReadable = readable,
            hasLoot = lootable,
            hyperlink = itemLink,
            isFiltered = isFiltered,
            hasNoValue = noValue,
            itemID = itemID,
            isBound = isBound,
        }
    end
    
    C_Container.UseContainerItem = function(bag, slot)
        UseContainerItem(bag, slot)
    end
    
    C_Container.GetContainerItemID = function(bag, slot)
        return GetContainerItemID(bag, slot)
    end
end

-- ==========================================
-- C_ITEM API COMPATIBILITY
-- ==========================================

if not C_Item then
    C_Item = {}
end

if not C_Item.GetItemInfo then
    C_Item.GetItemInfo = function(itemID)
        return GetItemInfo(itemID)
    end
end

if not C_Item.GetItemID then
    C_Item.GetItemID = function(itemLocation)
        if itemLocation and itemLocation.IsValid and itemLocation:IsValid() then
            local bag, slot = itemLocation:GetBagAndSlot()
            if bag and slot then
                return GetContainerItemID(bag, slot)
            end
        end
        return nil
    end
end

if not C_Item.IsBound then
    C_Item.IsBound = function(itemLocation)
        if itemLocation and itemLocation.IsValid and itemLocation:IsValid() then
            local bag, slot = itemLocation:GetBagAndSlot()
            if bag and slot then
                local _, _, _, _, _, _, _, _, _, _, isBound = GetContainerItemInfo(bag, slot)
                return isBound
            end
        end
        return false
    end
end

-- ==========================================
-- ITEM LOCATION COMPATIBILITY
-- ==========================================

if not ItemLocation then
    ItemLocation = {}
    ItemLocation.__index = ItemLocation
    
    function ItemLocation:CreateFromBagAndSlot(bag, slot)
        local loc = setmetatable({}, ItemLocation)
        loc.bag = bag
        loc.slot = slot
        return loc
    end
    
    function ItemLocation:IsValid()
        if not self.bag or not self.slot then return false end
        local itemID = GetContainerItemID(self.bag, self.slot)
        return itemID ~= nil
    end
    
    function ItemLocation:GetBagAndSlot()
        return self.bag, self.slot
    end
end

-- ==========================================
-- C_TIMER COMPATIBILITY
-- ==========================================

if not C_Timer then
    C_Timer = {}
    
    C_Timer.After = function(delay, callback)
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                callback()
            end
        end)
    end
    
    C_Timer.NewTimer = function(delay, callback)
        C_Timer.After(delay, callback)
        return {} -- Dummy timer object
    end
end

-- ==========================================
-- SETTINGS API COMPATIBILITY
-- ==========================================

-- Settings API doesn't exist in Classic
if not Settings then
    addon.useSimpleConfig = true
else
    addon.useSimpleConfig = false
end

-- ==========================================
-- NUM_BAG_SLOTS COMPATIBILITY
-- ==========================================

if not NUM_BAG_SLOTS then
    NUM_BAG_SLOTS = 4
end

-- Some versions use different constants
if not NUM_TOTAL_EQUIPPED_BAG_SLOTS then
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = NUM_BAG_SLOTS
end

-- ==========================================
-- STATIC POPUP COMPATIBILITY
-- ==========================================

-- Ensure StaticPopupDialogs exists
if not StaticPopupDialogs then
    StaticPopupDialogs = {}
end

-- ==========================================
-- COPY TABLE COMPATIBILITY
-- ==========================================

if not CopyTable then
    function CopyTable(t)
        if type(t) ~= "table" then return t end
        local copy = {}
        for k, v in pairs(t) do
            if type(v) == "table" then
                copy[k] = CopyTable(v)
            else
                copy[k] = v
            end
        end
        return copy
    end
end

-- ==========================================
-- STRING TRIM COMPATIBILITY
-- ==========================================

if not string.trim then
    function string.trim(s)
        return s:match("^%s*(.-)%s*$")
    end
end

-- ==========================================
-- GET EXPANSION FOR ITEM (Classic Compatible)
-- ==========================================

-- In Classic, items don't have expansion IDs in GetItemInfo
-- We need to estimate based on item level or just return 0
function addon.GetItemExpansionCompat(itemID)
    if addon.isClassicEra then
        return 0 -- Everything is Classic
    end
    
    local itemInfo = { GetItemInfo(itemID) }
    if not itemInfo[1] then return nil end
    
    -- Try to get expansion ID (retail only, position 15)
    local expansionID = itemInfo[15]
    
    if expansionID then
        return expansionID
    end
    
    -- Fallback: estimate from item level
    local itemLevel = itemInfo[4] or 0
    
    if addon.isCata then
        if itemLevel <= 66 then return 0        -- Classic
        elseif itemLevel <= 164 then return 1   -- TBC
        elseif itemLevel <= 284 then return 2   -- WotLK
        else return 3                            -- Cataclysm
        end
    elseif addon.isWrath then
        if itemLevel <= 66 then return 0        -- Classic
        elseif itemLevel <= 164 then return 1   -- TBC
        else return 2                            -- WotLK
        end
    else
        -- Retail fallback
        if itemLevel <= 66 then return 0
        elseif itemLevel <= 164 then return 1
        elseif itemLevel <= 284 then return 2
        elseif itemLevel <= 416 then return 3
        elseif itemLevel <= 616 then return 4
        elseif itemLevel <= 750 then return 5
        elseif itemLevel <= 1000 then return 6
        elseif itemLevel <= 475 then return 7
        elseif itemLevel <= 252 then return 8
        elseif itemLevel <= 528 then return 9
        elseif itemLevel <= 680 then return 10
        else return 11
        end
    end
end

-- ==========================================
-- ADDON COMPARTMENT (Retail only)
-- ==========================================

addon.hasAddonCompartment = AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon

-- Print compatibility info on load
addon.compatInfo = string.format("WoW %s | %s | Max Expansion: %d",
    tocVersion,
    addon.isRetail and "Retail" or (addon.isCata and "Cataclysm" or (addon.isWrath and "WotLK" or "Classic Era")),
    addon.MAX_EXPANSION or 0
)
