-- Loaded only by LegacyVendor_Forever.toc. Item rules that replace the expansion
-- model on Forever, wired into Core's ShouldSellItem through two hooks:
--
--   addon.GetIlvlLimit(db, itemID, info)  -> item level hard-stop limit, or nil
--   addon.ForeverItemRule(db, info)       -> false+reason (keep), true (sell), nil
--
-- `info` carries what Core already resolved: itemID, link, equipLoc, classID,
-- subClassID, reqLevel, bag, slot.
local _, addon = ...

if not addon.isForever then return end

local CLASS_ARMOR, CLASS_WEAPON = 4, 2
local ARMOR_CLOTH, ARMOR_LEATHER, ARMOR_MAIL, ARMOR_PLATE, ARMOR_SHIELD = 1, 2, 3, 4, 6
local WEAPON_WAND = 19

-- Heaviest armour each class can ever wear. A class not listed here is unknown to
-- this table, and unknown never counts as "unusable" - a wrong guess would sell gear.
local MAX_ARMOR = {
    WARRIOR = ARMOR_PLATE, PALADIN = ARMOR_PLATE,
    HUNTER = ARMOR_MAIL, SHAMAN = ARMOR_MAIL,
    ROGUE = ARMOR_LEATHER, DRUID = ARMOR_LEATHER,
    PRIEST = ARMOR_CLOTH, MAGE = ARMOR_CLOTH, WARLOCK = ARMOR_CLOTH,
}
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local WAND_CLASSES = { PRIEST = true, MAGE = true, WARLOCK = true }

-- Slots whose armour type is restricted. Cloaks are "cloth" for every class, and
-- rings, necks and trinkets have no armour type at all.
local ARMOR_TYPED_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true,
    INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}

local function PlayerClassFile()
    local _, classFile = UnitClass("player")
    return classFile
end

-- "Classes: Mage, Warlock" line on class-restricted items, matched via the game's
-- own localized format string and class names so it works in every locale.
local function FailsClassRestrictionLine(bag, slot)
    if not (ITEM_CLASSES_ALLOWED and C_TooltipInfo and C_TooltipInfo.GetBagItem) then
        return false
    end
    local prefix = ITEM_CLASSES_ALLOWED:match("^(.-)%%s")
    local data = prefix and C_TooltipInfo.GetBagItem(bag, slot)
    if not (data and data.lines) then return false end

    local classFile = PlayerClassFile()
    local names = {
        LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile],
        LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classFile],
    }
    for _, line in ipairs(data.lines) do
        local text = line.leftText or ""
        if text:sub(1, #prefix) == prefix then
            local allowed = text:sub(#prefix + 1)
            for _, name in ipairs(names) do
                if name and allowed:find(name, 1, true) then return false end
            end
            return true
        end
    end
    return false
end

--- True when this character's class can never equip the item, at any level.
function addon.IsNeverUsableByClass(info)
    local classFile = PlayerClassFile()
    local maxArmor = MAX_ARMOR[classFile]
    if not maxArmor then return false end

    if info.classID == CLASS_ARMOR then
        if info.subClassID == ARMOR_SHIELD then
            return not SHIELD_CLASSES[classFile]
        end
        if ARMOR_TYPED_SLOTS[info.equipLoc] and (info.subClassID or 0) > maxArmor
            and info.subClassID <= ARMOR_PLATE then
            return true
        end
    elseif info.classID == CLASS_WEAPON and info.subClassID == WEAPON_WAND then
        return not WAND_CLASSES[classFile]
    end

    return info.bag ~= nil and FailsClassRestrictionLine(info.bag, info.slot)
end

local function IsSoulbound(bag, slot)
    if not (ItemLocation and C_Item and C_Item.IsBound) then return false end
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return location:IsValid() and C_Item.IsBound(location) == true
end

local function IsUnusableJunk(db, info)
    if not db.sellUnusableGear then return false end
    if info.classID ~= CLASS_ARMOR and info.classID ~= CLASS_WEAPON then return false end
    return IsSoulbound(info.bag, info.slot) and addon.IsNeverUsableByClass(info)
end

-- ==========================================
-- EQUIPMENT SETS
-- ==========================================
-- itemID -> set name. Matching on itemID can over-protect a duplicate copy, which
-- is the safe direction. Rebuilt lazily after EQUIPMENT_SETS_CHANGED.
local setItems

local function BuildSetItems()
    local map = {}
    local sets = C_EquipmentSet
    if not (sets and sets.GetEquipmentSetIDs and sets.GetItemIDs) then return map end
    for _, setID in ipairs(sets.GetEquipmentSetIDs() or {}) do
        local name = sets.GetEquipmentSetInfo and sets.GetEquipmentSetInfo(setID) or "a set"
        for _, itemID in pairs(sets.GetItemIDs(setID) or {}) do
            if type(itemID) == "number" and itemID > 0 then map[itemID] = name end
        end
    end
    return map
end

function addon.ResetEquipmentSetCache()
    setItems = nil
end

local function EquipmentSetName(itemID)
    setItems = setItems or BuildSetItems()
    return setItems[itemID]
end

-- ==========================================
-- HOOKS FOR CORE
-- ==========================================

-- Gear slots that count towards the average: everything but shirt (4) and tabard (19).
local AVERAGE_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

--- Average item level of the gear actually worn, or nil when nothing is equipped.
-- The game's own equipped average counts empty slots as 0, which on a levelling
-- character drags the limit low enough to protect nearly every drop.
local function EquippedAverageIlvl()
    if not (GetInventoryItemLink and GetDetailedItemLevelInfo) then return nil end
    local total, count = 0, 0
    for _, slotID in ipairs(AVERAGE_SLOTS) do
        local link = GetInventoryItemLink("player", slotID)
        local ilvl = link and GetDetailedItemLevelInfo(link)
        if ilvl and ilvl > 0 then
            total, count = total + ilvl, count + 1
        end
    end
    if count == 0 then return nil end
    return math.floor(total / count)
end

--- Item level hard-stop limit for an item. nil disables the stop for that item.
function addon.GetIlvlLimit(db, itemID, info)
    if info and IsUnusableJunk(db, info) then
        return nil -- it can never be an upgrade for this character
    end
    if db.autoIlvlLimit then
        return EquippedAverageIlvl() or db.highIlvlThreshold
    end
    return db.highIlvlThreshold
end

local function IsGear(info)
    return info.equipLoc and info.equipLoc ~= ""
        and (info.classID == CLASS_ARMOR or info.classID == CLASS_WEAPON)
end

--- Forever-only verdict that runs before the regular filters.
function addon.ForeverItemRule(db, info)
    if db.protectEquipmentSets then
        local setName = EquipmentSetName(info.itemID)
        if setName then return false, "in your equipment set \"" .. setName .. "\"" end
    end

    if IsUnusableJunk(db, info) then
        return true
    end

    if db.onlyOutgrownGear and IsGear(info) then
        local gap = db.outgrownLevels or 10
        local required = math.max(info.reqLevel or 0, 1)
        if required > (UnitLevel("player") or 1) - gap then
            return false, ("not %d+ levels below you yet"):format(gap)
        end
    end

    return nil
end

--- Extra "never sold" lines for the protection summary.
function addon.ForeverProtectionLines(db, kept)
    if db.protectEquipmentSets then
        kept[#kept + 1] = "gear saved in an equipment set"
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
events:SetScript("OnEvent", function()
    addon.ResetEquipmentSetCache()
    if addon.InvalidateSellableCache then addon.InvalidateSellableCache() end
end)
