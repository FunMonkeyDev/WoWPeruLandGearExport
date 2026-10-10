-- /geai: arma un prompt listo para pegar en una IA con lo que llevas puesto y el gear de tus bolsas.
-- /geai2: solo los datos del personaje, para pegarlos en el Gem/GPT que ya tiene las instrucciones
-- (ver GEM_INSTRUCCIONES.md).

-- Contexto del servidor que se incluye en el prompt. Edita este texto cuando abran mas contenido,
-- y tambien en GEM_INSTRUCCIONES.md.
local SERVER_CONTEXT = [[Servidor privado de WoW con cliente 3.3.5a (WotLK) pero con contenido progresivo capado a Vanilla (1.x).
Contenido abierto ahora: Molten Core, Onyxia's Lair, Zul'Gurub y Blackwing Lair (BWL). Los battlegrounds y sus recompensas PvP de Vanilla pueden contar.
No se puede obtener contenido de TBC ni WotLK: no lo sugieras.
Los items Heirloom (reliquia de cuenta) no estan permitidos dentro de raids: no los sugieras ni los cuentes como parte del set de raid, aunque los tenga puestos o en las bolsas.]]

local SLOT_LABELS = {
    [1] = "Cabeza", [2] = "Cuello", [3] = "Hombros", [5] = "Pecho", [6] = "Cintura",
    [7] = "Piernas", [8] = "Pies", [9] = "Muñecas", [10] = "Manos", [11] = "Anillo 1",
    [12] = "Anillo 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Espalda",
    [16] = "Mano principal", [17] = "Mano secundaria", [18] = "A distancia/Reliquia",
}
local SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

-- Tipos de equipo que no son "gear" evaluable (bolsas, carcaj, municion, tabardo, camisa).
local SKIP_EQUIP_LOC = {
    INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true,
    INVTYPE_TABARD = true, INVTYPE_BODY = true,
}

local MAX_TOOLTIP_LINES = 18

local ABBREV_LEGEND = "Formato: Slot: Nombre #ID i<nivel de objeto> req<nivel requerido> | lineas del tooltip separadas por |. "
    .. "Abreviaturas: STR fuerza, AGI agilidad, STA aguante, INT intelecto, SPI espiritu, ARM armadura, AP poder de ataque, "
    .. "RAP poder de ataque a distancia, SP poder con hechizos, MP5 mana cada 5 s, Crit/Hit/Haste/Def/Dodge/Parry/Block indices, "
    .. "BlockVal valor de bloqueo, Eq: efecto al equipar, Ench: encantamiento puesto (ench#id = id del encantamiento), "
    .. "SIN ENCANTAR = slot que admite encantamiento y no tiene."

-- Cadenas globales del cliente (ya traducidas a su idioma) -> abreviatura. Las que no existan se ignoran.
local STAT_ABBREV = {
    ITEM_MOD_STRENGTH = "STR", ITEM_MOD_AGILITY = "AGI", ITEM_MOD_STAMINA = "STA",
    ITEM_MOD_INTELLECT = "INT", ITEM_MOD_SPIRIT = "SPI", ARMOR_TEMPLATE = "ARM",
    ITEM_MOD_ATTACK_POWER = "AP", ITEM_MOD_RANGED_ATTACK_POWER = "RAP", ITEM_MOD_SPELL_POWER = "SP",
    ITEM_MOD_MANA_REGENERATION = "MP5", ITEM_MOD_HEALTH_REGEN = "HP5",
    ITEM_MOD_CRIT_RATING = "Crit", ITEM_MOD_HIT_RATING = "Hit", ITEM_MOD_HASTE_RATING = "Haste",
    ITEM_MOD_CRIT_SPELL_RATING = "SpellCrit", ITEM_MOD_HIT_SPELL_RATING = "SpellHit",
    ITEM_MOD_CRIT_MELEE_RATING = "MeleeCrit", ITEM_MOD_HIT_MELEE_RATING = "MeleeHit",
    ITEM_MOD_CRIT_RANGED_RATING = "RangedCrit", ITEM_MOD_HIT_RANGED_RATING = "RangedHit",
    ITEM_MOD_DEFENSE_SKILL_RATING = "Def", ITEM_MOD_DODGE_RATING = "Dodge", ITEM_MOD_PARRY_RATING = "Parry",
    ITEM_MOD_BLOCK_RATING = "Block", ITEM_MOD_BLOCK_VALUE = "BlockVal", SHIELD_BLOCK_TEMPLATE = "BlockVal",
    ITEM_MOD_EXPERTISE_RATING = "Exp", ITEM_MOD_ARMOR_PENETRATION_RATING = "ArP",
    ITEM_MOD_SPELL_PENETRATION = "SpellPen", ITEM_MOD_RESILIENCE_RATING = "Resil",
}

-- Convierte una cadena de formato ("%c%d Fuerza", "Mejora ... %d.") en un patron Lua con capturas (signo, numero).
local function FormatToPattern(fmt)
    fmt = fmt:gsub("%%%d*%$?c", "\1"):gsub("%%%d*%$?d", "\2"):gsub("%%%d*%$?s", "\3")
    fmt = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    fmt = fmt:gsub("\1", "([+-]?)"):gsub("\2", "(%%d+)"):gsub("\3", ".-")
    return "^" .. fmt .. "$"
end

local STAT_PATTERNS = {}
for globalName, abbrev in pairs(STAT_ABBREV) do
    local fmt = _G[globalName]
    if type(fmt) == "string" and fmt:find("%%") then
        table.insert(STAT_PATTERNS, { pattern = FormatToPattern(fmt), abbrev = abbrev })
    end
end

-- Lineas que no aportan al analisis: durabilidad, precio de venta y nivel requerido (ya va en la cabecera).
local DROP_PATTERNS = {}
for _, globalName in ipairs({ "DURABILITY_TEMPLATE", "ITEM_MIN_LEVEL" }) do
    if type(_G[globalName]) == "string" then
        table.insert(DROP_PATTERNS, FormatToPattern(_G[globalName]))
    end
end

local EQUIP_PREFIX = (ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:") .. " "
-- "Encantado: %s" -> "Encantado: ". Puede no existir en el cliente; entonces el encantamiento queda como texto normal.
local ENCHANT_PREFIX = type(ENCHANTED_TOOLTIP_LINE) == "string" and ENCHANTED_TOOLTIP_LINE:match("^(.-)%%s") or nil
if ENCHANT_PREFIX == "" then
    ENCHANT_PREFIX = nil
end

-- Slots que en Vanilla admiten encantamiento (o libram/arcanum/hombrera de reputacion/mira).
local ENCHANTABLE_SLOTS = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [9] = true,
    [10] = true, [15] = true, [16] = true, [17] = true, [18] = true }
local NOT_ENCHANTABLE_EQUIP_LOC = { INVTYPE_HOLDABLE = true, INVTYPE_RELIC = true, INVTYPE_THROWN = true }

local scanTip = CreateFrame("GameTooltip", "WPLGeaiScanTip", nil, "GameTooltipTemplate")

local function CleanText(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return strtrim(text)
end

local function IsDropped(text)
    if text:match('^".*"$') or text:match("^«.*»$") then
        return true -- texto decorativo
    end
    if SELL_PRICE and text:sub(1, #SELL_PRICE) == SELL_PRICE then
        return true
    end
    for _, pattern in ipairs(DROP_PATTERNS) do
        if text:match(pattern) then
            return true
        end
    end
    return false
end

-- "+18 Fuerza" -> "STR18", "Equipar: Mejora el indice de golpe critico 14." -> "Crit14". Lo demas queda como texto.
local function Abbreviate(text)
    if ENCHANT_PREFIX and text:sub(1, #ENCHANT_PREFIX) == ENCHANT_PREFIX then
        return "Ench: " .. strtrim(text:sub(#ENCHANT_PREFIX + 1))
    end
    local body = text
    local isEquip = text:sub(1, #EQUIP_PREFIX) == EQUIP_PREFIX
    if isEquip then
        body = text:sub(#EQUIP_PREFIX + 1)
    end
    for _, stat in ipairs(STAT_PATTERNS) do
        local sign, value = body:match(stat.pattern)
        if not sign then
            sign, value = text:match(stat.pattern) -- por si la cadena global ya trae el prefijo "Equipar:"
        end
        if value then
            return stat.abbrev .. (sign == "-" and "-" or "") .. value
        elseif sign and sign:match("^%d+$") then
            return stat.abbrev .. sign -- formato sin %c: la primera captura ya es el numero
        end
    end
    if isEquip then
        return "Eq: " .. body
    end
    return text
end

local function IsRed(fontString)
    local r, g, b = fontString:GetTextColor()
    return r and r > 0.9 and g < 0.2 and b < 0.2
end

-- Lineas del tooltip del item (sin el nombre) ya abreviadas, y si el personaje no puede usarlo (texto en rojo,
-- sin contar el nivel requerido para no descartar items que podra usar al subir).
local function TooltipLines(link)
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)

    local lines, unusable = {}, false
    for i = 2, scanTip:NumLines() do
        local left = _G["WPLGeaiScanTipTextLeft" .. i]
        local right = _G["WPLGeaiScanTipTextRight" .. i]
        local leftText = left and left:GetText()
        local rightText = right and right:IsShown() and right:GetText()
        if leftText and leftText ~= "" then
            local text = CleanText(leftText)
            if rightText and rightText ~= "" then
                text = text .. " " .. CleanText(rightText)
            end
            if not IsDropped(text) then
                if IsRed(left) or (rightText and IsRed(right)) then
                    unusable = true
                end
                if #lines < MAX_TOOLTIP_LINES then
                    table.insert(lines, Abbreviate(text))
                end
            end
        end
    end
    return lines, unusable
end

-- Una linea por item. Con skipUnusable no escribe nada si el personaje no puede equiparlo.
-- Con checkEnchant (equipo puesto) marca el encantamiento: "ench#<id>" o "SIN ENCANTAR".
local function DescribeItem(link, label, out, skipUnusable, checkEnchant)
    local lines, unusable = TooltipLines(link)
    if skipUnusable and unusable then
        return false
    end
    local name, _, _, itemLevel, reqLevel, _, _, _, equipLoc = GetItemInfo(link)
    local itemId = link:match("item:(%d+)") or "?"
    local text = string.format("%s: %s #%s i%s req%s", label, name or "?", itemId,
        tostring(itemLevel or "?"), tostring(reqLevel or "?"))
    if checkEnchant and not NOT_ENCHANTABLE_EQUIP_LOC[equipLoc] then
        local enchantId = tonumber(link:match("item:%d+:(%d+)") or 0) or 0
        text = text .. (enchantId > 0 and (" ench#" .. enchantId) or " SIN ENCANTAR")
    end
    if #lines > 0 then
        text = text .. " | " .. table.concat(lines, " | ")
    end
    table.insert(out, text)
    return true
end

local function TalentSummary()
    local parts = {}
    for tab = 1, GetNumTalentTabs() do
        local tabName, _, pointsSpent = GetTalentTabInfo(tab)
        table.insert(parts, string.format("%s %d", tabName or ("Arbol " .. tab), pointsSpent or 0))
    end
    return table.concat(parts, " / ")
end

-- Datos del personaje: lo unico que cambia entre jugadores. Es lo que se pega en el Gem/GPT con /geai2.
local function AddCharacterData(out)
    local add = function(text) table.insert(out, text) end

    add("WPL-GEAR v1")
    add(ABBREV_LEGEND)
    add("")
    add("== MI PERSONAJE ==")
    add(string.format("%s | %s %s | Nivel %d | Talentos %s (la spec es el arbol con mas puntos)",
        UnitName("player"), UnitClass("player"), UnitRace("player"), UnitLevel("player"), TalentSummary()))
    add("")
    add("== EQUIPO PUESTO ==")
    local emptySlots = {}
    for _, slotId in ipairs(SLOT_ORDER) do
        local link = GetInventoryItemLink("player", slotId)
        if link then
            DescribeItem(link, SLOT_LABELS[slotId], out, false, ENCHANTABLE_SLOTS[slotId])
        else
            table.insert(emptySlots, SLOT_LABELS[slotId])
        end
    end
    if #emptySlots > 0 then
        add("Vacíos: " .. table.concat(emptySlots, ", "))
    end
    add("")
    add("== EQUIPO EN MIS BOLSAS (no puesto, solo lo que puedo equipar) ==")
    local bagCount = 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
                if equipLoc and equipLoc ~= "" and not SKIP_EQUIP_LOC[equipLoc]
                    and DescribeItem(link, _G[equipLoc] or equipLoc, out, true) then
                    bagCount = bagCount + 1
                end
            end
        end
    end
    if bagCount == 0 then
        add("(no hay piezas de equipo que pueda usar en las bolsas)")
    end
end

-- short = true: solo los datos, para pegarlos en el asistente que ya tiene las instrucciones.
local function BuildPrompt(short)
    local out = {}
    local add = function(text) table.insert(out, text) end

    if short then
        AddCharacterData(out)
        return table.concat(out, "\n")
    end

    add("Eres un experto en WoW Vanilla (1.x) que aconseja sobre equipo. Analiza mi personaje y responde en español.")
    add("")
    add("== CONTEXTO DEL SERVIDOR ==")
    add(SERVER_CONTEXT)
    add("")
    AddCharacterData(out)
    add("")
    add("== TAREA ==")
    add("1. Revisa mis bolsas: ¿hay algo mejor que lo que llevo puesto para la spec de este personaje? Dime qué equipar, en qué slot y por qué. Compara stats y efectos (Equip/Use), no solo el nivel de objeto.")
    add("2. Sugiere mejoras, primero PRE-BIS: items que pueda conseguir ya (misiones, mazmorras, crafteo, reputación, PvP/battlegrounds) y que superen lo que llevo. Indica el slot y dónde se consigue cada uno.")
    add("3. Solo donde mi equipo ya supere o iguale ese pre-BIS, dime qué items de las raids abiertas me mejorarían.")
    add("4. Encantamientos: para cada slot de mi equipo puesto marcado SIN ENCANTAR, o cuyo encantamiento (Ench:) no sea el mejor para mi spec, recomienda el mejor encantamiento de Vanilla. Incluye librams/arcanums de cabeza y piernas, hombreras de reputación (Zandalar de ZG, Argent Dawn), kits de armadura y miras. Indica cómo se consigue (receta de Encantamiento, reputación, misión) y, si hay una opción mucho más barata casi igual de buena, menciónala. Si recomiendo cambiar un item en el punto 1 o 2, recomienda el encantamiento para el item nuevo.")
    add("5. Entrega todo ordenado. Para cada item de raid o battleground usa este formato: RAID o BG > jefe o rango/objetivo > item (slot). Agrupa por raid o BG y dentro por jefe. Los encantamientos van en una sección aparte: Slot > encantamiento > cómo se consigue.")
    add("")
    add("== REGLAS ==")
    add("- Solo items y encantamientos que existan en Vanilla y sean obtenibles en el contenido abierto indicado arriba. El servidor tiene la base de datos de WotLK: no recomiendes encantamientos de TBC ni WotLK aunque existan en el juego.")
    add("- Si no estás seguro de qué jefe o fuente suelta un item, dilo claramente en vez de inventarlo.")
    add("- Usa los nombres e IDs de item que te doy para no confundir versiones.")
    add("- Los items Heirloom no entran en raids: si llevo uno puesto o en bolsas, ignóralo para el análisis de raid y sugiere reemplazarlo por un item normal.")

    return table.concat(out, "\n")
end

local geaiFrame

local function EnsureFrame()
    if geaiFrame then
        return geaiFrame
    end

    local f = CreateFrame("Frame", "WowPeruLandGeaiFrame", UIParent)
    f:SetSize(580, 440)
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
    title:SetText("WowPeruLand - Prompt para IA")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText("Ctrl+A para seleccionar todo, Ctrl+C para copiar, y pégalo en tu IA")

    local scroll = CreateFrame("ScrollFrame", "WowPeruLandGeaiScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -60)
    scroll:SetPoint("BOTTOMRIGHT", -38, 20)

    local editBox = CreateFrame("EditBox", "WowPeruLandGeaiEditBox", scroll)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(510)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    scroll:SetScrollChild(editBox)

    f.editBox = editBox
    f.scroll = scroll
    geaiFrame = f
    return f
end

local function ShowPrompt(short)
    local f = EnsureFrame()
    f.editBox:SetText(BuildPrompt(short))
    f.editBox:HighlightText()
    f.editBox:SetFocus()
    f.scroll:SetVerticalScroll(0)
    f:Show()
end

SLASH_WPLGEAI1 = "/geai"
SlashCmdList["WPLGEAI"] = function()
    ShowPrompt(false)
end

SLASH_WPLGEAI21 = "/geai2"
SlashCmdList["WPLGEAI2"] = function()
    ShowPrompt(true)
end
