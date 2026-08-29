-- LegacyVendor - Guided setup flow
-- The filter panel answers "what is every option?", which is the wrong first
-- question. This asks three plain questions in order, each narrowing the last, with
-- the real bag count updating underneath so the effect of a choice is visible while
-- making it. The full panel stays available for people who want every switch.

local addonName, addon = ...

local Wizard = {}
addon.Wizard = Wizard

local FRAME_W, FRAME_H = 520, 520
local STEP_COUNT = 4

-- Snapshot/restore so Cancel genuinely undoes everything the flow touched.
local function Snapshot(db)
    local function copy(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do out[k] = (type(v) == "table") and copy(v) or v end
        return out
    end
    return {
        expansions = copy(db.expansions), rarities = copy(db.rarities),
        equipSlots = copy(db.equipSlots), itemTypes = copy(db.itemTypes),
        itemSources = copy(db.itemSources), sellMode = db.sellMode,
        sellBoP = db.sellBoP, sellBoE = db.sellBoE, sellUnbound = db.sellUnbound,
        protectUncollected = db.protectUncollected,
    }
end

local function Restore(db, snap)
    for k, v in pairs(snap) do db[k] = v end
end

-- ==========================================
-- STEP CONTENT
-- ==========================================
-- Each "big choice" writes a complete, coherent slice of config, so a user never
-- has to know that "gear only" means 22 slot toggles plus 9 type toggles.

local SCOPE_CHOICES = {
    {
        name = "Gear only",
        desc = "Armour and weapons. Leaves consumables, mats and everything else alone.",
        icon = "Interface\\ICONS\\INV_Chest_Chain_05",
        apply = function(db)
            db.sellMode = "matching"
            for k in pairs(addon.EQUIP_SLOTS) do db.equipSlots[k] = true end
            for id in pairs(addon.ITEM_TYPES) do db.itemTypes[id] = false end
            db.itemSources = { consumable = true, profession = true }
        end,
    },
    {
        name = "Gear + old consumables",
        desc = "Also clears out stale food, potions and flasks from old expansions.",
        icon = "Interface\\ICONS\\INV_Potion_54",
        apply = function(db)
            db.sellMode = "matching"
            for k in pairs(addon.EQUIP_SLOTS) do db.equipSlots[k] = true end
            for id in pairs(addon.ITEM_TYPES) do db.itemTypes[id] = false end
            db.itemTypes[0] = true
            db.itemSources = { profession = true }
        end,
    },
    {
        name = "Everything from those expansions",
        desc = "Sells all legacy items from the expansions you picked. Fastest, least selective.",
        icon = "Interface\\ICONS\\INV_Misc_Coin_01",
        apply = function(db)
            db.sellMode = "everything"
        end,
    },
}

local CARE_CHOICES = {
    {
        name = "Very careful",
        desc = "Only grey and green soulbound items. Skips anything blue or better.",
        icon = "Interface\\ICONS\\INV_Shield_06",
        apply = function(db)
            db.rarities = { [0] = true, [1] = true, [2] = true, [3] = false, [4] = false, [5] = false }
            db.sellBoP, db.sellBoE, db.sellUnbound = true, false, false
        end,
    },
    {
        name = "Balanced",
        desc = "Up to blue quality, soulbound only. A sensible default for most cleanups.",
        icon = "Interface\\ICONS\\INV_Misc_Gem_Variety_01",
        apply = function(db)
            db.rarities = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = false, [5] = false }
            db.sellBoP, db.sellBoE, db.sellUnbound = true, false, false
        end,
    },
    {
        name = "Aggressive",
        desc = "Up to epic, including bound BoE gear. Clears the most, keeps the least.",
        icon = "Interface\\ICONS\\INV_Misc_Head_Dragon_Black",
        apply = function(db)
            db.rarities = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = false }
            db.sellBoP, db.sellBoE, db.sellUnbound = true, true, false
        end,
    },
}

-- A large, clickable choice card. Deliberately big: one of these replaces dozens of
-- individual toggles, so it should read as a decision, not a checkbox.
local function CreateChoiceCard(parent, choice, isSelected, onClick)
    local W = addon.Widgets
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(52)

    card.Icon = card:CreateTexture(nil, "ARTWORK")
    card.Icon:SetSize(34, 34)
    card.Icon:SetPoint("LEFT", 10, 0)
    card.Icon:SetTexture(choice.icon)
    card.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.Title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.Title:SetPoint("TOPLEFT", 54, -9)
    card.Title:SetText(choice.name)

    card.Desc = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.Desc:SetPoint("TOPLEFT", 54, -26)
    card.Desc:SetPoint("RIGHT", -10, 0)
    card.Desc:SetJustifyH("LEFT")
    card.Desc:SetText(choice.desc)
    card.Desc:SetTextColor(0.65, 0.65, 0.68)

    function card:SetSelected(on)
        if on then
            W.ApplyCard(self, { 0.30, 0.24, 0.08, 0.95 }, { 0.95, 0.78, 0.35, 1 })
            self.Title:SetTextColor(1, 0.93, 0.72)
            self.Icon:SetAlpha(1)
        else
            W.ApplyCard(self, { 0.11, 0.11, 0.13, 0.9 }, { 0.28, 0.28, 0.32, 1 })
            self.Title:SetTextColor(0.8, 0.8, 0.8)
            self.Icon:SetAlpha(0.55)
        end
    end

    card:SetScript("OnClick", onClick)
    card:SetSelected(isSelected)
    return card
end

-- ==========================================
-- FRAME
-- ==========================================

function Wizard.Open()
    if Wizard.frame then
        Wizard.frame:Show()
        Wizard.Goto(1)
        return
    end

    local f = CreateFrame("Frame", "LegacyVendorWizard", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg or f, "TOP", 0, -4)
    f.title:SetText("Legacy Vendor - Quick Setup")

    -- Step breadcrumb
    f.StepText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.StepText:SetPoint("TOPLEFT", 18, -34)

    f.Question = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.Question:SetPoint("TOPLEFT", 18, -52)
    f.Question:SetPoint("TOPRIGHT", -18, -52)
    f.Question:SetJustifyH("LEFT")

    f.Hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.Hint:SetPoint("TOPLEFT", 18, -76)
    f.Hint:SetPoint("TOPRIGHT", -18, -76)
    f.Hint:SetJustifyH("LEFT")
    f.Hint:SetTextColor(0.6, 0.6, 0.63)

    f.Body = CreateFrame("Frame", nil, f)
    f.Body:SetPoint("TOPLEFT", 14, -100)
    f.Body:SetPoint("BOTTOMRIGHT", -14, 74)

    -- Running count: the whole point of the flow is seeing this move as you choose.
    f.Live = addon.Widgets.CreateSummaryBar(f)
    f.Live:SetPoint("BOTTOMLEFT", 14, 40)
    f.Live:SetPoint("BOTTOMRIGHT", -14, 40)

    f.Back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.Back:SetSize(90, 24)
    f.Back:SetPoint("BOTTOMLEFT", 16, 12)
    f.Back:SetText("Back")
    f.Back:SetScript("OnClick", function() Wizard.Goto(Wizard.step - 1) end)

    f.Next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.Next:SetSize(110, 24)
    f.Next:SetPoint("BOTTOMRIGHT", -16, 12)
    f.Next:SetScript("OnClick", function()
        if Wizard.step >= STEP_COUNT then
            Wizard.Finish()
        else
            Wizard.Goto(Wizard.step + 1)
        end
    end)

    f.Cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.Cancel:SetSize(90, 24)
    f.Cancel:SetPoint("BOTTOM", 0, 12)
    f.Cancel:SetText("Cancel")
    f.Cancel:SetScript("OnClick", function() Wizard.Cancel() end)

    Wizard.frame = f
    Wizard.snapshot = Snapshot(LegacyVendorDB)
    Wizard.Goto(1)
    f:Show()
end

function Wizard.Cancel()
    if Wizard.snapshot then
        Restore(LegacyVendorDB, Wizard.snapshot)
    end
    if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
    if Wizard.frame then Wizard.frame:Hide() end
end

function Wizard.Finish()
    if Wizard.frame then Wizard.frame:Hide() end
    if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
        addon.UpdateMerchantButton()
    end
    if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
    addon.Print("Setup complete. " .. (addon.BuildFilterSentence and addon.BuildFilterSentence(LegacyVendorDB) or ""))
end

-- Clears the body between steps.
local function ClearBody(body)
    if body._kids then
        for _, k in ipairs(body._kids) do k:Hide(); k:SetParent(nil) end
    end
    body._kids = {}
end

local function Track(body, obj)
    body._kids[#body._kids + 1] = obj
    return obj
end

function Wizard.RefreshLive()
    local f = Wizard.frame
    if not f then return end
    f.Live:SetSentence(addon.BuildFilterSentence(LegacyVendorDB))
    if addon.CountSellable then
        local count, gold = addon.CountSellable()
        if count == 0 then
            f.Live:SetCount("Nothing in your bags matches yet.", true)
        else
            local g = math.floor((gold or 0) / 10000)
            f.Live:SetCount(("%d item%s would sell  (about %dg)"):format(count, count == 1 and "" or "s", g), false)
        end
    end
end

function Wizard.Goto(step)
    step = math.max(1, math.min(STEP_COUNT, step))
    Wizard.step = step

    local f = Wizard.frame
    local body = f.Body
    ClearBody(body)

    f.StepText:SetText(("|cFF888888Step %d of %d|r"):format(step, STEP_COUNT))
    f.Back:SetEnabled(step > 1)
    f.Next:SetText(step >= STEP_COUNT and "Finish" or "Next")

    if step == 1 then
        f.Question:SetText("Which expansions do you want to clear out?")
        f.Hint:SetText("Everything else follows from this. Current content is always protected.")

        local row = Track(body, CreateFrame("Frame", nil, body))
        row:SetPoint("TOPLEFT"); row:SetPoint("TOPRIGHT"); row:SetHeight(24)

        local allBtn = Track(body, addon.Widgets.CreatePresetButton(row, "Select all", nil, function()
            for i = 0, (addon.MAX_EXPANSION or addon.CURRENT_EXPANSION) do
                if i ~= addon.CURRENT_EXPANSION then LegacyVendorDB.expansions[i] = true end
            end
            Wizard.Goto(1)
        end))
        allBtn:SetPoint("LEFT", row, "LEFT", 2, 0)

        local noneBtn = Track(body, addon.Widgets.CreatePresetButton(row, "Clear all", nil, function()
            for i = 0, (addon.MAX_EXPANSION or addon.CURRENT_EXPANSION) do
                LegacyVendorDB.expansions[i] = false
            end
            Wizard.Goto(1)
        end))
        noneBtn:SetPoint("LEFT", allBtn, "RIGHT", 6, 0)

        local chips = {}
        for i = 0, (addon.MAX_EXPANSION or addon.CURRENT_EXPANSION) do
            local exp = addon.EXPANSIONS[i]
            if exp then
                local chip = Track(body, addon.Widgets.CreateChip(body, {
                    label = exp.short or exp.name,
                    icon = addon.Visuals.ExpansionIcon[i],
                    tooltip = "Sell items from " .. exp.name .. ".",
                }, function() return LegacyVendorDB.expansions[i] end,
                   function(v) LegacyVendorDB.expansions[i] = v; Wizard.RefreshLive() end))
                chips[#chips + 1] = chip
            end
        end
        addon.Widgets.LayoutChips(body, chips, -34, 2, FRAME_W - 60)

    elseif step == 2 then
        f.Question:SetText("What kinds of items should it sell?")
        f.Hint:SetText("Pick one. This sets the gear slots and item types for you.")

        local y = 0
        for idx, choice in ipairs(SCOPE_CHOICES) do
            local card
            card = Track(body, CreateChoiceCard(body, choice,
                LegacyVendorDB._wizScope == idx,
                function()
                    LegacyVendorDB._wizScope = idx
                    choice.apply(LegacyVendorDB)
                    Wizard.Goto(2)
                end))
            card:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
            card:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, y)
            y = y - 58
        end

    elseif step == 3 then
        f.Question:SetText("How careful should it be?")
        f.Hint:SetText("Controls quality and bind type. You can fine-tune later in Settings.")

        local y = 0
        for idx, choice in ipairs(CARE_CHOICES) do
            local card
            card = Track(body, CreateChoiceCard(body, choice,
                LegacyVendorDB._wizCare == idx,
                function()
                    LegacyVendorDB._wizCare = idx
                    choice.apply(LegacyVendorDB)
                    Wizard.Goto(3)
                end))
            card:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
            card:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, y)
            y = y - 58
        end

        local protect = Track(body, CreateFrame("CheckButton", nil, body, "InterfaceOptionsCheckButtonTemplate"))
        protect:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y - 6)
        protect.Text:SetText("Never sell uncollected appearances, mounts, toys or pets")
        protect:SetChecked(LegacyVendorDB.protectUncollected ~= false)
        protect:SetScript("OnClick", function(self)
            LegacyVendorDB.protectUncollected = self:GetChecked()
            Wizard.RefreshLive()
        end)

    else
        f.Question:SetText("Here's what that means")
        f.Hint:SetText("Nothing has been sold. Finish to keep these settings.")

        local list = Track(body, body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
        list:SetPoint("TOPLEFT", 2, 0)
        list:SetPoint("TOPRIGHT", -2, 0)
        list:SetJustifyH("LEFT")
        list:SetJustifyV("TOP")
        list:SetHeight(240)

        local items = {}
        if addon.CountSellable then
            local _, _, list = addon.CountSellable()
            items = list or {}
        end

        local lines = {}
        if items and #items > 0 then
            lines[#lines + 1] = "|cFFFFD100Examples from your bags:|r"
            for i = 1, math.min(12, #items) do
                lines[#lines + 1] = "  " .. (items[i].link or "?")
            end
            if #items > 12 then
                lines[#lines + 1] = ("  |cFF888888...and %d more|r"):format(#items - 12)
            end
        else
            lines[#lines + 1] = "|cFFFFCC00Nothing in your bags matches these settings right now.|r"
            lines[#lines + 1] = "That is fine - it just means this character has no old"
            lines[#lines + 1] = "clutter from the expansions you picked."
        end
        list:SetText(table.concat(lines, "\n"))
    end

    Wizard.RefreshLive()
end
