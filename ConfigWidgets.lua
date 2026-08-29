-- LegacyVendor - Reusable configuration widgets
-- Visual building blocks for the settings panel: chips, collapsible sections,
-- icon toggles and the live summary bar. Kept free of any LegacyVendorDB access so
-- these stay presentation-only and reusable.

local addonName, addon = ...

local Widgets = {}
addon.Widgets = Widgets

-- Shared palette. Deliberately muted so the accent (gold) carries emphasis and the
-- quality colours below stay readable against it.
local C = {
    cardBg      = { 0.09, 0.09, 0.11, 0.85 },
    cardBorder  = { 0.25, 0.25, 0.29, 1 },
    chipOff     = { 0.13, 0.13, 0.15, 0.9 },
    chipOffEdge = { 0.32, 0.32, 0.36, 1 },
    chipOn      = { 0.36, 0.28, 0.09, 0.95 },
    chipOnEdge  = { 0.95, 0.78, 0.35, 1 },
    accent      = { 0.95, 0.78, 0.35 },
    good        = { 0.45, 0.85, 0.45 },
    dim         = { 0.62, 0.62, 0.62 },
}
Widgets.Colors = C

-- Applies a flat card look (fill + 1px border) using plain textures, which behaves
-- identically on Retail and Classic - BackdropTemplate has shifted across versions.
function Widgets.ApplyCard(frame, fill, edge)
    fill = fill or C.cardBg
    edge = edge or C.cardBorder

    if not frame._bgTex then
        frame._bgTex = frame:CreateTexture(nil, "BACKGROUND")
        frame._bgTex:SetAllPoints()

        frame._edges = {}
        for i = 1, 4 do
            frame._edges[i] = frame:CreateTexture(nil, "BORDER")
        end
        local t, b, l, r = frame._edges[1], frame._edges[2], frame._edges[3], frame._edges[4]
        t:SetHeight(1); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT")
        b:SetHeight(1); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT")
        l:SetWidth(1);  l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT")
        r:SetWidth(1);  r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT")
    end

    frame._bgTex:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
    for _, e in ipairs(frame._edges) do
        e:SetColorTexture(edge[1], edge[2], edge[3], edge[4] or 1)
    end
end

-- A toggleable pill. `spec` may carry an icon texture or a colour swatch, which is
-- what turns the old flat checkbox lists into something scannable at a glance.
-- spec = { label, icon, color, tooltip, width }
function Widgets.CreateChip(parent, spec, getState, onToggle)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(24)

    local hasArt = spec.icon or spec.color
    local textX = hasArt and 24 or 9

    chip.Icon = nil
    if spec.icon then
        chip.Icon = chip:CreateTexture(nil, "ARTWORK")
        chip.Icon:SetSize(14, 14)
        chip.Icon:SetPoint("LEFT", 6, 0)
        chip.Icon:SetTexture(spec.icon)
        -- Trim the default icon border so it reads as a glyph, not a mini item button.
        chip.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif spec.color then
        chip.Icon = chip:CreateTexture(nil, "ARTWORK")
        chip.Icon:SetSize(10, 10)
        chip.Icon:SetPoint("LEFT", 8, 0)
        chip.Icon:SetColorTexture(spec.color[1], spec.color[2], spec.color[3], 1)
    end

    chip.Text = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chip.Text:SetPoint("LEFT", textX, 0)
    chip.Text:SetText(spec.label or "")

    local textW = chip.Text:GetStringWidth() or 40
    chip:SetWidth(spec.width or (textX + textW + 10))

    function chip:UpdateVisual()
        local on = getState() and true or false
        if on then
            Widgets.ApplyCard(self, C.chipOn, C.chipOnEdge)
            self.Text:SetTextColor(1, 0.93, 0.72)
            if self.Icon then self.Icon:SetAlpha(1) end
        else
            Widgets.ApplyCard(self, C.chipOff, C.chipOffEdge)
            self.Text:SetTextColor(0.55, 0.55, 0.58)
            if self.Icon then self.Icon:SetAlpha(0.45) end
        end
    end

    chip:SetScript("OnClick", function(self)
        onToggle(not getState())
        self:UpdateVisual()
    end)

    chip:SetScript("OnEnter", function(self)
        if not self._bgTex then return end
        self._bgTex:SetColorTexture(0.22, 0.20, 0.14, 0.95)
        if spec.tooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(spec.label or "", 1, 0.82, 0)
            GameTooltip:AddLine(spec.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    chip:SetScript("OnLeave", function(self)
        self:UpdateVisual()
        if GameTooltip then GameTooltip:Hide() end
    end)

    chip:UpdateVisual()
    return chip
end

-- Lays chips out as a wrapped row inside `parent`, starting at yOffset.
-- Returns the new yOffset below the final row.
function Widgets.LayoutChips(parent, chips, yOffset, leftInset, availableWidth, spacing)
    leftInset = leftInset or 12
    spacing = spacing or 5
    availableWidth = availableWidth or (parent:GetWidth() - leftInset - 12)

    local x, rowTop = 0, yOffset
    for _, chip in ipairs(chips) do
        local w = chip:GetWidth()
        if x > 0 and (x + w) > availableWidth then
            x = 0
            rowTop = rowTop - 28
        end
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset + x, rowTop)
        x = x + w + spacing
    end

    return rowTop - 30
end

-- A collapsible titled section. Returns the header button plus a content frame the
-- caller fills; collapsing hides the content and reclaims its height.
function Widgets.CreateSection(parent, title, subtitle, startCollapsed, onToggle)
    local section = CreateFrame("Frame", nil, parent)
    section:SetHeight(24)

    local header = CreateFrame("Button", nil, section)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(24)

    header.Arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.Arrow:SetPoint("LEFT", 6, 0)
    header.Arrow:SetWidth(12)

    header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.Text:SetPoint("LEFT", 20, 0)
    header.Text:SetText(title)
    header.Text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

    if subtitle then
        header.Sub = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.Sub:SetPoint("LEFT", header.Text, "RIGHT", 8, 0)
        header.Sub:SetText(subtitle)
        header.Sub:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    end

    local content = CreateFrame("Frame", nil, section)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    content:SetHeight(1)
    section.Content = content

    section.collapsed = startCollapsed and true or false

    function section:UpdateVisual()
        header.Arrow:SetText(self.collapsed and "|cFF888888>|r" or "|cFFFFD100v|r")
        content:SetShown(not self.collapsed)
    end

    header:SetScript("OnClick", function()
        section.collapsed = not section.collapsed
        section:UpdateVisual()
        if onToggle then onToggle(section.collapsed) end
    end)
    header:SetScript("OnEnter", function(self) self.Text:SetTextColor(1, 1, 1) end)
    header:SetScript("OnLeave", function(self) self.Text:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end)

    section:UpdateVisual()
    return section
end

-- The live "what will actually sell" bar: a plain-English sentence plus a match
-- count, so a setting's effect is visible next to the setting itself.
function Widgets.CreateSummaryBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(52)
    Widgets.ApplyCard(bar, { 0.06, 0.10, 0.06, 0.9 }, { 0.28, 0.42, 0.28, 1 })

    bar.Sentence = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.Sentence:SetPoint("TOPLEFT", 10, -8)
    bar.Sentence:SetPoint("TOPRIGHT", -10, -8)
    bar.Sentence:SetJustifyH("LEFT")
    bar.Sentence:SetWordWrap(true)

    bar.Count = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.Count:SetPoint("BOTTOMLEFT", 10, 8)
    bar.Count:SetJustifyH("LEFT")

    function bar:SetSentence(text)
        self.Sentence:SetText(text or "")
    end

    function bar:SetCount(text, isZero)
        self.Count:SetText(text or "")
        if isZero then
            self.Count:SetTextColor(0.85, 0.6, 0.35)
        else
            self.Count:SetTextColor(C.good[1], C.good[2], C.good[3])
        end
    end

    return bar
end

-- A compact preset button. Presets are the fastest path from "installed" to
-- "configured", which is the step most users never finish.
function Widgets.CreatePresetButton(parent, label, tooltip, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(26)
    Widgets.ApplyCard(btn, { 0.14, 0.14, 0.17, 0.95 }, { 0.38, 0.38, 0.42, 1 })

    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.Text:SetPoint("CENTER")
    btn.Text:SetText(label)

    btn:SetWidth((btn.Text:GetStringWidth() or 60) + 24)

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", function(self)
        Widgets.ApplyCard(self, { 0.26, 0.21, 0.10, 0.95 }, C.chipOnEdge)
        if tooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(label, 1, 0.82, 0)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        Widgets.ApplyCard(self, { 0.14, 0.14, 0.17, 0.95 }, { 0.38, 0.38, 0.42, 1 })
        if GameTooltip then GameTooltip:Hide() end
    end)

    return btn
end
