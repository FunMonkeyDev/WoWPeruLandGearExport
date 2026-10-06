local FORMAT_VERSION = "WPL2"

-- IDs de slot de Blizzard (se excluyen Camisa=4 y Tabardo=19, no son "gear")
local SLOT_IDS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

-- Devuelve el indice (1-3) del arbol de talentos con mas puntos invertidos, como aproximacion
-- de la spec activa. No distingue variantes de un mismo arbol (ej. Sangre Dps vs Tanque en DK,
-- Feral Dps vs Tanque en Druida) - eso queda como mejor intento, el usuario puede corregirlo
-- manualmente en la web si hace falta.
local function GetPrimaryTalentTab()
    local bestTab, bestPoints = 1, -1
    for tab = 1, GetNumTalentTabs() do
        local _, _, pointsSpent = GetTalentTabInfo(tab)
        if pointsSpent and pointsSpent > bestPoints then
            bestPoints = pointsSpent
            bestTab = tab
        end
    end
    return bestTab
end

local function BuildExportString()
    local name = UnitName("player")
    local _, classToken = UnitClass("player")
    local level = UnitLevel("player")
    local talentTab = GetPrimaryTalentTab()

    local parts = {}
    for _, slotId in ipairs(SLOT_IDS) do
        local itemId = GetInventoryItemID("player", slotId) or 0
        table.insert(parts, slotId .. "=" .. itemId)
    end

    return string.format(
        "%s;%s;%s;%d;%d;%s",
        FORMAT_VERSION, name, classToken, level, talentTab, table.concat(parts, ",")
    )
end

local exportFrame

local function EnsureFrame()
    if exportFrame then
        return exportFrame
    end

    local f = CreateFrame("Frame", "WowPeruLandGearExportFrame", UIParent)
    f:SetSize(420, 110)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -18)
    title:SetText("WowPeruLand - Exportar equipo")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText("El texto ya está seleccionado, copia con Ctrl+C y pégalo en la web")

    local editBoxBg = CreateFrame("Frame", nil, f)
    editBoxBg:SetPoint("TOP", hint, "BOTTOM", 0, -10)
    editBoxBg:SetSize(380, 24)
    editBoxBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editBoxBg:SetBackdropColor(0, 0, 0, 0.8)

    local editBox = CreateFrame("EditBox", nil, editBoxBg)
    editBox:SetPoint("TOPLEFT", 6, -4)
    editBox:SetPoint("BOTTOMRIGHT", -6, 4)
    editBox:SetAutoFocus(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetScript("OnEscapePressed", function(self)
        f:Hide()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    f.editBox = editBox
    exportFrame = f
    return f
end

SLASH_WPLGEAREXPORT1 = "/gearexport"
SlashCmdList["WPLGEAREXPORT"] = function()
    local exportString = BuildExportString()
    local f = EnsureFrame()
    f.editBox:SetText(exportString)
    f.editBox:SetFocus()
    f.editBox:HighlightText()
    f:Show()
end
