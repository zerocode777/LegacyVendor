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
    -- EXPANSION FILTERS
    -- ==========================================
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Expansion Filters"))
    
    -- Get max expansion for this version
    local maxExpansion = addon.MAX_EXPANSION or addon.CURRENT_EXPANSION
    local currentExpansion = addon.CURRENT_EXPANSION
    
    -- Create toggles for each expansion (only show expansions that exist in this WoW version)
    for i = 0, maxExpansion do
        local exp = addon.EXPANSIONS[i]
        if exp then
            local variable = "LegacyVendor_Exp" .. i
            local name = exp.name .. " (" .. exp.short .. ")"
            local tooltip
            
            if i >= currentExpansion then
                tooltip = "Current expansion - selling is disabled for protection."
                name = name .. " |cFFFF0000[Protected]|r"
            else
                tooltip = "Enable selling of Bind on Pickup items from " .. exp.name .. "."
            end
            
            local setting = Settings.RegisterProxySetting(category, variable,
                Settings.VarType.Boolean, name, LegacyVendorDB.expansions[i],
                function() return LegacyVendorDB.expansions[i] end,
                function(value)
                    -- Protect current expansion
                    if i >= currentExpansion then
                        LegacyVendorDB.expansions[i] = false
                        addon.Print("Cannot enable selling for current expansion items.")
                    else
                        LegacyVendorDB.expansions[i] = value
                    end
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
    
    local typeOrder = {0, 1, 5, 7, 9, 12, 13, 15}
    for _, typeID in ipairs(typeOrder) do
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
    
    -- Register the category
    Settings.RegisterAddOnCategory(category)
    
    addon.settingsCategory = category
end

-- Alternative simple frame-based config for compatibility
local function CreateSimpleConfig()
    local configFrame = CreateFrame("Frame", "LegacyVendorConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(450, 600)
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
    
    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", configFrame.Inset, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame.Inset, "BOTTOMRIGHT", -25, 5)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(400, 1800)  -- Taller to accommodate all filters
    scrollFrame:SetScrollChild(content)
    
    local yOffset = -10
    
    -- Helper function to create checkboxes
    local function CreateCheckbox(parent, label, tooltip, getValue, setValue, refreshOnChange)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 10, yOffset)
        cb.Text:SetText(label)
        cb.tooltipText = tooltip
        
        cb:SetChecked(getValue())
        cb:SetScript("OnClick", function(self)
            setValue(self:GetChecked())
            if refreshOnChange then
                RefreshButton()
            end
        end)
        
        yOffset = yOffset - 30
        return cb
    end
    
    -- General Settings Header
    local header1 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header1:SetPoint("TOPLEFT", 10, yOffset)
    header1:SetText("General Settings")
    yOffset = yOffset - 25
    
    -- Enable checkbox
    CreateCheckbox(content, "Enable LegacyVendor", "Enable or disable automatic selling",
        function() return LegacyVendorDB.enabled end,
        function(v) LegacyVendorDB.enabled = v end,
        true)
    
    -- Auto-sell checkbox
    CreateCheckbox(content, "Auto-Sell Mode (may not work with API restrictions)", 
        "When OFF: Click [Sell Legacy] button at vendors (recommended). When ON: Auto-sell when opening vendor.",
        function() return LegacyVendorDB.autoSell end,
        function(v) LegacyVendorDB.autoSell = v end)
    
    -- Show summary checkbox
    CreateCheckbox(content, "Show Sale Summary", "Display summary after selling",
        function() return LegacyVendorDB.showSummary end,
        function(v) LegacyVendorDB.showSummary = v end)
    
    -- Confirm checkbox
    CreateCheckbox(content, "Confirm Before Selling", "Show confirmation dialog",
        function() return LegacyVendorDB.confirmSell end,
        function(v) LegacyVendorDB.confirmSell = v end)
    
    -- Sell gray checkbox
    CreateCheckbox(content, "Also Sell Gray Items", "Sell all gray items automatically",
        function() return LegacyVendorDB.sellGray end,
        function(v) LegacyVendorDB.sellGray = v end)
    
    -- Debug checkbox
    CreateCheckbox(content, "Debug Mode", "Show debug messages in chat",
        function() return LegacyVendorDB.debug end,
        function(v) LegacyVendorDB.debug = v end)
    
    yOffset = yOffset - 20
    
    -- ==========================================
    -- BIND TYPE FILTERS
    -- ==========================================
    local headerBind = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerBind:SetPoint("TOPLEFT", 10, yOffset)
    headerBind:SetText("|cFFFFD100Bind Type Filters|r")
    yOffset = yOffset - 5
    
    local bindNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bindNote:SetPoint("TOPLEFT", 10, yOffset)
    bindNote:SetText("|cFF888888Which binding types to include|r")
    yOffset = yOffset - 20
    
    CreateCheckbox(content, "Sell Bind on Pickup (Soulbound)", "Sell BoP items",
        function() return LegacyVendorDB.sellBoP end,
        function(v) LegacyVendorDB.sellBoP = v end,
        true)
    
    CreateCheckbox(content, "Sell Bind on Equip (Bound)", "Sell BoE items you've equipped. Careful with transmog!",
        function() return LegacyVendorDB.sellBoE end,
        function(v) LegacyVendorDB.sellBoE = v end,
        true)
    
    CreateCheckbox(content, "Sell Not Bound (Food, Reagents)", "Sell unbound items like food, potions, reagents",
        function() return LegacyVendorDB.sellUnbound end,
        function(v) LegacyVendorDB.sellUnbound = v end,
        true)
    
    yOffset = yOffset - 20
    
    -- ==========================================
    -- EXPANSION FILTERS
    -- ==========================================
    local header2 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header2:SetPoint("TOPLEFT", 10, yOffset)
    header2:SetText("|cFFFFD100Expansion Filters|r (Check to SELL)")
    yOffset = yOffset - 5
    
    local expNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expNote:SetPoint("TOPLEFT", 10, yOffset)
    expNote:SetText("|cFF888888Items must be from a checked expansion|r")
    yOffset = yOffset - 20
    
    -- Get max expansion for this WoW version
    local maxExpansion = addon.MAX_EXPANSION or addon.CURRENT_EXPANSION
    local currentExpansion = addon.CURRENT_EXPANSION
    
    -- Create expansion checkboxes (only show expansions that exist in this WoW version)
    for i = 0, maxExpansion do
        local exp = addon.EXPANSIONS[i]
        if exp then
            local label = exp.name
            local isProtected = i >= currentExpansion
            
            if isProtected then
                label = label .. " |cFFFF0000[Protected]|r"
            end
            
            local cb = CreateCheckbox(content, label, 
                isProtected and "Current expansion items are protected" or "Sell BoP items from " .. exp.name,
                function() return LegacyVendorDB.expansions[i] end,
                function(v)
                    if isProtected then
                        LegacyVendorDB.expansions[i] = false
                    else
                        LegacyVendorDB.expansions[i] = v
                    end
                end)
            
            if isProtected then
                cb:Disable()
            end
        end
    end
    
    yOffset = yOffset - 20
    
    -- ==========================================
    -- RARITY FILTERS
    -- ==========================================
    local header3 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header3:SetPoint("TOPLEFT", 10, yOffset)
    header3:SetText("|cFFFFD100Rarity Filters|r (Check to SELL)")
    yOffset = yOffset - 5
    
    local rarityNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rarityNote:SetPoint("TOPLEFT", 10, yOffset)
    rarityNote:SetText("|cFF888888Items must be of a checked rarity|r")
    yOffset = yOffset - 20
    
    -- Sort rarities by ID
    local rarityOrder = {0, 1, 2, 3, 4, 5, 6, 7}
    for _, rarityID in ipairs(rarityOrder) do
        local rarity = addon.RARITIES[rarityID]
        if rarity then
            local coloredName = string.format("|cFF%s%s|r", rarity.color, rarity.name)
            CreateCheckbox(content, coloredName, "Sell items of " .. rarity.name .. " quality",
                function() return LegacyVendorDB.rarities[rarityID] end,
                function(v) LegacyVendorDB.rarities[rarityID] = v end)
        end
    end
    
    yOffset = yOffset - 20
    
    -- ==========================================
    -- EQUIPMENT SLOT FILTERS
    -- ==========================================
    local header4 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header4:SetPoint("TOPLEFT", 10, yOffset)
    header4:SetText("|cFFFFD100Equipment Slot Filters|r (Check to SELL)")
    yOffset = yOffset - 5
    
    local slotNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotNote:SetPoint("TOPLEFT", 10, yOffset)
    slotNote:SetText("|cFF888888Equippable items must be in a checked slot|r")
    yOffset = yOffset - 20
    
    -- Group equipment slots logically
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
            CreateCheckbox(content, slot.name, "Sell equipment in " .. slot.name .. " slot",
                function() return LegacyVendorDB.equipSlots[slotKey] end,
                function(v) LegacyVendorDB.equipSlots[slotKey] = v end)
        end
    end
    
    yOffset = yOffset - 20
    
    -- ==========================================
    -- ITEM TYPE FILTERS (Non-Equippable)
    -- ==========================================
    local header5 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header5:SetPoint("TOPLEFT", 10, yOffset)
    header5:SetText("|cFFFFD100Non-Equippable Item Types|r (Check to SELL)")
    yOffset = yOffset - 5
    
    local typeNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeNote:SetPoint("TOPLEFT", 10, yOffset)
    typeNote:SetText("|cFF888888Non-equippable items must be of a checked type|r")
    yOffset = yOffset - 20
    
    -- Sort item types by ID
    local typeOrder = {0, 1, 5, 7, 9, 12, 13, 15}
    for _, typeID in ipairs(typeOrder) do
        local itemType = addon.ITEM_TYPES[typeID]
        if itemType then
            CreateCheckbox(content, itemType.name, "Sell " .. itemType.name,
                function() return LegacyVendorDB.itemTypes[typeID] end,
                function(v) LegacyVendorDB.itemTypes[typeID] = v end)
        end
    end
    
    yOffset = yOffset - 30
    
    -- ==========================================
    -- QUICK ACTIONS
    -- ==========================================
    local header6 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header6:SetPoint("TOPLEFT", 10, yOffset)
    header6:SetText("|cFFFFD100Quick Actions|r")
    yOffset = yOffset - 30
    
    -- Enable All Legacy Expansions button
    local enableAllExpBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    enableAllExpBtn:SetPoint("TOPLEFT", 10, yOffset)
    enableAllExpBtn:SetSize(170, 25)
    enableAllExpBtn:SetText("All Legacy Expansions")
    enableAllExpBtn:SetScript("OnClick", function()
        for i = 0, addon.CURRENT_EXPANSION - 1 do
            LegacyVendorDB.expansions[i] = true
        end
        addon.Print("All legacy expansions enabled for selling.")
        configFrame:Hide()
        configFrame:Show() -- Refresh
    end)
    
    -- Disable All Expansions button
    local disableAllExpBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    disableAllExpBtn:SetPoint("LEFT", enableAllExpBtn, "RIGHT", 10, 0)
    disableAllExpBtn:SetSize(170, 25)
    disableAllExpBtn:SetText("Disable All Expansions")
    disableAllExpBtn:SetScript("OnClick", function()
        for i = 0, addon.CURRENT_EXPANSION do
            LegacyVendorDB.expansions[i] = false
        end
        addon.Print("All expansions disabled.")
        configFrame:Hide()
        configFrame:Show() -- Refresh
    end)
    
    yOffset = yOffset - 30
    
    -- Enable All Slots button
    local enableAllSlotsBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    enableAllSlotsBtn:SetPoint("TOPLEFT", 10, yOffset)
    enableAllSlotsBtn:SetSize(170, 25)
    enableAllSlotsBtn:SetText("All Equipment Slots")
    enableAllSlotsBtn:SetScript("OnClick", function()
        for slotKey, _ in pairs(addon.EQUIP_SLOTS) do
            LegacyVendorDB.equipSlots[slotKey] = true
        end
        addon.Print("All equipment slots enabled for selling.")
        configFrame:Hide()
        configFrame:Show()
    end)
    
    -- Disable All Slots button
    local disableAllSlotsBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    disableAllSlotsBtn:SetPoint("LEFT", enableAllSlotsBtn, "RIGHT", 10, 0)
    disableAllSlotsBtn:SetSize(170, 25)
    disableAllSlotsBtn:SetText("Disable All Slots")
    disableAllSlotsBtn:SetScript("OnClick", function()
        for slotKey, _ in pairs(addon.EQUIP_SLOTS) do
            LegacyVendorDB.equipSlots[slotKey] = false
        end
        addon.Print("All equipment slots disabled.")
        configFrame:Hide()
        configFrame:Show()
    end)
    
    yOffset = yOffset - 30
    
    -- Enable All Rarities (safe ones) button
    local enableAllRarityBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    enableAllRarityBtn:SetPoint("TOPLEFT", 10, yOffset)
    enableAllRarityBtn:SetSize(170, 25)
    enableAllRarityBtn:SetText("Safe Rarities (G/U/R/E)")
    enableAllRarityBtn:SetScript("OnClick", function()
        LegacyVendorDB.rarities[0] = true  -- Gray
        LegacyVendorDB.rarities[1] = false -- White (keep)
        LegacyVendorDB.rarities[2] = true  -- Green
        LegacyVendorDB.rarities[3] = true  -- Blue
        LegacyVendorDB.rarities[4] = true  -- Epic
        LegacyVendorDB.rarities[5] = false -- Legendary (keep)
        LegacyVendorDB.rarities[6] = false -- Artifact (keep)
        LegacyVendorDB.rarities[7] = false -- Heirloom (keep)
        addon.Print("Safe rarities (Gray, Green, Blue, Epic) enabled.")
        configFrame:Hide()
        configFrame:Show()
    end)
    
    -- Disable All Rarities button
    local disableAllRarityBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    disableAllRarityBtn:SetPoint("LEFT", enableAllRarityBtn, "RIGHT", 10, 0)
    disableAllRarityBtn:SetSize(170, 25)
    disableAllRarityBtn:SetText("Disable All Rarities")
    disableAllRarityBtn:SetScript("OnClick", function()
        for rarityID, _ in pairs(addon.RARITIES) do
            LegacyVendorDB.rarities[rarityID] = false
        end
        addon.Print("All rarities disabled.")
        configFrame:Hide()
        configFrame:Show()
    end)
    
    yOffset = yOffset - 40
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 10, yOffset)
    resetBtn:SetSize(170, 25)
    resetBtn:SetText("Reset ALL to Defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopupDialogs["LEGACYVENDOR_RESET"] = {
            text = "Are you sure you want to reset ALL LegacyVendor settings to defaults?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                SlashCmdList["LEGACYVENDOR"]("reset")
                configFrame:Hide()
            end,
            timeout = 0,
            whileDead = false,
            hideOnEscape = true,
        }
        StaticPopup_Show("LEGACYVENDOR_RESET")
    end)
    
    -- Update content height based on how many items we added
    content:SetHeight(math.abs(yOffset) + 50)
    
    addon.configFrame = configFrame
    return configFrame
end

-- Open config function
function addon.OpenConfig()
    -- Try modern Settings API first
    if Settings and Settings.OpenToCategory and addon.settingsCategory then
        Settings.OpenToCategory(addon.settingsCategory:GetID())
    else
        -- Fallback to simple config frame
        if not addon.configFrame then
            CreateSimpleConfig()
        end
        if addon.configFrame:IsShown() then
            addon.configFrame:Hide()
        else
            addon.configFrame:Show()
        end
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
