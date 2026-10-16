if EUI_CLIENT_BLOCKED then return end -- EllesmereUI's client failsafe
if not EllesmereUI then return end
-------------------------------------------------------------------------------
--  Standalone pet XP bar
--  Built like the EllesmereUI Action Bars XP bar: dark background, 1px border,
--  centred text, tooltip on hover. It registers with EllesmereUI unlock mode,
--  which owns position, width and height.
-------------------------------------------------------------------------------
local _, ns = ...

local KEY = "EUI_PetXPBar"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- Just below the Action Bars XP bar's default spot (TOP, 0, -100, 18 high).
local DEFAULT_POS = { point = "TOP", relPoint = "TOP", x = 0, y = -122 }

local PP = EllesmereUI.PP
local Get, Cfg, PetXP = ns.Get, ns.Cfg, ns.PetXP

local holder, bar, text, clickBtn

local function ShowTooltip(self)
    local cur, maxXP, level = PetXP()
    if not cur then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(UnitName("pet") or PET, 1, 1, 1)
    GameTooltip:AddDoubleLine(LEVEL, tostring(level), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(XP, string.format("%s / %s (%.1f%%)",
        BreakUpLargeNumbers(cur), BreakUpLargeNumbers(maxXP), cur / maxXP * 100), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(EllesmereUI.L and EllesmereUI.L("Remaining") or "Remaining",
        ns.Abbreviate(maxXP - cur), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to open the pet window.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function HideTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function EnsureClickButton()
    if clickBtn or not holder then return end
    clickBtn = ns.MakeClickButton(holder, ShowTooltip, HideTooltip)
end

local function Update()
    if not holder then return end
    local cur, maxXP, level = PetXP()
    local show = cur and Get("enabled")
    if show then
        bar:SetMinMaxValues(0, maxXP)
        bar:SetValue(cur)
        text:SetFormattedText("%s - %.1f%%", ns.PetTitle(level), cur / maxXP * 100)
    end
    -- The click overlay makes Show/Hide protected; in lockdown only the fill
    -- and text update, PLAYER_REGEN_ENABLED brings the visibility up to date.
    if InCombatLockdown() and holder:IsProtected() then return end
    EnsureClickButton()
    holder:SetShown(show and true or false)
end

local function ApplyLayout()
    local w, h = Get("width"), Get("height")
    if PP then PP.Size(holder, w, h) else holder:SetSize(w, h) end
    text:SetFont(EllesmereUI.GetFontPath("actionBars")
        or "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
        Get("textSize"), EllesmereUI.GetFontOutlineFlag("actionBars"))
end

local function ApplyPosition()
    local pos = EUIPetXPDB and EUIPetXPDB.pos or DEFAULT_POS
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
end

local function Inset(region)
    if PP then
        PP.SetInside(region, holder, 1, 1)
    else
        region:SetPoint("TOPLEFT", 1, -1)
        region:SetPoint("BOTTOMRIGHT", -1, 1)
    end
end

local function CreateBar()
    if holder then return end
    holder = CreateFrame("Frame", "EUIPetXPBar", UIParent)
    holder:SetClampedToScreen(true)
    holder:Hide()

    local bg = holder:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0.06, 0.06, 0.08, 0.85)
    Inset(bg)

    if EllesmereUI.MakeBorder then
        holder._border = EllesmereUI.MakeBorder(holder, 0, 0, 0, 1)
    end

    bar = CreateFrame("StatusBar", nil, holder)
    bar:SetStatusBarTexture(WHITE)
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 4)
    bar:SetStatusBarColor(ns.FillColor())
    Inset(bar)

    -- The text sits on a frame above the border strips (MakeBorder renders two
    -- levels above the holder), so large text is not cut by the border edges.
    local textHost = CreateFrame("Frame", nil, bar)
    textHost:SetAllPoints(bar)
    textHost:SetFrameLevel(holder:GetFrameLevel() + 3)
    text = textHost:CreateFontString(nil, "OVERLAY")
    if EllesmereUI.PrimeFontShadow then
        EllesmereUI.PrimeFontShadow(text, EllesmereUI.GetFontUseShadow("actionBars"))
    end
    text:SetPoint("CENTER")
    text:SetTextColor(1, 1, 1, 1)

    holder:EnableMouse(true)
    holder:SetScript("OnEnter", ShowTooltip)
    holder:SetScript("OnLeave", HideTooltip)
    holder:SetScript("OnMouseUp", ns.OpenPetFrame)

    ApplyLayout()
    ApplyPosition()
end

local function Resized()
    ApplyLayout()
    if EllesmereUI._unlockActive and EllesmereUI.RepositionBarToMover then
        EllesmereUI.RepositionBarToMover(KEY)
    end
end

local function Snap(v)
    if PP and PP.Snap then return PP.Snap(v) end
    return math.floor(v + 0.5)
end

local function RegisterUnlock()
    if not (EllesmereUI.RegisterUnlockElements and EllesmereUI.MakeUnlockElement) then return end
    EllesmereUI:RegisterUnlockElements({
        EllesmereUI.MakeUnlockElement({
            key = KEY,
            label = "Pet XP Bar",
            group = "Action Bars",
            order = 320,
            getFrame = function() return holder end,
            -- A switched-off bar gets no mover; re-registering applies a change live.
            isHidden = function() return not Get("enabled") end,
            getSize = function() return Get("width"), Get("height") end,
            setWidth = function(_, w)
                Cfg().width = math.max(50, Snap(w))
                Resized()
            end,
            setHeight = function(_, h)
                Cfg().height = math.max(2, Snap(h))
                Resized()
            end,
            savePos = function(_, point, relPoint, x, y)
                if not point then return end
                Cfg().pos = { point = point, relPoint = relPoint or point, x = x, y = y }
                if not EllesmereUI._unlockActive then ApplyPosition() end
            end,
            loadPos = function()
                local pos = EUIPetXPDB and EUIPetXPDB.pos
                return pos and pos.point and pos or DEFAULT_POS
            end,
            clearPos = function()
                Cfg().pos = nil
                ApplyPosition()
            end,
            applyPos = ApplyPosition,
        }),
    }, "EUI-PetXP")
end

-- Called by Commands.lua after the enabled setting changes.
function ns.RefreshBar()
    if holder then RegisterUnlock() end
    Update()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CreateBar()
        RegisterUnlock()
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PET_UI_UPDATE")
        self:RegisterEvent("PLAYER_LEVEL_UP")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterUnitEvent("UNIT_PET", "player")
        self:RegisterUnitEvent("UNIT_PET_EXPERIENCE", "pet")
        self:RegisterUnitEvent("UNIT_NAME_UPDATE", "pet")
        -- The player's UNIT_LEVEL too: during PLAYER_LEVEL_UP UnitLevel("player")
        -- can still return the old level, and the bar returns at the new one.
        self:RegisterUnitEvent("UNIT_LEVEL", "pet", "player")
    end
    Update()
end)
