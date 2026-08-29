-- LegacyVendor - Visual metadata for filter categories
-- Maps each filter option to an icon or colour so the settings panel can be scanned
-- visually instead of read line by line. Uses Blizzard's own art throughout - the
-- paperdoll slot textures and standard item icons - so there is nothing to ship.

local addonName, addon = ...

local ICONS = "Interface\\ICONS\\"
local PAPERDOLL = "Interface\\Paperdoll\\UI-PaperDoll-Slot-"

addon.Visuals = {}

-- Equipment slots reuse the character sheet's own empty-slot art, which is exactly
-- the glyph a player already associates with that slot.
addon.Visuals.EquipSlotIcon = {
    ["INVTYPE_HEAD"]           = PAPERDOLL .. "Head",
    ["INVTYPE_NECK"]           = PAPERDOLL .. "Neck",
    ["INVTYPE_SHOULDER"]       = PAPERDOLL .. "Shoulder",
    ["INVTYPE_BODY"]           = PAPERDOLL .. "Shirt",
    ["INVTYPE_CHEST"]          = PAPERDOLL .. "Chest",
    ["INVTYPE_WAIST"]          = PAPERDOLL .. "Waist",
    ["INVTYPE_LEGS"]           = PAPERDOLL .. "Legs",
    ["INVTYPE_FEET"]           = PAPERDOLL .. "Feet",
    ["INVTYPE_WRIST"]          = PAPERDOLL .. "Wrists",
    ["INVTYPE_HAND"]           = PAPERDOLL .. "Hands",
    ["INVTYPE_FINGER"]         = PAPERDOLL .. "Finger",
    ["INVTYPE_TRINKET"]        = PAPERDOLL .. "Trinket",
    ["INVTYPE_CLOAK"]          = PAPERDOLL .. "Chest",
    ["INVTYPE_WEAPON"]         = PAPERDOLL .. "MainHand",
    ["INVTYPE_SHIELD"]         = PAPERDOLL .. "SecondaryHand",
    ["INVTYPE_2HWEAPON"]       = PAPERDOLL .. "MainHand",
    ["INVTYPE_WEAPONMAINHAND"] = PAPERDOLL .. "MainHand",
    ["INVTYPE_WEAPONOFFHAND"]  = PAPERDOLL .. "SecondaryHand",
    ["INVTYPE_HOLDABLE"]       = PAPERDOLL .. "SecondaryHand",
    ["INVTYPE_RANGED"]         = PAPERDOLL .. "Ranged",
    ["INVTYPE_RANGEDRIGHT"]    = PAPERDOLL .. "Ranged",
    ["INVTYPE_TABARD"]         = PAPERDOLL .. "Tabard",
}

addon.Visuals.ItemTypeIcon = {
    [0]  = ICONS .. "INV_Potion_54",
    [1]  = ICONS .. "INV_Misc_Bag_08",
    [3]  = ICONS .. "INV_Misc_Gem_Variety_01",
    [5]  = ICONS .. "INV_Misc_Dust_01",
    [7]  = ICONS .. "Trade_BlackSmithing",
    [9]  = ICONS .. "INV_Scroll_03",
    [12] = ICONS .. "INV_Misc_Note_01",
    [13] = ICONS .. "INV_Misc_Key_03",
    [15] = ICONS .. "INV_Misc_QuestionMark",
}

addon.Visuals.SourceIcon = {
    consumable = ICONS .. "INV_Potion_54",
    dungeon    = ICONS .. "INV_Misc_Head_Dragon_01",
    raid       = ICONS .. "INV_Misc_Head_Dragon_Black",
    outdoor    = ICONS .. "INV_Misc_Map02",
    profession = ICONS .. "Trade_BlackSmithing",
    vendor     = ICONS .. "INV_Misc_Coin_01",
    pvp        = ICONS .. "INV_BannerPVP_02",
    reputation = ICONS .. "Achievement_Reputation_01",
    housing    = ICONS .. "INV_Misc_Bag_28",
    unknown    = ICONS .. "INV_Misc_QuestionMark",
}

addon.Visuals.BindIcon = {
    bop     = ICONS .. "INV_Misc_Bandage_Netherweave_Heavy",
    boe     = ICONS .. "INV_Misc_Note_02",
    unbound = ICONS .. "INV_Misc_Food_15",
}

-- Short labels keep chips compact; the full name still shows in the tooltip.
addon.Visuals.ShortLabel = {
    -- Bind types
    bop = "Soulbound", boe = "Bind on Equip", unbound = "Not Bound",
    -- Sources
    consumable = "Consumables", dungeon = "Dungeons", raid = "Raids",
    outdoor = "World", profession = "Professions", vendor = "Vendor",
    pvp = "PvP", reputation = "Reputation", housing = "Housing/Delves",
    unknown = "Other",
}

addon.Visuals.ItemTypeShort = {
    [0] = "Consumables", [1] = "Bags", [3] = "Gems", [5] = "Reagents",
    [7] = "Trade Goods", [9] = "Recipes", [12] = "Quest Items",
    [13] = "Keys", [15] = "Misc",
}

addon.Visuals.RarityShort = {
    [0] = "Poor", [1] = "Common", [2] = "Uncommon",
    [3] = "Rare", [4] = "Epic", [5] = "Legendary",
}

-- "a335ee" -> {0.64, 0.21, 0.93}
function addon.Visuals.HexToRGB(hex)
    if type(hex) ~= "string" or #hex < 6 then
        return { 1, 1, 1 }
    end
    return {
        tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
    }
end
