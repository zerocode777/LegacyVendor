-- LegacyVendor Configuration UI
-- Compatible with all WoW versions: Retail, Cataclysm Classic, Classic Era

local addonName, addon = ...

-- Helper function to refresh button when settings change
local function RefreshButton()
    if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
        addon.UpdateMerchantButton()
    end
end

-- Create options panel using the Settings API (modern WoW only)
-- Reduced to a thin launcher: Enable toggle + button to open the custom config frame.
local function CreateOptionsPanel()
    -- Skip if Settings API not available (Classic)
    if not Settings or not Settings.RegisterVerticalLayoutCategory then
        return
    end

    -- Main category
    local category, layout = Settings.RegisterVerticalLayoutCategory("LegacyVendor")

    -- Header
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General Settings"))

    -- Enable/Disable toggle
    do
        local variable = "LegacyVendor_Enabled"
        local name = "Enable LegacyVendor"
        local tooltip = "Enable or disable automatic selling of legacy items."

        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.enabled,
            function() return LegacyVendorDB.enabled end,
            function(value) LegacyVendorDB.enabled = value; RefreshButton() end)

        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Launch button: opens the full custom config frame
    if Settings.CreateButton then
        -- Preferred: native Settings button element (available in recent Retail builds)
        local buttonInitializer = Settings.CreateButton(
            "Open Legacy Vendor Filters…",
            "Open the full LegacyVendor filter configuration.",
            function() addon.OpenConfig() end)
        layout:AddInitializer(buttonInitializer)
    else
        -- Fallback: proxy boolean setting whose setter fires OpenConfig then resets itself
        local variable = "LegacyVendor_OpenConfigLauncher"
        local name = "Open Legacy Vendor Filters…"
        local tooltip = "Click to open the full LegacyVendor filter configuration frame."
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, false,
            function() return false end,
            function(_value) addon.OpenConfig() end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Register the category
    Settings.RegisterAddOnCategory(category)

    addon.settingsCategory = category
end

-- Alternative simple frame-based config for compatibility
local function CreateSimpleConfig()
    local configFrame = CreateFrame("Frame", "LegacyVendorConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(660, 700)
    -- Restore wherever the user last dragged the window. Toggling a filter rebuilds
    -- this frame, and snapping back to centre every time made that unusable.
    do
        local pos = addon._configFramePos
        if pos and pos.point then
            configFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        else
            configFrame:SetPoint("CENTER")
        end
    end
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        addon._configFramePos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    configFrame:Hide()

    configFrame.TitleBg:SetHeight(30)
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.title:SetPoint("TOP", configFrame.TitleBg, "TOP", 0, -3)
    configFrame.title:SetText("LegacyVendor Settings")

    local insetFrame = configFrame.Inset or configFrame
    local insetOffsetT = configFrame.Inset and -5 or -32
    local insetOffsetB = configFrame.Inset and 5 or 8

    -- Live "what will actually sell" bar: one plain-English sentence that narrows as
    -- filters are clicked, plus a real count from the player's current bags. This is
    -- the panel's answer to "what do these settings actually do?".
    local topSummaryFrame = addon.Widgets.CreateSummaryBar(configFrame)
    topSummaryFrame:SetPoint("TOPLEFT", insetFrame, "TOPLEFT", 8, insetOffsetT - 1)
    topSummaryFrame:SetPoint("TOPRIGHT", insetFrame, "TOPRIGHT", -8, insetOffsetT - 1)

    -- Search bar
    local searchFrame = CreateFrame("Frame", nil, configFrame)
    searchFrame:SetPoint("TOPLEFT", topSummaryFrame, "BOTTOMLEFT", 0, -3)
    searchFrame:SetPoint("TOPRIGHT", topSummaryFrame, "BOTTOMRIGHT", 0, -3)
    searchFrame:SetHeight(22)
    local searchFrameBg = searchFrame:CreateTexture(nil, "BACKGROUND")
    searchFrameBg:SetAllPoints()
    searchFrameBg:SetColorTexture(0.06, 0.06, 0.06, 0.95)
    local searchLabel = searchFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchLabel:SetPoint("LEFT", searchFrame, "LEFT", 26, 0)
    searchLabel:SetText("|cFF888888Search options...|r")
    local searchIcon = searchFrame:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", searchFrame, "LEFT", 5, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    local searchBox = CreateFrame("EditBox", nil, searchFrame)
    searchBox:SetFontObject(ChatFontNormal)
    searchBox:SetPoint("LEFT", searchFrame, "LEFT", 24, 0)
    searchBox:SetPoint("RIGHT", searchFrame, "RIGHT", -8, 0)
    searchBox:SetHeight(18)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(64)

    -- Scroll frame (anchored below search bar)
    local scrollFrame = CreateFrame("ScrollFrame", nil, configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", searchFrame, "BOTTOMLEFT", -3, -3)
    scrollFrame:SetPoint("BOTTOMRIGHT", insetFrame, "BOTTOMRIGHT", -25, insetOffsetB + 26)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(610, 2600)
    scrollFrame:SetScrollChild(content)

    -- Active filter summary bar (bottom)
    -- Presets strip along the bottom: the fastest path from "installed" to
    -- "configured", which is the step most users never finish.
    local presetFrame = CreateFrame("Frame", nil, configFrame)
    presetFrame:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 3, -3)
    presetFrame:SetPoint("TOPRIGHT", scrollFrame, "BOTTOMRIGHT", 25, -3)
    presetFrame:SetHeight(30)

    local presetLabel = presetFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    presetLabel:SetPoint("LEFT", presetFrame, "LEFT", 4, 0)
    presetLabel:SetText("|cFF888888Start from:|r")

    -- Guided setup: the "I do not want to read forty options" path.
    local wizardBtn = CreateFrame("Button", nil, presetFrame, "UIPanelButtonTemplate")
    wizardBtn:SetSize(130, 24)
    wizardBtn:SetPoint("RIGHT", presetFrame, "RIGHT", -10, 0)
    wizardBtn:SetText("Guided setup")
    wizardBtn:SetScript("OnClick", function()
        if addon.Wizard then addon.Wizard.Open() end
    end)

    if addon.EnsureExpansionProfiles then
        addon.EnsureExpansionProfiles(LegacyVendorDB)
    end

    local maxExpansion = addon.MAX_EXPANSION or addon.CURRENT_EXPANSION
    if LegacyVendorDB.selectedExpansionProfileID == nil then
        LegacyVendorDB.selectedExpansionProfileID = 0
    end
    if LegacyVendorDB.selectedExpansionProfileID > maxExpansion then
        LegacyVendorDB.selectedExpansionProfileID = maxExpansion
    end

    local function GetSelectedExpansionID()
        return LegacyVendorDB.selectedExpansionProfileID or 0
    end

    local function GetSelectedProfile()
        local expID = GetSelectedExpansionID()
        if not LegacyVendorDB.expansionProfiles then
            LegacyVendorDB.expansionProfiles = {}
        end
        if not LegacyVendorDB.expansionProfiles[expID] then
            if addon.CreateDefaultExpansionProfile then
                LegacyVendorDB.expansionProfiles[expID] = addon.CreateDefaultExpansionProfile()
            else
                LegacyVendorDB.expansionProfiles[expID] = {
                    useDetailedFilters = false, filterBySource = false,
                    onlySellLowerIlvl = false,
                    bindTypes = { bop = true, boe = false, unbound = false },
                    rarities = {}, equipSlots = {}, itemTypes = {}, itemSources = {},
                }
            end
        end
        return LegacyVendorDB.expansionProfiles[expID]
    end

    local function RefreshConfigFrame()
        local wasShown = configFrame:IsShown()

        -- Capture where the window sits and how far it is scrolled, so a rebuild
        -- (any bulk All/None, or a branch in the step flow) resumes in place
        -- instead of jumping back to centre at the top.
        local point, _, relPoint, x, y = configFrame:GetPoint()
        if point then
            addon._configFramePos = { point = point, relPoint = relPoint, x = x, y = y }
        end
        addon._configScroll = scrollFrame and scrollFrame:GetVerticalScroll() or 0

        configFrame:Hide()
        addon.configFrame = nil
        CreateSimpleConfig()
        if wasShown and addon.configFrame then
            addon.configFrame:Show()
        end
    end

    -- Build the preset buttons now that RefreshConfigFrame exists. Applying a preset
    -- rewrites several filter groups at once, so the panel is rebuilt to redraw every
    -- chip's state rather than trying to refresh each one individually.
    do
        local anchor = presetLabel
        for _, preset in ipairs(addon.Sections.Presets) do
            local btn = addon.Widgets.CreatePresetButton(presetFrame, preset.name, preset.tooltip,
                function()
                    preset.apply(LegacyVendorDB)
                    if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
                    RefreshButton()
                    RefreshConfigFrame()
                    addon.Print(("Applied the \"%s\" preset."):format(preset.name))
                end)
            btn:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
            anchor = btn
        end
    end

    -- Let other modules (filter import, presets) rebuild this panel.
    addon.RefreshConfig = RefreshConfigFrame

    -- Display order for the per-expansion "Advanced" overrides further down. The main
    -- filter sections render as chips via addon.Sections and carry their own ordering.
    local rarityOrder = { 0, 1, 2, 3, 4, 5, 6, 7 }
    local slotOrder = {
        "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
        "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND",
        "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
        "INVTYPE_FINGER", "INVTYPE_TRINKET",
        "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
        "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_SHIELD",
        "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
        "INVTYPE_BODY", "INVTYPE_TABARD",
    }
    local generalTypeOrder = { 1, 12, 13, 15 }
    local craftingTypeOrder = { 3, 5, 7, 9 }
    local sourceOrder = { "consumable", "dungeon", "raid", "outdoor", "profession",
                          "vendor", "pvp", "reputation", "housing", "unknown" }

    -- Assigned once RefreshSummary exists; the chip sections below capture it by
    -- name so every filter click refreshes the live sentence and count.
    local RefreshLiveSummary

    -- Checkbox registry for search filtering
    local allCheckboxEntries = {}

    local function StripColorCodes(s)
        return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end

    local function FilterCheckboxes(searchText)
        local txt = (searchText or ""):lower():match("^%s*(.-)%s*$") or ""
        for _, entry in ipairs(allCheckboxEntries) do
            if txt == "" then
                entry.frame:Show()
            else
                local clean = StripColorCodes(entry.label):lower()
                entry.frame:SetShown(clean:find(txt, 1, true) ~= nil)
            end
        end
    end

    -- Frames to grey when not in "matching" mode
    local detailFrames = {}

    local function RefreshDetailGrey()
        local isMatching = LegacyVendorDB.sellMode == "matching"
        local r, g, b = isMatching and 1 or 0.45, isMatching and 1 or 0.45, isMatching and 1 or 0.45
        for _, f in ipairs(detailFrames) do
            if f.SetAlpha then
                f:SetAlpha(isMatching and 1.0 or 0.4)
            end
            if f.Text and f.Text.SetTextColor then
                f.Text:SetTextColor(r, g, b)
            end
        end
    end

    -- Formats copper as a short gold string for the live count line.
    local function ShortMoney(copper)
        if not copper or copper <= 0 then return "0g" end
        local gold = math.floor(copper / 10000)
        if gold > 0 then return gold .. "g" end
        local silver = math.floor((copper % 10000) / 100)
        if silver > 0 then return silver .. "s" end
        return (copper % 100) .. "c"
    end

    -- Recomputes the sentence AND the real bag count. The count is what turns an
    -- abstract filter set into something checkable, so it is worth the scan - it
    -- only ever runs while this panel is open and a setting just changed.
    local countPending = false
    local function RefreshSummary()
        topSummaryFrame:SetSentence(addon.BuildFilterSentence(LegacyVendorDB))
        if addon.BuildProtectionSummary then
            topSummaryFrame:SetProtections(addon.BuildProtectionSummary(LegacyVendorDB))
        end

        -- Coalesce rapid clicking into one scan.
        if not countPending then
            countPending = true
            C_Timer.After(0.05, function()
                countPending = false

                -- Everything a filter change affects, refreshed from one place:
                -- the panel's own count, the merchant's Sell (N) button, and the
                -- bag highlights. Previously only the first of these updated, so
                -- the button kept a stale number until the vendor was reopened.
                if addon.CountSellable then
                    local count, gold = addon.CountSellable()
                    if configFrame:IsShown() then
                        if count == 0 then
                            topSummaryFrame:SetCount("Nothing in your bags matches right now.", true)
                        else
                            topSummaryFrame:SetCount(string.format(
                                "%d item%s in your bags would sell right now  (about %s)",
                                count, count == 1 and "" or "s", ShortMoney(gold)), false)
                        end
                    end
                end

                RefreshButton()
                if addon.ScheduleHighlightUpdate then
                    addon.ScheduleHighlightUpdate()
                end
            end)
        end

        RefreshDetailGrey()
    end

    -- Chip sections call this by name; keep both spellings pointing at one function.
    RefreshLiveSummary = RefreshSummary

    -- Wire up search box scripts
    searchBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        searchLabel:SetShown(txt == "")
        FilterCheckboxes(txt)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        searchLabel:Show()
        FilterCheckboxes("")
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    local yOffset = -10
    local col2_col = 0
    local COL2_LEFT, COL2_RIGHT = 10, 310

    -- Horizontal separator line
    local function AddSep()
        yOffset = yOffset - 5
        local sep = content:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", content, "TOPLEFT", 8, yOffset)
        sep:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, yOffset)
        sep:SetColorTexture(0.3, 0.3, 0.3, 0.9)
        yOffset = yOffset - 8
    end

    -- Section header with optional subtitle
    -- iconKey indexes addon.Visuals.HeaderIcon; each block gets its own glyph so
    -- sections are identifiable while scrolling, before the text is read.
    local function AddHeader(text, subtitle, iconKey)
        local icon = iconKey and addon.Visuals and addon.Visuals.HeaderIcon[iconKey]
        local textX = 10

        if icon then
            local tex = content:CreateTexture(nil, "ARTWORK")
            tex:SetSize(26, 26)
            tex:SetPoint("TOPLEFT", 10, yOffset + 4)
            tex:SetTexture(icon)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local edge = content:CreateTexture(nil, "BACKGROUND")
            edge:SetPoint("TOPLEFT", tex, "TOPLEFT", -1, 1)
            edge:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 1, -1)
            edge:SetColorTexture(0, 0, 0, 0.8)

            textX = 44
        end

        local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        h:SetPoint("TOPLEFT", textX, yOffset)
        h:SetText(text)
        yOffset = yOffset - 22
        if subtitle then
            local s = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            s:SetPoint("TOPLEFT", textX + 4, yOffset)
            s:SetText("|cFF999999" .. subtitle .. "|r")
            yOffset = yOffset - 16
        end
        yOffset = yOffset - 4
    end

    local FILTER_ORDER_HELP = "Expansion -> Mode -> Rarity -> Bind -> Slot/Type -> Source -> ilvl checks"
    local currentTooltipScope = "global"

    local function SetTooltipScope(scope)
        currentTooltipScope = scope or "global"
    end

    local function AttachCheckboxTooltip(cb, label, tooltip)
        cb:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            local scopeTag = "|cFF66CCFF[Global]|r"
            if currentTooltipScope == "profile" then
                scopeTag = "|cFF77FF77[Per-Expansion]|r"
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:SetText((label or "Option") .. " " .. scopeTag, 1.0, 0.82, 0.0)
            GameTooltip:AddLine(tooltip or "No description available.", 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Filter order:", 0.55, 0.8, 1.0)
            GameTooltip:AddLine(FILTER_ORDER_HELP, 0.82, 0.82, 0.82, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end

    -- Single-column checkbox
    local function CreateCheckbox(parent, label, tooltip, getValue, setValue, refreshOnChange)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 10, yOffset)
        cb.Text:SetText(label)
        cb.tooltipText = tooltip
        AttachCheckboxTooltip(cb, label, tooltip)
        cb:SetChecked(getValue())
        cb:SetScript("OnClick", function(self)
            setValue(self:GetChecked())
            if refreshOnChange then RefreshButton() end
            RefreshSummary()
        end)
        yOffset = yOffset - 26
        table.insert(allCheckboxEntries, { frame = cb, label = label })
        return cb
    end

    -- Two-column checkbox (alternates left/right, advances yOffset on right)
    local function CreateCheckbox2Col(parent, label, tooltip, getValue, setValue, refreshOnChange)
        local xPos = (col2_col == 0) and COL2_LEFT or COL2_RIGHT
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", xPos, yOffset)
        cb.Text:SetText(label)
        cb.tooltipText = tooltip
        AttachCheckboxTooltip(cb, label, tooltip)
        cb:SetChecked(getValue())
        cb:SetScript("OnClick", function(self)
            setValue(self:GetChecked())
            if refreshOnChange then RefreshButton() end
            RefreshSummary()
        end)
        if col2_col == 0 then
            col2_col = 1
        else
            yOffset = yOffset - 26
            col2_col = 0
        end
        table.insert(allCheckboxEntries, { frame = cb, label = label })
        return cb
    end

    -- Flush incomplete 2-col row
    local function Flush2Col()
        if col2_col == 1 then
            yOffset = yOffset - 26
            col2_col = 0
        end
    end

    -- Button helper
    local function MakeBtn(xOff, label, onClick)
        local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", xOff, yOffset)
        btn:SetSize(205, 24)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    -- ==================================================
    -- GENERAL SETTINGS
    -- ==================================================
    AddHeader("|cFFFFD100How should it sell?|r",
        "A few decisions that shape everything else.", "general")
    SetTooltipScope("global")

    -- Small labelled sub-heading, so a long options list reads as grouped
    -- concerns (safety / behaviour / appearance) instead of one flat run.
    local function AddSubLabel(text)
        yOffset = yOffset - 4
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 14, yOffset)
        fs:SetText("|cFF8A8A8A" .. text .. "|r")
        yOffset = yOffset - 18
    end

    -- Step 1: Radio-style sell mode checkboxes (mutually exclusive)
    local function SetMode(m)
        LegacyVendorDB.sellMode = m
        RefreshButton()
        RefreshSummary()
        RefreshConfigFrame()
    end

    AddSubLabel("SELLING MODE")

    -- Mutually exclusive, so render as two chips rather than two checkboxes that
    -- merely behave like radio buttons.
    yOffset = addon.Sections.RenderChipGroup(content, yOffset, {
        { key = "everything", label = "Everything from those expansions",
          icon = "Interface\\ICONS\\INV_Misc_Coin_01",
          tooltip = "Ignore the detailed filters entirely. Fastest, least selective." },
        { key = "matching", label = "Only what matches my filters",
          icon = "Interface\\ICONS\\INV_Misc_Spyglass_02",
          tooltip = "Walk through the step-by-step filters below." },
    },
    function(key) return LegacyVendorDB.sellMode == key end,
    function(key, v) if v then SetMode(key) end end,
    nil, nil, nil)

    AddSubLabel("SAFETY")

    CreateCheckbox(content, "Protect uncollected appearances, mounts, toys & pets  |cFF44FF44(recommended)|r",
        "Never sell an item that would be your only source of an appearance, mount, toy or pet. "
        .. "Selling one of those cannot be undone.",
        function() return LegacyVendorDB.protectUncollected ~= false end,
        function(v)
            LegacyVendorDB.protectUncollected = v
            if addon.ResetCollectibleCache then addon.ResetCollectibleCache() end
            RefreshButton()
        end, true)

    CreateCheckbox(content, "Never sell gear at or above item level  |cFF44FF44(recommended)|r",
        "A plain safety net that does not depend on working out which expansion an item "
        .. "belongs to or where it came from - it just asks how good the item is. Uses the "
        .. "item's effective level, so legacy gear scaled up by current-season bonuses is "
        .. "judged at its real strength.",
        function() return LegacyVendorDB.protectHighIlvl end,
        function(v)
            LegacyVendorDB.protectHighIlvl = v
            RefreshButton()
            RefreshSummary()
        end, true)

    -- On its own row beneath the checkbox. Sharing the checkbox's row meant the box
    -- landed on top of the label text, which varies in width by locale and font.
    do
        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 46, yOffset - 2)
        lbl:SetText("|cFF888888Item level limit:|r")

        local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        box:SetSize(60, 20)
        box:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(4)
        box:SetText(tostring(LegacyVendorDB.highIlvlThreshold or 285))

        local function Commit(self)
            local v = tonumber(self:GetText()) or 0
            LegacyVendorDB.highIlvlThreshold = v
            self:SetText(tostring(v))
            self:ClearFocus()
            RefreshButton()
            RefreshSummary()
        end
        box:SetScript("OnEnterPressed", Commit)
        box:SetScript("OnEditFocusLost", Commit)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(LegacyVendorDB.highIlvlThreshold or 285))
            self:ClearFocus()
        end)

        local tip = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tip:SetPoint("LEFT", box, "RIGHT", 8, 0)
        tip:SetText("|cFF888888and above is never sold|r")

        yOffset = yOffset - 26
    end

    CreateCheckbox(content, "Protect current-season Mythic+ gear  |cFF44FF44(recommended)|r",
        "Hard-protect current-season scaled legacy dungeon items. Overrides every sell filter.",
        function() return LegacyVendorDB.strictSeasonalProtection ~= false end,
        function(v) LegacyVendorDB.strictSeasonalProtection = v end, true)

    CreateCheckbox(content, "Auto-confirm \"will become non-tradeable\" prompts",
        "WoW warns before selling loot that is still tradeable to your group, which stops "
        .. "those items selling until you click Okay. Turn this on to accept that prompt "
        .. "automatically during a sell run. Off by default, because it removes a warning "
        .. "the game deliberately shows you.",
        function() return LegacyVendorDB.autoConfirmTradeTimer end,
        function(v) LegacyVendorDB.autoConfirmTradeTimer = v end)

    CreateCheckbox(content, "Ask me before selling",
        "Show a confirmation dialog listing what is about to be sold.",
        function() return LegacyVendorDB.confirmSell end,
        function(v) LegacyVendorDB.confirmSell = v end)

    AddSubLabel("BEHAVIOUR")

    CreateCheckbox(content, "Sell automatically when I open a vendor",
        "OFF (recommended): you click the [Sell Legacy] button. ON: it sells the moment a vendor opens.",
        function() return LegacyVendorDB.autoSell end,
        function(v) LegacyVendorDB.autoSell = v end)

    CreateCheckbox(content, "Also sell grey (Poor) items",
        "Sell grey junk regardless of expansion or filters.",
        function() return LegacyVendorDB.sellGray end,
        function(v)
            LegacyVendorDB.sellGray = v
            RefreshButton()
        end)

    CreateCheckbox(content, "Tell me what I sold",
        "Print a summary in chat after selling.",
        function() return LegacyVendorDB.showSummary end,
        function(v) LegacyVendorDB.showSummary = v end)

    AddSubLabel("APPEARANCE")

    CreateCheckbox(content, "Show sell info on item tooltips",
        "Adds a line to any bag item's tooltip saying whether it will sell, and if not, why not.",
        function() return LegacyVendorDB.showTooltipInfo ~= false end,
        function(v) LegacyVendorDB.showTooltipInfo = v end)



    CreateCheckbox(content, "Highlight Sellable Items in Bags", "Show a glowing marker on items that will be sold.",
        function() return LegacyVendorDB.highlightItems end,
        function(v)
            LegacyVendorDB.highlightItems = v
            if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
        end)

    -- Highlight style picker + a live-animated preview swatch.
    if addon.HIGHLIGHT_STYLES and addon.HighlightStyleImpl then
        local pickerLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pickerLabel:SetPoint("TOPLEFT", 30, yOffset)
        pickerLabel:SetText("Highlight Style:")
        yOffset = yOffset - 4

        -- Preview swatch: a fake item icon with the same highlight visual applied,
        -- always animating (while this panel is open) so the user can compare styles
        -- before committing to one.
        local previewFrame = CreateFrame("Frame", nil, content)
        previewFrame:SetSize(36, 36)
        previewFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -30, yOffset)

        local previewBg = previewFrame:CreateTexture(nil, "BACKGROUND")
        previewBg:SetAllPoints()
        previewBg:SetColorTexture(0.08, 0.08, 0.08, 1)

        local previewIcon = previewFrame:CreateTexture(nil, "ARTWORK")
        previewIcon:SetPoint("TOPLEFT", 2, -2)
        previewIcon:SetPoint("BOTTOMRIGHT", -2, 2)
        previewIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        previewFrame.Icon = previewIcon -- mimics an item button's .Icon field

        local previewHl, previewDriver
        previewDriver = CreateFrame("Frame", nil, previewFrame)

        local function RebuildPreview()
            if previewHl and previewHl.host then
                previewHl.host:Hide()
            end

            local styleId = LegacyVendorDB.highlightStyle or addon.DEFAULT_HIGHLIGHT_STYLE
            local impl = addon.HighlightStyleImpl[styleId] or addon.HighlightStyleImpl[addon.DEFAULT_HIGHLIGHT_STYLE]

            local host = CreateFrame("Frame", nil, previewFrame)
            host:SetPoint("TOPLEFT", previewIcon, "TOPLEFT", -2, 2)
            host:SetPoint("BOTTOMRIGHT", previewIcon, "BOTTOMRIGHT", 2, -2)
            host:SetFrameLevel(previewFrame:GetFrameLevel() + 5)

            previewHl = { style = styleId, host = host, phase = 0, accum = 0 }
            impl.build(previewHl, host)

            local color = LegacyVendorDB.highlightColor or { r = 0.68, g = 0.45, b = 1.0 }
            impl.color(previewHl, color.r or 0.68, color.g or 0.45, color.b or 1.0)
            impl.update(previewHl, host, 0)
        end

        previewDriver:SetScript("OnUpdate", function(_, elapsed)
            if not previewHl or not configFrame:IsShown() then
                return
            end
            local impl = addon.HighlightStyleImpl[previewHl.style]
            if not impl or not impl.animated then
                return
            end
            previewHl.accum = (previewHl.accum or 0) + elapsed
            if previewHl.accum < 0.03 then
                return
            end
            local dt = previewHl.accum
            previewHl.accum = 0
            previewHl.phase = ((previewHl.phase or 0) + (dt * (impl.speed or 0.5))) % 1
            impl.update(previewHl, previewHl.host, previewHl.phase)
        end)

        local function GetStyleName(id)
            for _, s in ipairs(addon.HIGHLIGHT_STYLES) do
                if s.id == id then return s.name end
            end
            return id
        end

        local dropdown = CreateFrame("Frame", "LegacyVendorHighlightStyleDropdown", content, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", pickerLabel, "BOTTOMLEFT", -16, -2)
        UIDropDownMenu_SetWidth(dropdown, 170)

        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, style in ipairs(addon.HIGHLIGHT_STYLES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = style.name
                info.value = style.id
                info.checked = (LegacyVendorDB.highlightStyle == style.id)
                info.func = function()
                    LegacyVendorDB.highlightStyle = style.id
                    UIDropDownMenu_SetSelectedValue(dropdown, style.id)
                    UIDropDownMenu_SetText(dropdown, style.name)
                    RebuildPreview()
                    if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        local currentStyleId = LegacyVendorDB.highlightStyle or addon.DEFAULT_HIGHLIGHT_STYLE
        UIDropDownMenu_SetSelectedValue(dropdown, currentStyleId)
        UIDropDownMenu_SetText(dropdown, GetStyleName(currentStyleId))

        -- Color picker: a clickable swatch showing the current highlight color.
        local colorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        colorLabel:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, -12)
        colorLabel:SetText("Highlight Color:")

        local swatch = CreateFrame("Button", nil, content)
        swatch:SetSize(20, 20)
        swatch:SetPoint("LEFT", colorLabel, "RIGHT", 8, 0)

        local swatchBorder = swatch:CreateTexture(nil, "BACKGROUND")
        swatchBorder:SetPoint("TOPLEFT", -1, 1)
        swatchBorder:SetPoint("BOTTOMRIGHT", 1, -1)
        swatchBorder:SetColorTexture(0, 0, 0, 1)

        local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
        swatchTex:SetAllPoints()

        local function RefreshSwatch()
            local c = LegacyVendorDB.highlightColor or { r = 0.68, g = 0.45, b = 1.0, a = 0.85 }
            swatchTex:SetColorTexture(c.r or 0.68, c.g or 0.45, c.b or 1.0, 1)
        end

        local function ApplyColorChange(r, g, b)
            local prevA = (LegacyVendorDB.highlightColor and LegacyVendorDB.highlightColor.a) or 0.85
            LegacyVendorDB.highlightColor = { r = r, g = g, b = b, a = prevA }
            RefreshSwatch()
            if previewHl then
                local impl = addon.HighlightStyleImpl[previewHl.style]
                if impl then impl.color(previewHl, r, g, b) end
            end
            if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
        end

        local function OpenColorPicker()
            -- Modern retail splits ColorPickerFrame into a lazy-loaded sub-addon; make
            -- sure it's actually loaded before touching it (harmless no-op elsewhere).
            if not ColorPickerFrame then
                if C_AddOns and C_AddOns.LoadAddOn then
                    pcall(C_AddOns.LoadAddOn, "Blizzard_ColorPickerFrame")
                elseif LoadAddOn then
                    pcall(LoadAddOn, "Blizzard_ColorPickerFrame")
                end
            end
            if not ColorPickerFrame then
                return
            end

            local c = LegacyVendorDB.highlightColor or { r = 0.68, g = 0.45, b = 1.0, a = 0.85 }
            if ColorPickerFrame.SetupColorPickerAndShow then
                -- Modern retail API (Dragonflight+)
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = c.r, g = c.g, b = c.b,
                    hasOpacity = false,
                    swatchFunc = function()
                        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                        ApplyColorChange(nr, ng, nb)
                    end,
                    cancelFunc = function(previousValues)
                        if previousValues then
                            ApplyColorChange(previousValues.r, previousValues.g, previousValues.b)
                        end
                    end,
                })
            else
                -- Classic / older retail API
                ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
                ColorPickerFrame.hasOpacity = false
                ColorPickerFrame.previousValues = { r = c.r, g = c.g, b = c.b }
                ColorPickerFrame.func = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    ApplyColorChange(nr, ng, nb)
                end
                ColorPickerFrame.cancelFunc = function(previousValues)
                    ApplyColorChange(previousValues.r, previousValues.g, previousValues.b)
                end
                ColorPickerFrame:Show()
            end
        end

        swatch:SetScript("OnClick", OpenColorPicker)
        swatch:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Highlight Color")
            GameTooltip:AddLine("Click to choose a custom color for the bag highlight.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        RefreshSwatch()
        RebuildPreview()

        yOffset = yOffset - 80
    end

    MakeBtn(26, "Filter profiles", function()
        if addon.Profiles then addon.Profiles.Open() end
    end)
    yOffset = yOffset - 30

    MakeBtn(26, "Share / import filters", function()
        if addon.Share then addon.Share.Open("export") end
    end)
    yOffset = yOffset - 30

    MakeBtn(26, "Manage never-sell list", function()
        if addon.Exclusions then addon.Exclusions.Open() end
    end)
    yOffset = yOffset - 30

    AddSubLabel("TROUBLESHOOTING")

    CreateCheckbox(content, "Debug mode",
        "Record the decision made for every bag slot. Nothing goes to chat - open the "
        .. "log with the button below, or /lv exportlog.",
        function() return LegacyVendorDB.debug end,
        function(v) LegacyVendorDB.debug = v end)

    MakeBtn(26, "Open debug log", function()
        if addon.ShowExportLog then addon.ShowExportLog() end
    end)
    yOffset = yOffset - 30

    CreateCheckbox(content, "Enable LegacyVendor",
        "Master switch. When off, nothing is scanned, highlighted or sold.",
        function() return LegacyVendorDB.enabled end,
        function(v)
            LegacyVendorDB.enabled = v
            RefreshButton()
            if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
        end, true)

    AddSep()

    -- ==================================================
    -- PROGRESSIVE FILTER FLOW
    -- Sections reveal one at a time as the previous question is answered, and
    -- branch: picking "Gear" is what makes the gear-slot list appear. Showing all
    -- six groups at once is what made this read as a settings dump rather than a
    -- decision you walk through.
    -- ==================================================
    local AnyTrue = addon.Sections.AnyTrue

    -- Which sections the flow shows depends on these four answers, and they are
    -- evaluated while the panel is being built. So a chip that changes one of them
    -- has to rebuild, or the step it unlocks never appears - which is exactly what
    -- broke when the flow was introduced. Compare a signature before and after so
    -- only gate-changing clicks pay for a rebuild; every other chip just refreshes
    -- the sentence and count in place.
    local function GateSignature()
        return table.concat({
            tostring(AnyTrue(LegacyVendorDB.expansions)),
            tostring(AnyTrue(LegacyVendorDB.equipSlots)),
            tostring(AnyTrue(LegacyVendorDB.itemTypes)),
            tostring(LegacyVendorDB.sellMode),
        }, "|")
    end

    -- The signature this panel was BUILT for. A chip runs set() before onChange, so
    -- sampling "before" inside the handler would already reflect the change and
    -- never differ; comparing against what is currently on screen is the correct
    -- test for "the visible sections are now stale".
    local builtGateSignature = GateSignature()

    local function OnGatingFilterChanged()
        RefreshLiveSummary()
        if GateSignature() ~= builtGateSignature then
            RefreshConfigFrame()
        end
    end

    -- Muted "you are not there yet" line shown in place of the sections still ahead.
    -- Takes an optional action so the message can fix the thing it is describing
    -- instead of leaving the user at a dead end.
    local function AddGateHint(text, actionLabel, onAction)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 44, yOffset)
        fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, yOffset)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText("|cFF7F7F7F" .. text .. "|r")
        yOffset = yOffset - (fs:GetStringHeight() or 14) - 10

        if actionLabel and onAction then
            local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            btn:SetPoint("TOPLEFT", 44, yOffset)
            btn:SetSize(230, 24)
            btn:SetText(actionLabel)
            btn:SetScript("OnClick", onAction)
            yOffset = yOffset - 30
        end

        yOffset = yOffset - 8
    end

    -- STEP 0: the hard stops. These run BEFORE every filter below and override them,
    -- so showing them here - at the head of the same sequence - is the only way the
    -- flow tells the truth. Presented as settled context, not another question.
    do
        AddHeader("|cFF88CC88Always protected|r  |cFF888888(before any filter below)|r",
            "These are never sold, whatever you choose in the steps that follow.", "sources")

        local kept = addon.BuildProtectionSummary and addon.BuildProtectionSummary(LegacyVendorDB) or {}
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 44, yOffset)
        fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, yOffset)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)

        if #kept == 0 then
            fs:SetText("|cFFCC8844Nothing is protected. Every item matching the steps below will sell.|r")
        else
            fs:SetText("|cFF88CC88- " .. table.concat(kept, "\n- ") .. "|r")
        end
        yOffset = yOffset - (fs:GetStringHeight() or 14) - 12

        local editBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        editBtn:SetPoint("TOPLEFT", 44, yOffset)
        editBtn:SetSize(200, 22)
        editBtn:SetText("Change what is protected")
        editBtn:SetScript("OnClick", function()
            -- The guards live in General Settings above; jump there rather than
            -- duplicating the same controls in two places and letting them drift.
            scrollFrame:SetVerticalScroll(0)
        end)
        yOffset = yOffset - 34

        AddSep()
    end

    -- STEP 1: expansions. Always visible - everything else depends on it.
    AddHeader("|cFFFFD100Step 1 - Which expansions?|r",
        "Everything below narrows this. Current content is always protected.", "expansions")
    SetTooltipScope("global")

    yOffset = addon.Sections.RenderExpansions(content, yOffset, maxExpansion, OnGatingFilterChanged, nil, RefreshConfigFrame)

    local haveExpansion = AnyTrue(LegacyVendorDB.expansions)

    if not haveExpansion then
        AddGateHint("Pick at least one expansion above to carry on.")

    elseif LegacyVendorDB.sellMode ~= "matching" then
        -- In "sell everything" mode the detail filters genuinely do not run, so
        -- rendering them greyed-out was just noise. Say so instead.
        AddGateHint("You are in \"Everything from those expansions\" mode, so the detailed "
            .. "filters below do not apply - every legacy item from the expansions above "
            .. "will sell. Switch modes to pick rarities, bind types, gear slots and the rest.",
            "Let me choose filters instead",
            function() SetMode("matching") end)

    else
        AddSep()

        -- STEP 2: the branch point.
        AddHeader("|cFFFFD100Step 2 - What kinds of items?|r",
            "Pick one or both. Your choice decides which lists appear next.", "types")
        yOffset = addon.Sections.RenderItemKinds(content, yOffset, OnGatingFilterChanged, detailFrames, RefreshConfigFrame)

        local wantGear = AnyTrue(LegacyVendorDB.equipSlots)
        local wantOther = AnyTrue(LegacyVendorDB.itemTypes)

        if not (wantGear or wantOther) then
            AddGateHint("Choose gear, other items, or both to carry on.")
        else
            -- STEP 3a: only when gear is in scope.
            if wantGear then
                AddSep()
                AddHeader("|cFFFFD100Step 3 - Which gear slots?|r",
                    "Equippable items must match one of these.", "slots")
                yOffset = addon.Sections.RenderEquipSlots(content, yOffset, OnGatingFilterChanged, detailFrames, RefreshConfigFrame)
            end

            -- STEP 3b: only when non-gear is in scope.
            if wantOther then
                AddSep()
                AddHeader("|cFFFFD100Step " .. (wantGear and "3b" or "3") .. " - Which other items?|r",
                    "Crafting mats and quest items stay off until you pick them here.", "types")
                yOffset = addon.Sections.RenderItemTypes(content, yOffset, OnGatingFilterChanged, detailFrames, RefreshConfigFrame)
            end

            AddSep()

            -- STEP 4: quality.
            AddHeader("|cFFFFD100Step 4 - Which rarities?|r",
                "An item must match one of these to sell.", "rarity")
            yOffset = addon.Sections.RenderRarities(content, yOffset, RefreshLiveSummary, detailFrames, RefreshConfigFrame)

            AddSep()

            -- STEP 5: bind state.
            AddHeader("|cFFFFD100Step 5 - Which bind types?|r",
                "An item must match one of these to sell.", "bind")
            yOffset = addon.Sections.RenderBindTypes(content, yOffset, RefreshLiveSummary, detailFrames, RefreshConfigFrame)

            AddSep()

            -- STEP 6: exclusions last - they subtract from everything decided above.
            AddHeader("|cFFFFD100Step 6 - ...except never from|r  |cFFFF9944(optional)|r",
                "Anything from a highlighted source is skipped, even if it matched every step above.", "sources")
            yOffset = addon.Sections.RenderSources(content, yOffset, RefreshLiveSummary, detailFrames, RefreshConfigFrame)
        end
    end

    AddSep()

    -- ==================================================
    -- ADVANCED: per-expansion overrides (collapsible)
    -- Step 5: hidden by default; backed by LegacyVendorDB.showAdvanced
    -- ==================================================
    local advOpen = LegacyVendorDB.showAdvanced == true
    local advHeaderText = advOpen
        and "|cFFFFD100[-] Advanced: per-expansion overrides|r"
        or  "|cFF888888[+] Advanced: per-expansion overrides (click to expand)|r"
    AddHeader(advHeaderText,
        "Optional. Override the global filters for one specific expansion.")

    -- Invisible click button over the header row
    local advToggleBtn = CreateFrame("Button", nil, content)
    advToggleBtn:SetPoint("TOPLEFT", 8, yOffset + 38 + 22 + 16)  -- covers header + subtitle
    advToggleBtn:SetSize(430, 40)
    advToggleBtn:SetScript("OnClick", function()
        LegacyVendorDB.showAdvanced = not (LegacyVendorDB.showAdvanced == true)
        RefreshConfigFrame()
    end)

    if advOpen then
        -- Styled selector bar
        local selectedExpID = GetSelectedExpansionID()
        local selectedExp = addon.EXPANSIONS[selectedExpID]
        local selectedLabel = selectedExp and selectedExp.name or ("Expansion " .. selectedExpID)

        local selectorBg = CreateFrame("Frame", nil, content)
        selectorBg:SetPoint("TOPLEFT", 8, yOffset)
        selectorBg:SetPoint("TOPRIGHT", -8, yOffset)
        selectorBg:SetHeight(30)
        local selectorBg_bg = selectorBg:CreateTexture(nil, "BACKGROUND")
        selectorBg_bg:SetAllPoints(selectorBg)
        selectorBg_bg:SetColorTexture(0.05, 0.05, 0.2, 0.9)

        local prevBtn = CreateFrame("Button", nil, selectorBg, "UIPanelButtonTemplate")
        prevBtn:SetPoint("LEFT", selectorBg, "LEFT", 4, 0)
        prevBtn:SetSize(55, 22)
        prevBtn:SetText("< Prev")
        prevBtn:SetScript("OnClick", function()
            local id = GetSelectedExpansionID() - 1
            if id < 0 then id = maxExpansion end
            LegacyVendorDB.selectedExpansionProfileID = id
            RefreshConfigFrame()
        end)

        local nextBtn = CreateFrame("Button", nil, selectorBg, "UIPanelButtonTemplate")
        nextBtn:SetPoint("RIGHT", selectorBg, "RIGHT", -4, 0)
        nextBtn:SetSize(55, 22)
        nextBtn:SetText("Next >")
        nextBtn:SetScript("OnClick", function()
            local id = GetSelectedExpansionID() + 1
            if id > maxExpansion then id = 0 end
            LegacyVendorDB.selectedExpansionProfileID = id
            RefreshConfigFrame()
        end)

        local expNameLabel = selectorBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        expNameLabel:SetPoint("CENTER", selectorBg, "CENTER", 0, 0)
        expNameLabel:SetText("|cFF00CCFFEditing: |r|cFFFFFFFF" .. selectedLabel .. "|r")

        yOffset = yOffset - 38
        SetTooltipScope("profile")

        CreateCheckbox(content, "Use Detailed Filters For This Expansion",
            "ON: apply per-expansion nested filters below for this expansion only.",
            function() return GetSelectedProfile().useDetailedFilters end,
            function(v) GetSelectedProfile().useDetailedFilters = v end, true)

        CreateCheckbox(content, "Only Sell Lower Item Level  |cFF888888(this profile)|r",
            "Sell equippable items only if their ilvl is lower than your equipped item in that slot.",
            function() return GetSelectedProfile().onlySellLowerIlvl end,
            function(v) GetSelectedProfile().onlySellLowerIlvl = v end, true)

        AddSep()

        -- Per-profile Bind Type
        AddHeader("|cFFFFD100Bind Type  |cFF888888(this expansion profile)|r")

        CreateCheckbox(content, "Sell Soulbound (BoP)  |cFF888888[profile]|r", "Sell Bind on Pickup items for this expansion.",
            function() return GetSelectedProfile().bindTypes.bop end,
            function(v) GetSelectedProfile().bindTypes.bop = v end, true)

        CreateCheckbox(content, "Sell Bound BoE  |cFF888888[profile]|r", "Sell Bind on Equip items for this expansion.",
            function() return GetSelectedProfile().bindTypes.boe end,
            function(v) GetSelectedProfile().bindTypes.boe = v end, true)

        CreateCheckbox(content, "Sell Not Bound  |cFFFF5555[profile, careful!]|r",
            "Sell unbound items for this expansion.",
            function() return GetSelectedProfile().bindTypes.unbound end,
            function(v) GetSelectedProfile().bindTypes.unbound = v end, true)

        AddSep()

        -- Per-profile Rarity
        AddHeader("|cFFFFD100Rarity  |cFF888888(this expansion profile)|r")

        for _, rarityID in ipairs(rarityOrder) do
            local rarity = addon.RARITIES[rarityID]
            if rarity then
                local coloredName = string.format("|cFF%s%s|r", rarity.color, rarity.name)
                CreateCheckbox2Col(content, coloredName, "Sell " .. rarity.name .. " quality items (this expansion).",
                    function() return GetSelectedProfile().rarities[rarityID] end,
                    function(v) GetSelectedProfile().rarities[rarityID] = v end)
            end
        end
        Flush2Col()

        AddSep()

        -- Per-profile Equipment Slots
        AddHeader("|cFFFFD100Equipment Slots  |cFF888888(this expansion profile)|r")

        for _, slotKey in ipairs(slotOrder) do
            local slot = addon.EQUIP_SLOTS[slotKey]
            if slot then
                CreateCheckbox2Col(content, slot.name, "Sell items in " .. slot.name .. " slot (this expansion).",
                    function() return GetSelectedProfile().equipSlots[slotKey] end,
                    function(v) GetSelectedProfile().equipSlots[slotKey] = v end)
            end
        end
        Flush2Col()

        AddSep()

        -- Per-profile Item Types
        AddHeader("|cFFFFD100Item Types  |cFF888888(this expansion profile)|r")

        for _, typeID in ipairs(generalTypeOrder) do
            local itemType = addon.ITEM_TYPES[typeID]
            if itemType then
                CreateCheckbox2Col(content, itemType.name, "Sell " .. itemType.name .. " (this expansion).",
                    function() return GetSelectedProfile().itemTypes[typeID] end,
                    function(v) GetSelectedProfile().itemTypes[typeID] = v end)
            end
        end
        Flush2Col()

        for _, typeID in ipairs(craftingTypeOrder) do
            local itemType = addon.ITEM_TYPES[typeID]
            if itemType then
                CreateCheckbox2Col(content, itemType.name, "Sell " .. itemType.name .. " (this expansion, off by default).",
                    function() return GetSelectedProfile().itemTypes[typeID] end,
                    function(v) GetSelectedProfile().itemTypes[typeID] = v end)
            end
        end
        Flush2Col()

        AddSep()

        -- Per-profile Source Filtering
        AddHeader("|cFFFFD100Source Filtering  |cFF888888(this expansion profile)|r")

        CreateCheckbox(content, "Enable Source Filtering  |cFF888888[profile]|r",
            "When ON, only items from checked sources below are sold for this expansion.",
            function() return GetSelectedProfile().filterBySource end,
            function(v) GetSelectedProfile().filterBySource = v end, true)

        for _, sourceKey in ipairs(sourceOrder) do
            local source = addon.ITEM_SOURCES[sourceKey]
            if source then
                CreateCheckbox2Col(content, source.name, "Include: " .. source.name .. " (this expansion).",
                    function() return GetSelectedProfile().itemSources[sourceKey] end,
                    function(v) GetSelectedProfile().itemSources[sourceKey] = v end, true)
            end
        end
        Flush2Col()

        AddSep()
    end -- advOpen

    SetTooltipScope("global")

    -- ==================================================
    -- QUICK ACTIONS
    -- ==================================================
    AddHeader("|cFFFFD100Quick Actions|r", nil, "actions")

    MakeBtn(10, "Enable Legacy Expansions", function()
        for i = 0, addon.CURRENT_EXPANSION - 1 do LegacyVendorDB.expansions[i] = true end
        addon.Print("All legacy expansions enabled.")
        RefreshConfigFrame()
    end)
    MakeBtn(216, "Disable All Expansions", function()
        for i = 0, addon.CURRENT_EXPANSION do LegacyVendorDB.expansions[i] = false end
        addon.Print("All expansions disabled.")
        RefreshConfigFrame()
    end)
    yOffset = yOffset - 30

    -- Quick Actions: equip slots and rarities now target global DB fields
    MakeBtn(10, "Enable All Equip Slots", function()
        for k in pairs(addon.EQUIP_SLOTS) do LegacyVendorDB.equipSlots[k] = true end
        addon.Print("All equipment slots enabled.")
        RefreshConfigFrame()
    end)
    MakeBtn(216, "Disable All Equip Slots", function()
        for k in pairs(addon.EQUIP_SLOTS) do LegacyVendorDB.equipSlots[k] = false end
        addon.Print("All equipment slots disabled.")
        RefreshConfigFrame()
    end)
    yOffset = yOffset - 30

    MakeBtn(10, "Safe Rarities (G/U/R/E)", function()
        LegacyVendorDB.rarities[0]=true;  LegacyVendorDB.rarities[1]=false; LegacyVendorDB.rarities[2]=true
        LegacyVendorDB.rarities[3]=true;  LegacyVendorDB.rarities[4]=true;  LegacyVendorDB.rarities[5]=false
        LegacyVendorDB.rarities[6]=false; LegacyVendorDB.rarities[7]=false
        addon.Print("Safe rarities enabled.")
        RefreshConfigFrame()
    end)
    MakeBtn(216, "Disable All Rarities", function()
        for rarityID in pairs(addon.RARITIES) do LegacyVendorDB.rarities[rarityID] = false end
        addon.Print("All rarities disabled.")
        RefreshConfigFrame()
    end)
    yOffset = yOffset - 40

    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 10, yOffset)
    resetBtn:SetSize(195, 24)
    resetBtn:SetText("Reset ALL to Defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopupDialogs["LEGACYVENDOR_RESET"] = {
            text = "Reset ALL LegacyVendor settings to defaults?",
            button1 = "Yes", button2 = "No",
            OnAccept = function()
                SlashCmdList["LEGACYVENDOR"]("reset")
                configFrame:Hide()
            end,
            timeout = 0, whileDead = false, hideOnEscape = true,
        }
        StaticPopup_Show("LEGACYVENDOR_RESET")
    end)
    yOffset = yOffset - 30

    content:SetHeight(math.abs(yOffset) + 50)
    RefreshSummary()

    -- Scroll range is only known after the new content lays out, so defer a frame.
    if addon._configScroll and addon._configScroll > 0 then
        local target = addon._configScroll
        C_Timer.After(0, function()
            if not scrollFrame then return end
            local maxScroll = scrollFrame:GetVerticalScrollRange() or 0
            scrollFrame:SetVerticalScroll(math.min(target, maxScroll))
        end)
    end

    addon.configFrame = configFrame
    return configFrame
end

-- Open config function
function addon.OpenConfig()
    -- Always use the simple frame because it contains the full expansion profile editor.
    if not addon.configFrame then
        CreateSimpleConfig()
    end
    if addon.configFrame:IsShown() then
        addon.configFrame:Hide()
    else
        addon.configFrame:Show()
    end
end

-- Initialize config when addon loads
local configLoader = CreateFrame("Frame")
configLoader:RegisterEvent("PLAYER_LOGIN")
configLoader:SetScript("OnEvent", function(self, event)
    -- Delay config creation to ensure saved variables are loaded
    C_Timer.After(1, function()
        -- Try to use modern Settings API
        if Settings and Settings.RegisterVerticalLayoutCategory then
            pcall(CreateOptionsPanel)
        end
        -- Always create simple config as fallback
        CreateSimpleConfig()
    end)
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Add to Blizzard addon list
if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    AddonCompartmentFrame:RegisterAddon({
        text = "LegacyVendor",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        notCheckable = true,
        func = function()
            addon.OpenConfig()
        end,
    })
end
