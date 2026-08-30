-- LegacyVendor - Filter sharing
-- Turns the current filter set into a short text string and back, so a config can be
-- handed to someone else, posted in a guide, or kept as a backup.
--
-- Deliberately dependency-free and human-readable rather than compressed: these
-- strings are a few hundred characters at worst, and a format a person can eyeball
-- ("E:0,1,2") is far easier to support than an opaque blob when someone reports that
-- an import did not do what they expected.

local addonName, addon = ...

local Share = {}
addon.Share = Share

local PREFIX = "LV1"

-- ==========================================
-- SERIALISE
-- ==========================================

local function KeysOf(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if v == true then out[#out + 1] = tostring(k) end
    end
    table.sort(out)
    return out
end

-- Sum of bytes, folded into 4 hex digits. Not cryptographic - it only needs to catch
-- a string mangled by chat wrapping or a truncated copy/paste.
local function Checksum(text)
    local sum = 0
    for i = 1, #text do
        sum = (sum + text:byte(i) * i) % 65536
    end
    return string.format("%04X", sum)
end

function Share.Export(db)
    db = db or LegacyVendorDB
    if not db then return nil end

    local fields = {}

    fields[#fields + 1] = "M:" .. tostring(db.sellMode or "everything")
    fields[#fields + 1] = "E:" .. table.concat(KeysOf(db.expansions), ",")
    fields[#fields + 1] = "R:" .. table.concat(KeysOf(db.rarities), ",")
    fields[#fields + 1] = "S:" .. table.concat(KeysOf(db.equipSlots), ",")
    fields[#fields + 1] = "T:" .. table.concat(KeysOf(db.itemTypes), ",")
    fields[#fields + 1] = "X:" .. table.concat(KeysOf(db.itemSources), ",")

    -- Booleans that change what sells, packed as a flag list.
    local flags = {}
    if db.sellBoP then flags[#flags + 1] = "bop" end
    if db.sellBoE then flags[#flags + 1] = "boe" end
    if db.sellUnbound then flags[#flags + 1] = "unbound" end
    if db.sellGray then flags[#flags + 1] = "gray" end
    if db.protectUncollected ~= false then flags[#flags + 1] = "protect" end
    if db.strictSeasonalProtection ~= false then flags[#flags + 1] = "strict" end
    if db.onlySellLowerIlvl then flags[#flags + 1] = "lowerilvl" end
    fields[#fields + 1] = "F:" .. table.concat(flags, ",")

    local body = table.concat(fields, ";")
    return PREFIX .. "!" .. Checksum(body) .. "!" .. body
end

-- ==========================================
-- PARSE
-- ==========================================

local function SplitList(text)
    local out = {}
    for token in tostring(text or ""):gmatch("[^,]+") do
        out[#out + 1] = token
    end
    return out
end

-- Returns a settings table, or nil plus a reason the string was rejected.
function Share.Parse(str)
    if type(str) ~= "string" then
        return nil, "That is not a shareable string."
    end

    str = str:gsub("%s+", "")
    if str == "" then
        return nil, "Nothing was pasted."
    end

    local prefix, sum, body = str:match("^(%w+)!(%w+)!(.*)$")
    if not prefix then
        return nil, "That does not look like a LegacyVendor string."
    end
    if prefix ~= PREFIX then
        return nil, "That string is from a different version of LegacyVendor."
    end
    if Checksum(body) ~= sum then
        return nil, "That string looks incomplete - copy the whole thing and try again."
    end

    local parsed = { expansions = {}, rarities = {}, equipSlots = {},
                     itemTypes = {}, itemSources = {}, flags = {} }

    for field in body:gmatch("[^;]+") do
        local key, value = field:match("^(%a):(.*)$")
        if key == "M" then
            parsed.sellMode = (value == "matching") and "matching" or "everything"
        elseif key == "E" then
            for _, v in ipairs(SplitList(value)) do parsed.expansions[tonumber(v)] = true end
        elseif key == "R" then
            for _, v in ipairs(SplitList(value)) do parsed.rarities[tonumber(v)] = true end
        elseif key == "S" then
            for _, v in ipairs(SplitList(value)) do parsed.equipSlots[v] = true end
        elseif key == "T" then
            for _, v in ipairs(SplitList(value)) do parsed.itemTypes[tonumber(v)] = true end
        elseif key == "X" then
            for _, v in ipairs(SplitList(value)) do parsed.itemSources[v] = true end
        elseif key == "F" then
            for _, v in ipairs(SplitList(value)) do parsed.flags[v] = true end
        end
    end

    return parsed
end

-- Applies a parsed config. Every group is written wholesale rather than merged, so
-- an imported string produces the same behaviour it produced for whoever shared it -
-- a partial merge would silently leave the importer's own leftovers in place.
function Share.Apply(parsed)
    local db = LegacyVendorDB
    if not (db and parsed) then return false end

    db.sellMode = parsed.sellMode or db.sellMode

    db.expansions = {}
    for id in pairs(parsed.expansions) do db.expansions[id] = true end

    db.rarities = {}
    for id = 0, 7 do db.rarities[id] = parsed.rarities[id] and true or false end

    db.equipSlots = {}
    for key in pairs(addon.EQUIP_SLOTS) do db.equipSlots[key] = parsed.equipSlots[key] and true or false end

    db.itemTypes = {}
    for id in pairs(addon.ITEM_TYPES) do db.itemTypes[id] = parsed.itemTypes[id] and true or false end

    db.itemSources = {}
    for key in pairs(parsed.itemSources) do db.itemSources[key] = true end

    local f = parsed.flags
    db.sellBoP = f.bop and true or false
    db.sellBoE = f.boe and true or false
    db.sellUnbound = f.unbound and true or false
    db.sellGray = f.gray and true or false
    db.onlySellLowerIlvl = f.lowerilvl and true or false

    -- Safety guards are always ON after an import, regardless of what the string
    -- says. A config someone pasted from the internet should never be able to switch
    -- off the protection that stops an uncollected appearance being vendored; the
    -- importer can still turn it off themselves, deliberately, in Settings.
    db.protectUncollected = true
    db.strictSeasonalProtection = true

    if addon.InvalidateSellableCache then addon.InvalidateSellableCache() end
    return true
end

-- ==========================================
-- UI
-- ==========================================

function Share.Open(mode)
    if not Share.frame then
        local f = CreateFrame("Frame", "LegacyVendorShare", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(560, 300)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", f.TitleBg or f, "TOP", 0, -4)

        f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.hint:SetPoint("TOPLEFT", 14, -32)
        f.hint:SetPoint("TOPRIGHT", -14, -32)
        f.hint:SetJustifyH("LEFT")
        f.hint:SetWordWrap(true)
        f.hint:SetTextColor(0.65, 0.65, 0.68)

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 14, -70)
        sf:SetPoint("BOTTOMRIGHT", -34, 46)

        local edit = CreateFrame("EditBox", nil, sf)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(500)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        sf:SetScrollChild(edit)
        f.edit = edit

        f.action = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.action:SetSize(150, 24)
        f.action:SetPoint("BOTTOMRIGHT", -16, 12)

        f.status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.status:SetPoint("BOTTOMLEFT", 16, 18)
        f.status:SetPoint("RIGHT", f.action, "LEFT", -10, 0)
        f.status:SetJustifyH("LEFT")

        Share.frame = f
    end

    local f = Share.frame
    f.status:SetText("")

    if mode == "import" then
        f.title:SetText("Import Filter Settings")
        f.hint:SetText("Paste a LegacyVendor string below and press Import. This replaces your "
            .. "current filters, so export your own first if you want to keep them.")
        f.edit:SetText("")
        f.action:SetText("Import")
        f.action:SetScript("OnClick", function()
            local parsed, err = Share.Parse(f.edit:GetText())
            if not parsed then
                f.status:SetText("|cFFFF6666" .. (err or "Could not read that string.") .. "|r")
                return
            end
            Share.Apply(parsed)
            f.status:SetText("|cFF44FF44Imported.|r")
            if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
                addon.UpdateMerchantButton()
            end
            if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
            addon.Print("Filters imported: " .. (addon.BuildFilterSentence and addon.BuildFilterSentence(LegacyVendorDB) or ""))
            if addon.RefreshConfig and addon.configFrame and addon.configFrame:IsShown() then
                addon.RefreshConfig()
            end
        end)
    else
        f.title:SetText("Export Filter Settings")
        f.hint:SetText("Copy this string with Ctrl+C and share it. Whoever imports it gets the "
            .. "same filters you are using now.")
        f.edit:SetText(Share.Export(LegacyVendorDB) or "")
        f.edit:HighlightText()
        f.edit:SetFocus()
        f.action:SetText("Close")
        f.action:SetScript("OnClick", function() f:Hide() end)
    end

    f:Show()
end
