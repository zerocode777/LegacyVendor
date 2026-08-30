-- LegacyVendor - Named filter profiles
-- A leveling alt and a main doing transmog runs want different rules, and swapping
-- them by hand means re-ticking a dozen filters every time.
--
-- Profiles are stored as the same strings ConfigShare produces, rather than as a
-- second parallel copy of the settings schema. That reuses code already exercised by
-- export/import, means a profile can be shared verbatim, and leaves exactly one
-- place to update whenever a new filter is added.

local addonName, addon = ...

local Profiles = {}
addon.Profiles = Profiles

local ROW_HEIGHT = 28

local function Store()
    LegacyVendorDB.profiles = LegacyVendorDB.profiles or {}
    return LegacyVendorDB.profiles
end

-- Identifies the current character for auto-switching.
local function CharacterKey()
    local name = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or "?"
    return name .. "-" .. realm
end
Profiles.CharacterKey = CharacterKey

function Profiles.List()
    local names = {}
    for name in pairs(Store()) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function Profiles.Save(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        addon.Print("Give the profile a name first.")
        return false
    end
    if not addon.Share then return false end

    Store()[name] = {
        config = addon.Share.Export(LegacyVendorDB),
        saved = time and time() or nil,
    }
    LegacyVendorDB.activeProfile = name
    addon.Print(("Saved profile \"%s\"."):format(name))
    return true
end

function Profiles.Load(name, quiet)
    local entry = Store()[name]
    if not entry or not entry.config then
        if not quiet then addon.Print(("No profile called \"%s\"."):format(tostring(name))) end
        return false
    end

    local parsed, err = addon.Share.Parse(entry.config)
    if not parsed then
        addon.Print(("Profile \"%s\" could not be read: %s"):format(name, err or "unknown"))
        return false
    end

    addon.Share.Apply(parsed)
    LegacyVendorDB.activeProfile = name

    if addon.UpdateMerchantButton and MerchantFrame and MerchantFrame:IsShown() then
        addon.UpdateMerchantButton()
    end
    if addon.ScheduleHighlightUpdate then addon.ScheduleHighlightUpdate() end
    if addon.RefreshConfig and addon.configFrame and addon.configFrame:IsShown() then
        addon.RefreshConfig()
    end

    if not quiet then
        addon.Print(("Loaded \"%s\": %s"):format(name,
            addon.BuildFilterSentence and addon.BuildFilterSentence(LegacyVendorDB) or ""))
    end
    return true
end

function Profiles.Delete(name)
    if not Store()[name] then return false end
    Store()[name] = nil

    -- Drop any character bindings that pointed at it, so a deleted profile cannot
    -- leave a character trying to load something that no longer exists.
    for charKey, bound in pairs(LegacyVendorDB.charProfiles or {}) do
        if bound == name then LegacyVendorDB.charProfiles[charKey] = nil end
    end

    if LegacyVendorDB.activeProfile == name then
        LegacyVendorDB.activeProfile = nil
    end
    addon.Print(("Deleted profile \"%s\"."):format(name))
    return true
end

-- Called once at login: if this character is bound to a profile, apply it.
function Profiles.ApplyForCharacter()
    local bound = (LegacyVendorDB.charProfiles or {})[CharacterKey()]
    if not bound then return end
    if Profiles.Load(bound, true) then
        addon.Print(("Using profile \"%s\" on this character."):format(bound))
    end
end

function Profiles.BindCharacter(name)
    LegacyVendorDB.charProfiles = LegacyVendorDB.charProfiles or {}
    local key = CharacterKey()
    if name then
        LegacyVendorDB.charProfiles[key] = name
        addon.Print(("%s will use \"%s\" from now on."):format(key, name))
    else
        LegacyVendorDB.charProfiles[key] = nil
        addon.Print(("%s no longer loads a profile automatically."):format(key))
    end
end

-- ==========================================
-- UI
-- ==========================================

function Profiles.Open()
    if not Profiles.frame then
        local f = CreateFrame("Frame", "LegacyVendorProfiles", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(440, 380)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", f.TitleBg or f, "TOP", 0, -4)
        f.title:SetText("Filter Profiles")

        f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.hint:SetPoint("TOPLEFT", 14, -32)
        f.hint:SetPoint("TOPRIGHT", -14, -32)
        f.hint:SetJustifyH("LEFT")
        f.hint:SetWordWrap(true)
        f.hint:SetTextColor(0.65, 0.65, 0.68)
        f.hint:SetText("Save your current filters under a name, then switch between them. "
            .. "Star a profile to load it automatically on this character.")

        -- Save-as row
        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetSize(240, 22)
        box:SetPoint("TOPLEFT", 18, -74)
        box:SetAutoFocus(false)
        box:SetMaxLetters(40)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        f.box = box

        local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        saveBtn:SetSize(120, 24)
        saveBtn:SetPoint("LEFT", box, "RIGHT", 10, 0)
        saveBtn:SetText("Save current")
        saveBtn:SetScript("OnClick", function()
            if Profiles.Save(box:GetText()) then
                box:SetText("")
                box:ClearFocus()
                Profiles.Refresh()
            end
        end)

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -106)
        scroll:SetPoint("BOTTOMRIGHT", -32, 16)

        local list = CreateFrame("Frame", nil, scroll)
        list:SetSize(380, ROW_HEIGHT * 8)
        scroll:SetScrollChild(list)
        f.list = list

        f.empty = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.empty:SetPoint("TOPLEFT", 6, -8)
        f.empty:SetTextColor(0.55, 0.55, 0.58)
        f.empty:SetText("No profiles saved yet.")

        f.rows = {}
        Profiles.frame = f
    end

    Profiles.Refresh()
    Profiles.frame:Show()
end

local function AcquireRow(index)
    local f = Profiles.frame
    if f.rows[index] then return f.rows[index] end

    local row = CreateFrame("Frame", nil, f.list)
    row:SetHeight(ROW_HEIGHT - 3)
    row:SetPoint("TOPLEFT", f.list, "TOPLEFT", 2, -((index - 1) * ROW_HEIGHT) - 2)
    row:SetPoint("TOPRIGHT", f.list, "TOPRIGHT", -2, -((index - 1) * ROW_HEIGHT) - 2)

    row.Star = CreateFrame("Button", nil, row)
    row.Star:SetSize(20, 20)
    row.Star:SetPoint("LEFT", 2, 0)
    row.Star.tex = row.Star:CreateTexture(nil, "ARTWORK")
    row.Star.tex:SetAllPoints()
    row.Star.tex:SetTexture("Interface\\COMMON\\FavoritesIcon")

    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Text:SetPoint("LEFT", 26, 0)
    row.Text:SetJustifyH("LEFT")

    row.Load = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Load:SetSize(60, 20)
    row.Load:SetPoint("RIGHT", -70, 0)
    row.Load:SetText("Load")

    row.Del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Del:SetSize(60, 20)
    row.Del:SetPoint("RIGHT", -4, 0)
    row.Del:SetText("Delete")

    f.rows[index] = row
    return row
end

function Profiles.Refresh()
    local f = Profiles.frame
    if not f then return end

    local names = Profiles.List()
    local boundName = (LegacyVendorDB.charProfiles or {})[CharacterKey()]

    f.empty:SetShown(#names == 0)
    f.list:SetHeight(math.max(ROW_HEIGHT * 8, ROW_HEIGHT * #names))

    for i, row in ipairs(f.rows) do
        if i > #names then row:Hide() end
    end

    for i, name in ipairs(names) do
        local row = AcquireRow(i)
        local isActive = (LegacyVendorDB.activeProfile == name)
        local isBound = (boundName == name)

        row.Text:SetText(isActive and ("|cFFFFD100" .. name .. "|r  |cFF888888(in use)|r") or name)
        row.Star.tex:SetDesaturated(not isBound)
        row.Star.tex:SetAlpha(isBound and 1 or 0.35)

        row.Star:SetScript("OnClick", function()
            Profiles.BindCharacter(isBound and nil or name)
            Profiles.Refresh()
        end)
        row.Star:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(isBound and "Loaded automatically here" or "Load this on this character")
            GameTooltip:AddLine(CharacterKey(), 1, 1, 1)
            GameTooltip:Show()
        end)
        row.Star:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.Load:SetScript("OnClick", function()
            Profiles.Load(name)
            Profiles.Refresh()
        end)

        row.Del:SetScript("OnClick", function()
            StaticPopupDialogs["LEGACYVENDOR_DEL_PROFILE"] = {
                text = ("Delete the profile \"%s\"?"):format(name),
                button1 = YES or "Yes", button2 = NO or "No",
                OnAccept = function()
                    Profiles.Delete(name)
                    Profiles.Refresh()
                end,
                timeout = 0, whileDead = false, hideOnEscape = true, preferredIndex = 3,
            }
            StaticPopup_Show("LEGACYVENDOR_DEL_PROFILE")
        end)

        row:Show()
    end
end
