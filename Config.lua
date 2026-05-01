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
    
    -- Auto-sell toggle
    do
        local variable = "LegacyVendor_AutoSell"
        local name = "Auto-Sell Mode"
        local tooltip = "When enabled, items are sold automatically when opening a vendor. When disabled (default), you must click the [Sell Legacy] button at vendors. Manual mode is recommended for compatibility with Blizzard's API restrictions."
        
        local setting = Settings.RegisterProxySetting(category, variable, 
            Settings.VarType.Boolean, name, LegacyVendorDB.autoSell,
            function() return LegacyVendorDB.autoSell end,
            function(value) LegacyVendorDB.autoSell = value end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Strict seasonal protection toggle
    do
        local variable = "LegacyVendor_StrictSeasonalProtection"
        local name = "Strict Seasonal M+ Protection"
        local tooltip = "Hard-protect current-season scaled legacy dungeon items. When enabled (recommended), this protection is checked first and overrides all sell filters for those items."

        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.strictSeasonalProtection,
            function() return LegacyVendorDB.strictSeasonalProtection ~= false end,
            function(value) LegacyVendorDB.strictSeasonalProtection = value; RefreshButton() end)

        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Expansion meta mode toggle
    do
        local variable = "LegacyVendor_ExpansionMetaMode"
        local name = "Expansion Meta Mode (Sell All In Checked Expansions)"
        local tooltip = "When enabled, checking an expansion means sell all items in that expansion bucket. Current-season M+ dungeon gear is treated as current expansion in this mode."

        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.expansionSellAllMode,
            function() return LegacyVendorDB.expansionSellAllMode ~= false end,
            function(value) LegacyVendorDB.expansionSellAllMode = value; RefreshButton() end)

        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Show summary toggle
    do
        local variable = "LegacyVendor_ShowSummary"
        local name = "Show Sale Summary"
        local tooltip = "Display a summary message after selling items."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.showSummary,
            function() return LegacyVendorDB.showSummary end,
            function(value) LegacyVendorDB.showSummary = value end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Confirm before selling toggle
    do
        local variable = "LegacyVendor_ConfirmSell"
        local name = "Confirm Before Selling"
        local tooltip = "Show a confirmation dialog before selling items."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.confirmSell,
            function() return LegacyVendorDB.confirmSell end,
            function(value) LegacyVendorDB.confirmSell = value end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Sell gray items toggle
    do
        local variable = "LegacyVendor_SellGray"
        local name = "Also Sell Gray Items"
        local tooltip = "Automatically sell all gray (poor quality) items regardless of expansion."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.sellGray,
            function() return LegacyVendorDB.sellGray end,
            function(value) LegacyVendorDB.sellGray = value end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Highlight items in bags toggle
    do
        local variable = "LegacyVendor_HighlightItems"
        local name = "Highlight Sellable Items in Bags"
        local tooltip = "Show a red glow on items in your bags that will be sold. Makes it easy to see what Legacy Vendor will sell."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.highlightItems,
            function() return LegacyVendorDB.highlightItems end,
            function(value) 
                LegacyVendorDB.highlightItems = value
                if addon.ScheduleHighlightUpdate then
                    addon.ScheduleHighlightUpdate()
                end
            end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Only sell items lower ilvl than equipped toggle
    do
        local variable = "LegacyVendor_OnlySellLowerIlvl"
        local name = "Only Sell Lower Item Level"
        local tooltip = "When enabled, equippable items will only be sold if their item level is lower than what you currently have equipped in the same slot. Items without a slot are not affected."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.onlySellLowerIlvl,
            function() return LegacyVendorDB.onlySellLowerIlvl end,
            function(value) LegacyVendorDB.onlySellLowerIlvl = value; RefreshButton() end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- ==========================================
    -- BIND TYPE FILTERS
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Bind Type Filters"))
    
    -- Sell BoP items toggle
    do
        local variable = "LegacyVendor_SellBoP"
        local name = "Sell Bind on Pickup (Soulbound)"
        local tooltip = "Sell items that are Bind on Pickup and soulbound to you."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.sellBoP,
            function() return LegacyVendorDB.sellBoP end,
            function(value) LegacyVendorDB.sellBoP = value; RefreshButton() end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Sell BoE items toggle
    do
        local variable = "LegacyVendor_SellBoE"
        local name = "Sell Bind on Equip (Bound)"
        local tooltip = "Sell items that were Bind on Equip but are now bound to you. Be careful with valuable transmog!"
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.sellBoE,
            function() return LegacyVendorDB.sellBoE end,
            function(value) LegacyVendorDB.sellBoE = value; RefreshButton() end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Sell Unbound items toggle
    do
        local variable = "LegacyVendor_SellUnbound"
        local name = "Sell Not Bound (Food, Reagents)"
        local tooltip = "Sell items that are not bound at all, like old food, potions, and crafting materials. Use with caution!"
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.sellUnbound,
            function() return LegacyVendorDB.sellUnbound end,
            function(value) LegacyVendorDB.sellUnbound = value; RefreshButton() end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Max items per visit slider
    do
        local variable = "LegacyVendor_MaxSell"
        local name = "Max Items Per Visit"
        local tooltip = "Maximum number of items to sell per vendor visit."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Number, name, LegacyVendorDB.maxSellPerVisit,
            function() return LegacyVendorDB.maxSellPerVisit end,
            function(value) LegacyVendorDB.maxSellPerVisit = value end)
        
        local options = Settings.CreateSliderOptions(1, 100, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, setting, options, tooltip)
    end
    
    -- ==========================================
    -- ITEM SOURCE FILTERS
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Item Source Filters"))
    
    -- Filter by source toggle (master toggle)
    do
        local variable = "LegacyVendor_FilterBySource"
        local name = "Enable Source Filtering"
        local tooltip = "When enabled, only sell items from checked sources (dungeons, raids, etc.). When disabled, source is ignored."
        
        local setting = Settings.RegisterProxySetting(category, variable,
            Settings.VarType.Boolean, name, LegacyVendorDB.filterBySource,
            function() return LegacyVendorDB.filterBySource end,
            function(value) LegacyVendorDB.filterBySource = value; RefreshButton() end)
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Create toggles for each source type
    local sourceOrder = { "consumable", "dungeon", "raid", "outdoor", "profession", "vendor", "pvp", "reputation", "housing", "unknown" }
    for _, sourceKey in ipairs(sourceOrder) do
        local source = addon.ITEM_SOURCES[sourceKey]
        if source then
            local variable = "LegacyVendor_Source_" .. sourceKey
            local name = source.name
            local tooltip = "Include items from " .. source.name .. " when source filtering is enabled."
            
            local setting = Settings.RegisterProxySetting(category, variable,
                Settings.VarType.Boolean, name, LegacyVendorDB.itemSources[sourceKey],
                function() return LegacyVendorDB.itemSources[sourceKey] end,
                function(value) LegacyVendorDB.itemSources[sourceKey] = value; RefreshButton() end)
            
            Settings.CreateCheckbox(category, setting, tooltip)
        end
    end
    
    -- ==========================================
    -- EXPANSION FILTERS
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Expansion Filters"))
    
    -- Get max expansion for this version
    local maxExpansion = addon.MAX_EXPANSION or addon.CURRENT_EXPANSION
    
    -- Create toggles for each expansion (only show expansions that exist in this WoW version)
    for i = 0, maxExpansion do
        local exp = addon.EXPANSIONS[i]
        if exp then
            local variable = "LegacyVendor_Exp" .. i
            local name = exp.name .. " (" .. exp.short .. ")"
            local tooltip = "Enable selling of Bind on Pickup items from " .. exp.name .. "."
            
            local setting = Settings.RegisterProxySetting(category, variable,
                Settings.VarType.Boolean, name, LegacyVendorDB.expansions[i],
                function() return LegacyVendorDB.expansions[i] end,
                function(value)
                    LegacyVendorDB.expansions[i] = value
                    RefreshButton()
                end)
            
            Settings.CreateCheckbox(category, setting, tooltip)
        end
    end
    
    -- ==========================================
    -- RARITY FILTERS
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Rarity Filters"))
    
    local rarityOrder = {0, 1, 2, 3, 4, 5, 6, 7}
    for _, rarityID in ipairs(rarityOrder) do
        local rarity = addon.RARITIES[rarityID]
        if rarity then
            local variable = "LegacyVendor_Rarity" .. rarityID
            local name = rarity.name
            local tooltip = "Enable selling of " .. rarity.name .. " quality items."
            
            local setting = Settings.RegisterProxySetting(category, variable,
                Settings.VarType.Boolean, name, LegacyVendorDB.rarities[rarityID],
                function() return LegacyVendorDB.rarities[rarityID] end,
                function(value) LegacyVendorDB.rarities[rarityID] = value; RefreshButton() end)
            
            Settings.CreateCheckbox(category, setting, tooltip)
        end
    end
    
    -- ==========================================
    -- EQUIPMENT SLOT FILTERS
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Equipment Slot Filters"))
    
    local slotOrder = {
        "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
        "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND",
        "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
        "INVTYPE_FINGER", "INVTYPE_TRINKET",
        "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", 
        "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_SHIELD",
        "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
        "INVTYPE_BODY", "INVTYPE_TABARD"
    }
    
    for _, slotKey in ipairs(slotOrder) do
        local slot = addon.EQUIP_SLOTS[slotKey]
        if slot then
            local variable = "LegacyVendor_Slot_" .. slotKey
            local name = slot.name
            local tooltip = "Enable selling of items equipped in " .. slot.name .. " slot."
            
            local setting = Settings.RegisterProxySetting(category, variable,
                Settings.VarType.Boolean, name, LegacyVendorDB.equipSlots[slotKey],
                function() return LegacyVendorDB.equipSlots[slotKey] end,
                function(value) LegacyVendorDB.equipSlots[slotKey] = value; RefreshButton() end)
            
            Settings.CreateCheckbox(category, setting, tooltip)
        end
    end
    
    -- ==========================================
    -- ITEM TYPE FILTERS (Non-Equippable)
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Non-Equippable Item Types"))

    local typeHint = layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Note: Consumables are configured in Item Source Filters."))
    local generalTypeOrder = {1, 12, 13, 15}
    for _, typeID in ipairs(generalTypeOrder) do
        local itemType = addon.ITEM_TYPES[typeID]
        if itemType then
            local variable = "LegacyVendor_Type" .. typeID
            local name = itemType.name
            local tooltip = "Enable selling of " .. itemType.name .. "."
            
            local setting = Settings.RegisterProxySetting(category, variable,
                Settings.VarType.Boolean, name, LegacyVendorDB.itemTypes[typeID],
                function() return LegacyVendorDB.itemTypes[typeID] end,
                function(value) LegacyVendorDB.itemTypes[typeID] = value; RefreshButton() end)
            
            Settings.CreateCheckbox(category, setting, tooltip)
        end
    end
    
    -- ==========================================
    -- CRAFTING & PROFESSION ITEM FILTERS
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Crafting & Profession Items"))
    
    -- Gems, Reagents, Trade Goods (Vellums), and Recipes are off by default.
    -- Only enable if you intentionally want to sell legacy crafting materials.
    local craftingTypeOrder = {3, 5, 7, 9}
    for _, typeID in ipairs(craftingTypeOrder) do
        local itemType = addon.ITEM_TYPES[typeID]
        if itemType then
            local variable = "LegacyVendor_Type" .. typeID
            local name = itemType.name
            local tooltip = "Enable selling of " .. itemType.name .. ". Off by default — enable only to sell legacy crafting materials."
            
            local setting = Settings.RegisterProxySetting(category, variable,
                Settings.VarType.Boolean, name, LegacyVendorDB.itemTypes[typeID],
                function() return LegacyVendorDB.itemTypes[typeID] end,
                function(value) LegacyVendorDB.itemTypes[typeID] = value; RefreshButton() end)
            
            Settings.CreateCheckbox(category, setting, tooltip)
        end
    end
    
    -- Register the category
    Settings.RegisterAddOnCategory(category)
    
    addon.settingsCategory = category
end

-- Alternative simple frame-based config for compatibility
local function CreateSimpleConfig()
    local configFrame = CreateFrame("Frame", "LegacyVendorConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(480, 670)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:Hide()

    configFrame.TitleBg:SetHeight(30)
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.title:SetPoint("TOP", configFrame.TitleBg, "TOP", 0, -3)
    configFrame.title:SetText("LegacyVendor Settings")

    local insetFrame = configFrame.Inset or configFrame
    local insetOffsetT = configFrame.Inset and -5 or -32
    local insetOffsetB = configFrame.Inset and 5 or 8

    -- Active filter summary bar (top)
    local topSummaryFrame = CreateFrame("Frame", nil, configFrame)
    topSummaryFrame:SetPoint("TOPLEFT", insetFrame, "TOPLEFT", 8, insetOffsetT - 1)
    topSummaryFrame:SetPoint("TOPRIGHT", insetFrame, "TOPRIGHT", -8, insetOffsetT - 1)
    topSummaryFrame:SetHeight(20)
    local topSummaryBgTex = topSummaryFrame:CreateTexture(nil, "BACKGROUND")
    topSummaryBgTex:SetAllPoints()
    topSummaryBgTex:SetColorTexture(0.02, 0.15, 0.02, 0.85)
    local topSummaryText = topSummaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topSummaryText:SetPoint("LEFT", topSummaryFrame, "LEFT", 6, 0)
    topSummaryText:SetPoint("RIGHT", topSummaryFrame, "RIGHT", -6, 0)
    topSummaryText:SetJustifyH("LEFT")
    topSummaryText:SetWordWrap(false)

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
    content:SetSize(430, 2000)
    scrollFrame:SetScrollChild(content)

    -- Active filter summary bar (bottom)
    local bottomSummaryFrame = CreateFrame("Frame", nil, configFrame)
    bottomSummaryFrame:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 3, -3)
    bottomSummaryFrame:SetPoint("TOPRIGHT", scrollFrame, "BOTTOMRIGHT", 25, -3)
    bottomSummaryFrame:SetHeight(20)
    local bottomSummaryBgTex = bottomSummaryFrame:CreateTexture(nil, "BACKGROUND")
    bottomSummaryBgTex:SetAllPoints()
    bottomSummaryBgTex:SetColorTexture(0.02, 0.15, 0.02, 0.85)
    local bottomSummaryText = bottomSummaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bottomSummaryText:SetPoint("LEFT", bottomSummaryFrame, "LEFT", 6, 0)
    bottomSummaryText:SetPoint("RIGHT", bottomSummaryFrame, "RIGHT", -6, 0)
    bottomSummaryText:SetJustifyH("LEFT")
    bottomSummaryText:SetWordWrap(false)

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
        configFrame:Hide()
        addon.configFrame = nil
        CreateSimpleConfig()
        if wasShown and addon.configFrame then
            addon.configFrame:Show()
        end
    end

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

    local function BuildActiveSummary()
        if not LegacyVendorDB then return "|cFF44FF44—|r" end
        local parts = {}
        local metaOn = LegacyVendorDB.expansionSellAllMode ~= false

        -- Expansions: label changes based on meta mode
        local expNames = {}
        local maxExp = addon.MAX_EXPANSION or addon.CURRENT_EXPANSION or 0
        for i = 0, maxExp do
            if LegacyVendorDB.expansions and LegacyVendorDB.expansions[i] then
                local exp = addon.EXPANSIONS and addon.EXPANSIONS[i]
                if exp then table.insert(expNames, exp.short or exp.name) end
            end
        end
        if #expNames > 0 then
            if metaOn then
                -- Meta ON: checked expansion = sell all from it
                table.insert(parts, "|cFF44FF44Sell-all:|r " .. table.concat(expNames, " "))
            else
                -- Meta OFF: checked expansion only enables the bucket; detailed filters still gate each item
                table.insert(parts, "|cFFFFAA00Detailed:|r " .. table.concat(expNames, " "))
            end
        else
            table.insert(parts, "|cFFFF4444No expansions active|r")
        end

        -- Rarities (from currently-viewed profile, informational only)
        local rarNames = {}
        local expID = LegacyVendorDB.selectedExpansionProfileID or 0
        local profile = LegacyVendorDB.expansionProfiles and LegacyVendorDB.expansionProfiles[expID]
        if profile and profile.rarities then
            for rarID = 0, 7 do
                if profile.rarities[rarID] then
                    local rar = addon.RARITIES and addon.RARITIES[rarID]
                    if rar then table.insert(rarNames, rar.name:sub(1, 3)) end
                end
            end
        end
        if #rarNames > 0 then
            table.insert(parts, "Rar: " .. table.concat(rarNames, "/"))
        end

        -- Global flags
        local flags = {}
        if LegacyVendorDB.sellGray then table.insert(flags, "+Grays") end
        if LegacyVendorDB.autoSell then table.insert(flags, "Auto") end
        if LegacyVendorDB.strictSeasonalProtection ~= false then table.insert(flags, "M+Prot") end
        if #flags > 0 then
            table.insert(parts, table.concat(flags, " · "))
        end

        return "|cFF44FF44" .. table.concat(parts, "  ·  ") .. "|r"
    end

    local function RefreshSummary()
        local s = BuildActiveSummary()
        topSummaryText:SetText(s)
        bottomSummaryText:SetText(s)
    end

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
    local COL2_LEFT, COL2_RIGHT = 10, 225

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
    local function AddHeader(text, subtitle)
        local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        h:SetPoint("TOPLEFT", 10, yOffset)
        h:SetText(text)
        yOffset = yOffset - 22
        if subtitle then
            local s = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            s:SetPoint("TOPLEFT", 14, yOffset)
            s:SetText("|cFF999999" .. subtitle .. "|r")
            yOffset = yOffset - 16
        end
    end

    local FILTER_ORDER_HELP = "Expansion -> Meta/Detailed mode -> Rarity -> Bind -> Slot/Type -> Source -> ilvl checks"
    local currentTooltipScope = "global"

    local function SetTooltipScope(scope)
        currentTooltipScope = scope or "global"
    end

    local function AttachCheckboxTooltip(cb, label, tooltip)
        cb:SetScript("OnEnter", function(self)
            if not GameTooltip then
                return
            end

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
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Note: Some options are global, others apply only to the selected expansion profile.", 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end)

        cb:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
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
        btn:SetSize(195, 24)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    -- ==================================================
    -- GENERAL SETTINGS
    -- ==================================================
    AddHeader("|cFFFFD100General Settings|r",
        "Priority: Expansion -> (Meta/Detailed) -> Rarity -> Bind -> Slot/Type -> Source -> ilvl checks.")
    SetTooltipScope("global")

    CreateCheckbox(content, "Enable LegacyVendor", "Enable or disable automatic selling.",
        function() return LegacyVendorDB.enabled end,
        function(v) LegacyVendorDB.enabled = v end, true)

    CreateCheckbox(content, "Auto-Sell Mode",
        "When OFF: click [Sell Legacy] button at vendors (recommended). When ON: auto-sell on vendor open.",
        function() return LegacyVendorDB.autoSell end,
        function(v) LegacyVendorDB.autoSell = v end)

    CreateCheckbox(content, "Expansion Meta Mode  |cFF888888(sell all in checked expansions)|r",
        "Checked expansions sell everything in that expansion bucket.",
        function() return LegacyVendorDB.expansionSellAllMode ~= false end,
        function(v) LegacyVendorDB.expansionSellAllMode = v end, true)

    CreateCheckbox(content, "Strict Seasonal M+ Protection  |cFF44FF44(recommended)|r",
        "Hard-protect current-season scaled legacy dungeon items. Overrides all sell filters.",
        function() return LegacyVendorDB.strictSeasonalProtection ~= false end,
        function(v) LegacyVendorDB.strictSeasonalProtection = v end, true)

    CreateCheckbox(content, "Show Sale Summary", "Display a summary message after selling.",
        function() return LegacyVendorDB.showSummary end,
        function(v) LegacyVendorDB.showSummary = v end)

    CreateCheckbox(content, "Confirm Before Selling", "Show confirmation dialog before selling.",
        function() return LegacyVendorDB.confirmSell end,
        function(v) LegacyVendorDB.confirmSell = v end)

    CreateCheckbox(content, "Also Sell Gray Items", "Sell all gray items automatically.",
        function() return LegacyVendorDB.sellGray end,
        function(v) LegacyVendorDB.sellGray = v end)

    CreateCheckbox(content, "Highlight Sellable Items in Bags", "Show red glow on items that will be sold.",
        function() return LegacyVendorDB.highlightItems end,
        function(v)
            LegacyVendorDB.highlightItems = v
            if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
        end)

    CreateCheckbox(content, "Debug Mode", "Show debug messages in chat.",
        function() return LegacyVendorDB.debug end,
        function(v) LegacyVendorDB.debug = v end)

    AddSep()

    -- ==================================================
    -- EXPANSION PROFILE EDITOR
    -- ==================================================
    AddHeader("|cFFFFD100Expansion Profile Editor|r",
        "Meta mode = sell all in checked expansion (but still respects Source if enabled). Detailed mode uses all nested filters.")
    SetTooltipScope("profile")

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

    CreateCheckbox(content, "Use Detailed Filters For This Expansion",
        "OFF: meta mode sells all from this expansion. ON: apply per-expansion nested filters below.",
        function() return GetSelectedProfile().useDetailedFilters end,
        function(v) GetSelectedProfile().useDetailedFilters = v end, true)

    CreateCheckbox(content, "Only Sell Lower Item Level  |cFF888888(this profile)|r",
        "Sell equippable items only if their ilvl is lower than your equipped item in that slot.",
        function() return GetSelectedProfile().onlySellLowerIlvl end,
        function(v) GetSelectedProfile().onlySellLowerIlvl = v end, true)

    AddSep()

    -- ==================================================
    -- EXPANSION FILTERS (with inline status badges)
    -- ==================================================
    AddHeader("|cFFFFD100Expansion Filters|r  |cFF888888(check = SELL)|r",
        "Meta ON: checked expansion sells all. Meta OFF: must also pass detailed filters.")
    SetTooltipScope("global")

    for i = 0, maxExpansion do
        local exp = addon.EXPANSIONS[i]
        if exp then
            local profile = LegacyVendorDB.expansionProfiles and LegacyVendorDB.expansionProfiles[i]
            local enabled = LegacyVendorDB.expansions[i]
            local badge = ""
            if enabled then
                if profile and profile.useDetailedFilters then
                    badge = " |cFF00CCFF[detail]|r"
                elseif LegacyVendorDB.expansionSellAllMode then
                    badge = " |cFF44FF44[all]|r"
                else
                    badge = " |cFFFFFF44[global]|r"
                end
            end
            CreateCheckbox2Col(content, (exp.short or exp.name) .. badge,
                "Enable selling items from " .. exp.name,
                function() return LegacyVendorDB.expansions[i] end,
                function(v) LegacyVendorDB.expansions[i] = v end)
        end
    end
    Flush2Col()

    AddSep()

    -- ==================================================
    -- BIND TYPE FILTERS
    -- ==================================================
    AddHeader("|cFFFFD100Bind Type Filters|r  |cFF888888(this expansion profile)|r")
    SetTooltipScope("profile")

    CreateCheckbox(content, "Sell Soulbound (BoP)", "Sell Bind on Pickup items.",
        function() return GetSelectedProfile().bindTypes.bop end,
        function(v) GetSelectedProfile().bindTypes.bop = v end, true)

    CreateCheckbox(content, "Sell Bound BoE", "Sell Bind on Equip items that are already bound.",
        function() return GetSelectedProfile().bindTypes.boe end,
        function(v) GetSelectedProfile().bindTypes.boe = v end, true)

    CreateCheckbox(content, "Sell Not Bound  |cFFFF5555(careful!)|r",
        "Sell unbound items — old food, reagents, etc.",
        function() return GetSelectedProfile().bindTypes.unbound end,
        function(v) GetSelectedProfile().bindTypes.unbound = v end, true)

    AddSep()

    -- ==================================================
    -- ITEM SOURCE FILTERS
    -- ==================================================
    AddHeader("|cFFFFD100Item Source Filters|r  |cFF888888(this expansion profile)|r",
        "Filter by content type. 'Enable Source Filtering' must be ON to use.")
    SetTooltipScope("profile")

    CreateCheckbox(content, "Enable Source Filtering",
        "When ON, only items from checked sources below are sold.",
        function() return GetSelectedProfile().filterBySource end,
        function(v) GetSelectedProfile().filterBySource = v end, true)

    local sourceOrder = { "consumable", "dungeon", "raid", "outdoor", "profession", "vendor", "pvp", "reputation", "housing", "unknown" }
    for _, sourceKey in ipairs(sourceOrder) do
        local source = addon.ITEM_SOURCES[sourceKey]
        if source then
            CreateCheckbox2Col(content, source.name, "Include: " .. source.name,
                function() return GetSelectedProfile().itemSources[sourceKey] end,
                function(v) GetSelectedProfile().itemSources[sourceKey] = v end, true)
        end
    end
    Flush2Col()

    AddSep()

    -- ==================================================
    -- RARITY FILTERS
    -- ==================================================
    AddHeader("|cFFFFD100Rarity Filters|r  |cFF888888(this expansion profile)|r",
        "Items must match a checked rarity to be sold.")
    SetTooltipScope("profile")

    local rarityOrder = {0, 1, 2, 3, 4, 5, 6, 7}
    for _, rarityID in ipairs(rarityOrder) do
        local rarity = addon.RARITIES[rarityID]
        if rarity then
            local coloredName = string.format("|cFF%s%s|r", rarity.color, rarity.name)
            CreateCheckbox2Col(content, coloredName, "Sell " .. rarity.name .. " quality items.",
                function() return GetSelectedProfile().rarities[rarityID] end,
                function(v) GetSelectedProfile().rarities[rarityID] = v end)
        end
    end
    Flush2Col()

    AddSep()

    -- ==================================================
    -- EQUIPMENT SLOT FILTERS
    -- ==================================================
    AddHeader("|cFFFFD100Equipment Slot Filters|r  |cFF888888(this expansion profile)|r",
        "Equippable items must match a checked slot.")
    SetTooltipScope("profile")

    local slotOrder = {
        "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
        "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND",
        "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
        "INVTYPE_FINGER", "INVTYPE_TRINKET",
        "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
        "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_SHIELD",
        "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
        "INVTYPE_BODY", "INVTYPE_TABARD"
    }
    for _, slotKey in ipairs(slotOrder) do
        local slot = addon.EQUIP_SLOTS[slotKey]
        if slot then
            CreateCheckbox2Col(content, slot.name, "Sell items in " .. slot.name .. " slot.",
                function() return GetSelectedProfile().equipSlots[slotKey] end,
                function(v) GetSelectedProfile().equipSlots[slotKey] = v end)
        end
    end
    Flush2Col()

    AddSep()

    -- ==================================================
    -- ITEM TYPE FILTERS
    -- ==================================================
    AddHeader("|cFFFFD100Non-Equippable Item Types|r  |cFF888888(this expansion profile)|r",
        "Consumables are handled in Item Source Filters to avoid duplicate controls.")
    SetTooltipScope("profile")

    local generalTypeOrder = {1, 12, 13, 15}
    for _, typeID in ipairs(generalTypeOrder) do
        local itemType = addon.ITEM_TYPES[typeID]
        if itemType then
            CreateCheckbox2Col(content, itemType.name, "Sell " .. itemType.name .. ".",
                function() return GetSelectedProfile().itemTypes[typeID] end,
                function(v) GetSelectedProfile().itemTypes[typeID] = v end)
        end
    end
    Flush2Col()

    yOffset = yOffset - 8
    local craftingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    craftingLabel:SetPoint("TOPLEFT", 10, yOffset)
    craftingLabel:SetText("|cFFFFD100Crafting & Profession Items|r  |cFF888888(off by default — protect your mats!)|r")
    yOffset = yOffset - 20

    local craftingTypeOrder = {3, 5, 7, 9}
    for _, typeID in ipairs(craftingTypeOrder) do
        local itemType = addon.ITEM_TYPES[typeID]
        if itemType then
            CreateCheckbox2Col(content, itemType.name, "Sell " .. itemType.name .. " (off by default).",
                function() return GetSelectedProfile().itemTypes[typeID] end,
                function(v) GetSelectedProfile().itemTypes[typeID] = v end)
        end
    end
    Flush2Col()

    AddSep()

    -- ==================================================
    -- QUICK ACTIONS
    -- ==================================================
    AddHeader("|cFFFFD100Quick Actions|r")

    MakeBtn(10, "Enable All Legacy Expansions", function()
        for i = 0, addon.CURRENT_EXPANSION - 1 do LegacyVendorDB.expansions[i] = true end
        addon.Print("All legacy expansions enabled.")
        RefreshConfigFrame()
    end)
    MakeBtn(214, "Disable All Expansions", function()
        for i = 0, addon.CURRENT_EXPANSION do LegacyVendorDB.expansions[i] = false end
        addon.Print("All expansions disabled.")
        RefreshConfigFrame()
    end)
    yOffset = yOffset - 30

    MakeBtn(10, "All Equip Slots (profile)", function()
        local p = GetSelectedProfile()
        for k in pairs(addon.EQUIP_SLOTS) do p.equipSlots[k] = true end
        addon.Print("All equipment slots enabled.")
        RefreshConfigFrame()
    end)
    MakeBtn(214, "Disable All Slots (profile)", function()
        local p = GetSelectedProfile()
        for k in pairs(addon.EQUIP_SLOTS) do p.equipSlots[k] = false end
        addon.Print("All equipment slots disabled.")
        RefreshConfigFrame()
    end)
    yOffset = yOffset - 30

    MakeBtn(10, "Safe Rarities (G/U/R/E)", function()
        local p = GetSelectedProfile()
        p.rarities[0]=true;  p.rarities[1]=false; p.rarities[2]=true
        p.rarities[3]=true;  p.rarities[4]=true;  p.rarities[5]=false
        p.rarities[6]=false; p.rarities[7]=false
        addon.Print("Safe rarities enabled.")
        RefreshConfigFrame()
    end)
    MakeBtn(214, "Disable All Rarities", function()
        local p = GetSelectedProfile()
        for rarityID in pairs(addon.RARITIES) do p.rarities[rarityID] = false end
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
