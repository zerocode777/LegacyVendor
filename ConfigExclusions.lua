-- LegacyVendor - Exclusion list manager
-- The "never sell this specific item" list existed only as a chat command, so a
-- player could add items but never see, review or remove them. This is the visible
-- half: a scrollable list of what is excluded, with a remove button per row and a
-- drag-or-shift-click target for adding more.

local addonName, addon = ...

local Exclusions = {}
addon.Exclusions = Exclusions

local ROW_HEIGHT = 26
local MAX_ROWS = 10

local function ExcludedIDs()
    local ids = {}
    for itemID, on in pairs(LegacyVendorDB.excludedItems or {}) do
        if on then ids[#ids + 1] = itemID end
    end
    table.sort(ids)
    return ids
end

-- Item names arrive asynchronously the first time an item is seen this session, so
-- rows render a placeholder and refresh once the client has the data.
local function ItemDisplay(itemID)
    local name, link, quality, _, _, _, _, _, _, icon
    if C_Item and C_Item.GetItemInfo then
        name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    else
        name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    end
    return name, link, quality, icon
end

function Exclusions.Open()
    if Exclusions.frame then
        Exclusions.frame:Show()
        Exclusions.Refresh()
        return
    end

    local f = CreateFrame("Frame", "LegacyVendorExclusions", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(420, 400)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg or f, "TOP", 0, -4)
    f.title:SetText("Never Sell These Items")

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.hint:SetPoint("TOPLEFT", 14, -32)
    f.hint:SetPoint("TOPRIGHT", -14, -32)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWordWrap(true)
    f.hint:SetTextColor(0.65, 0.65, 0.68)
    f.hint:SetText("These are never sold, whatever your filters say. "
        .. "Drop an item onto the box below to add it, or hover one in your bags and type /lv exclude.")

    -- Drop target: dragging an item here is the discoverable way to add one.
    local drop = CreateFrame("Button", nil, f)
    drop:SetPoint("TOPLEFT", 14, -74)
    drop:SetPoint("TOPRIGHT", -14, -74)
    drop:SetHeight(38)
    addon.Widgets.ApplyCard(drop, { 0.10, 0.12, 0.10, 0.9 }, { 0.35, 0.5, 0.35, 1 })

    drop.Text = drop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    drop.Text:SetPoint("CENTER")
    drop.Text:SetText("|cFF88CC88Drop an item here to protect it|r")

    local function AddCursorItem()
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType ~= "item" then return end
        local id = itemID or (itemLink and tonumber(itemLink:match("item:(%d+)")))
        if not id then return end
        LegacyVendorDB.excludedItems[id] = true
        ClearCursor()
        Exclusions.Refresh()
        if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
            addon.UpdateMerchantButton()
        end
        if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
    end

    drop:SetScript("OnReceiveDrag", AddCursorItem)
    drop:SetScript("OnClick", AddCursorItem)
    f.drop = drop

    -- Scrollable row list
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -120)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)

    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(360, ROW_HEIGHT * MAX_ROWS)
    scroll:SetScrollChild(list)
    f.list = list

    f.empty = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.empty:SetPoint("TOPLEFT", 6, -8)
    f.empty:SetTextColor(0.55, 0.55, 0.58)
    f.empty:SetText("Nothing is protected yet.")

    local clearAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearAll:SetSize(120, 24)
    clearAll:SetPoint("BOTTOMLEFT", 14, 12)
    clearAll:SetText("Remove all")
    clearAll:SetScript("OnClick", function()
        StaticPopupDialogs["LEGACYVENDOR_CLEAR_EXCLUSIONS"] = {
            text = "Stop protecting every item on this list?",
            button1 = YES or "Yes", button2 = NO or "No",
            OnAccept = function()
                wipe(LegacyVendorDB.excludedItems)
                Exclusions.Refresh()
            end,
            timeout = 0, whileDead = false, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("LEGACYVENDOR_CLEAR_EXCLUSIONS")
    end)

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.count:SetPoint("BOTTOMRIGHT", -16, 18)

    f.rows = {}
    Exclusions.frame = f
    Exclusions.Refresh()
    f:Show()
end

local function AcquireRow(index)
    local f = Exclusions.frame
    local row = f.rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, f.list)
    row:SetHeight(ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", f.list, "TOPLEFT", 2, -((index - 1) * ROW_HEIGHT) - 2)
    row:SetPoint("TOPRIGHT", f.list, "TOPRIGHT", -2, -((index - 1) * ROW_HEIGHT) - 2)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(20, 20)
    row.Icon:SetPoint("LEFT", 4, 0)
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.Text:SetPoint("LEFT", 30, 0)
    row.Text:SetPoint("RIGHT", -30, 0)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)

    row.Remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.Remove:SetSize(22, 22)
    row.Remove:SetPoint("RIGHT", 2, 0)

    f.rows[index] = row
    return row
end

function Exclusions.Refresh()
    local f = Exclusions.frame
    if not f then return end

    local ids = ExcludedIDs()
    f.empty:SetShown(#ids == 0)
    f.count:SetText(("|cFF888888%d protected|r"):format(#ids))
    f.list:SetHeight(math.max(ROW_HEIGHT * MAX_ROWS, ROW_HEIGHT * #ids))

    for i, row in ipairs(f.rows) do
        if i > #ids then row:Hide() end
    end

    local pendingName = false
    for i, itemID in ipairs(ids) do
        local row = AcquireRow(i)
        local name, link, quality, icon = ItemDisplay(itemID)

        row.Icon:SetTexture(icon or "Interface\\ICONS\\INV_Misc_QuestionMark")

        if name then
            local hex = (quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality])
                and ITEM_QUALITY_COLORS[quality].hex or "|cFFFFFFFF"
            row.Text:SetText(hex .. name .. "|r")
        else
            -- Not cached yet; ask the client for it and refresh when it lands.
            row.Text:SetText("|cFF888888Loading item " .. itemID .. "...|r")
            pendingName = true
        end

        row.Remove:SetScript("OnClick", function()
            LegacyVendorDB.excludedItems[itemID] = nil
            Exclusions.Refresh()
            if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
                addon.UpdateMerchantButton()
            end
            if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
        end)

        row:SetScript("OnEnter", function(self)
            if link and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        row:Show()
    end

    if pendingName then
        C_Timer.After(0.5, function()
            if Exclusions.frame and Exclusions.frame:IsShown() then
                Exclusions.Refresh()
            end
        end)
    end
end
