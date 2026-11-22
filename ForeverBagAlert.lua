-- Loaded only by LegacyVendor_Forever.toc. Warns once when bags are nearly full
-- and names the cheapest items the addon would sell, so making room costs the
-- least gold. Re-arms only after free space climbs back above the threshold.
local _, addon = ...

if not addon.isForever then return end

local BagAlert = {}
addon.BagAlert = BagAlert

local armed = true
local pending = false

--- Pure decision: should a warning fire now, and is the alert armed afterwards?
function BagAlert.Evaluate(freeSlots, threshold, isArmed)
    if freeSlots > threshold then return false, true end
    return isArmed, false
end

--- Builds the chat line from the sellable list (cheapest first, at most three).
function BagAlert.BuildMessage(freeSlots, items)
    local head = ("Bags almost full - %d free slot%s."):format(freeSlots, freeSlots == 1 and "" or "s")
    if not items or #items == 0 then
        return head .. " Nothing matches your sell filters."
    end
    local sorted = {}
    for i, item in ipairs(items) do sorted[i] = item end
    table.sort(sorted, function(a, b) return (a.price or 0) < (b.price or 0) end)
    local links = {}
    for i = 1, math.min(3, #sorted) do links[i] = sorted[i].link or "?" end
    return ("%s Cheapest to sell: %s"):format(head, table.concat(links, ", "))
end

-- General-purpose bag slots only: profession and reagent bags cannot take most items.
local function CountFreeSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots, family = C_Container.GetContainerNumFreeSlots(bag)
        if (family or 0) == 0 then free = free + (slots or 0) end
    end
    return free
end

local function Check()
    pending = false
    local db = LegacyVendorDB
    if not (db and db.enabled and db.bagFullWarning) then return end
    if MerchantFrame and MerchantFrame:IsShown() then return end -- the Sell button covers it

    local free = CountFreeSlots()
    local warn
    warn, armed = BagAlert.Evaluate(free, db.bagFullSlots or 4, armed)
    if not warn then return end

    local _, _, items = addon.CountSellable()
    addon.Print(BagAlert.BuildMessage(free, items))
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function()
    -- Bag events come in bursts while looting; one check per burst is plenty.
    if pending then return end
    pending = true
    C_Timer.After(0.5, Check)
end)
