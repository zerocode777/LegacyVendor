-- ForeverRules.lua and ForeverBagAlert.lua against stubbed game APIs.
local T = _G.__LV_TEST
local makeArgs = dofile("tests/wow_stub.lua")

-- ---- game API stubs (only what the two modules touch) ----
local stub = { class = "MAGE", level = 30, bound = true, avgIlvl = 42, tooltip = {} }
_G.UnitClass = function() return "Mage", stub.class end
_G.UnitLevel = function() return stub.level end
-- Two worn items (40 and 45) and every other slot empty: average of worn gear is 42.
_G.GetInventoryItemLink = function(_, slotID)
    if stub.avgIlvl == 0 then return nil end
    return ({ [1] = "head", [5] = "chest" })[slotID]
end
_G.GetDetailedItemLevelInfo = function(link) return ({ head = 40, chest = 45 })[link] end
_G.ItemLocation = { CreateFromBagAndSlot = function()
    return { IsValid = function() return true end }
end }
_G.C_Item = { IsBound = function() return stub.bound end }
_G.ITEM_CLASSES_ALLOWED = "Classes: %s"
_G.LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", WARRIOR = "Warrior" }
_G.LOCALIZED_CLASS_NAMES_FEMALE = { MAGE = "Mage", WARRIOR = "Warrior" }
_G.C_TooltipInfo = { GetBagItem = function() return { lines = stub.tooltip } end }
_G.C_EquipmentSet = {
    GetEquipmentSetIDs = function() return { 1 } end,
    GetEquipmentSetInfo = function() return "Tank" end,
    GetItemIDs = function() return { [1] = 5001, [2] = -1 } end,
}

local addon = { isForever = true }
assert(loadfile("ForeverRules.lua"))(makeArgs(addon))
assert(loadfile("ForeverBagAlert.lua"))(makeArgs(addon))

local function item(fields)
    local info = { itemID = 100, equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 1,
                   reqLevel = 25, bag = 0, slot = 1 }
    for k, v in pairs(fields or {}) do info[k] = v end
    return info
end

local function db(fields)
    local d = { sellUnusableGear = true, protectEquipmentSets = true, onlyOutgrownGear = false,
                outgrownLevels = 10, autoIlvlLimit = true, highIlvlThreshold = 285 }
    for k, v in pairs(fields or {}) do d[k] = v end
    return d
end

T.test("rules: plate is never usable by a mage, cloth is", function()
    stub.class, stub.tooltip = "MAGE", {}
    T.eq(addon.IsNeverUsableByClass(item({ subClassID = 4 })), true)
    T.eq(addon.IsNeverUsableByClass(item({ subClassID = 1 })), false)
    T.eq(addon.IsNeverUsableByClass(item({ subClassID = 4, equipLoc = "INVTYPE_CLOAK" })), false)
end)

T.test("rules: warrior can wear anything, but no wands", function()
    stub.class = "WARRIOR"
    T.eq(addon.IsNeverUsableByClass(item({ subClassID = 4 })), false)
    T.eq(addon.IsNeverUsableByClass(item({ classID = 2, subClassID = 19, equipLoc = "INVTYPE_RANGEDRIGHT" })), true)
    stub.class = "MAGE"
end)

T.test("rules: unknown class never counts as unusable", function()
    stub.class = "EVOKER"
    T.eq(addon.IsNeverUsableByClass(item({ subClassID = 4 })), false)
    stub.class = "MAGE"
end)

T.test("rules: class-restricted tooltip line", function()
    stub.tooltip = { { leftText = "Classes: Warrior" } }
    T.eq(addon.IsNeverUsableByClass(item({ equipLoc = "INVTYPE_FINGER", subClassID = 0 })), true)
    stub.tooltip = { { leftText = "Classes: Mage, Warlock" } }
    T.eq(addon.IsNeverUsableByClass(item({ equipLoc = "INVTYPE_FINGER", subClassID = 0 })), false)
    stub.tooltip = {}
end)

T.test("rules: soulbound unusable gear sells; unbound does not", function()
    stub.bound = true
    T.eq(addon.ForeverItemRule(db(), item({ subClassID = 4 })), true)
    stub.bound = false
    T.eq(addon.ForeverItemRule(db(), item({ subClassID = 4 })), nil)
    stub.bound = true
end)

T.test("rules: equipment set beats the unusable rule", function()
    local verdict, reason = addon.ForeverItemRule(db(), item({ itemID = 5001, subClassID = 4 }))
    T.eq(verdict, false)
    T.eq(reason:find("Tank", 1, true) ~= nil, true, reason)
end)

T.test("rules: out-levelled gear gate", function()
    stub.level = 30
    local d = db({ onlyOutgrownGear = true })
    T.eq(addon.ForeverItemRule(d, item({ reqLevel = 25 })), false)
    T.eq(addon.ForeverItemRule(d, item({ reqLevel = 20 })), nil)
    T.eq(addon.ForeverItemRule(d, item({ reqLevel = 0 })), nil, "no requirement counts as level 1")
    T.eq(addon.ForeverItemRule(d, item({ classID = 0, equipLoc = "" })), nil, "consumables ignored")
end)

T.test("rules: item level limit follows equipped average", function()
    T.eq(addon.GetIlvlLimit(db(), 1, item()), 42)
    T.eq(addon.GetIlvlLimit(db({ autoIlvlLimit = false }), 1, item()), 285)
    T.eq(addon.GetIlvlLimit(db(), 1, item({ subClassID = 4 })), nil, "unusable gear has no limit")
    stub.avgIlvl = 0
    T.eq(addon.GetIlvlLimit(db(), 1, item()), 285, "falls back when nothing is worn")
    stub.avgIlvl = 42
end)

T.test("bag alert: warns once per crossing and re-arms", function()
    local E = addon.BagAlert.Evaluate
    local warn, armed = E(10, 4, true)
    T.eq(warn, false); T.eq(armed, true)
    warn, armed = E(4, 4, armed)
    T.eq(warn, true); T.eq(armed, false)
    warn, armed = E(2, 4, armed)
    T.eq(warn, false, "no repeat while still full")
    warn, armed = E(6, 4, armed)
    T.eq(armed, true)
end)

T.test("bag alert: lists the cheapest three", function()
    local msg = addon.BagAlert.BuildMessage(3, {
        { link = "[D]", price = 400 }, { link = "[A]", price = 1 },
        { link = "[C]", price = 300 }, { link = "[B]", price = 20 },
    })
    T.eq(msg:find("[A], [B], [C]", 1, true) ~= nil, true, msg)
    T.eq(addon.BagAlert.BuildMessage(1, {}):find("Nothing matches", 1, true) ~= nil, true)
end)
