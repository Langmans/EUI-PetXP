if EUI_CLIENT_BLOCKED then return end -- EllesmereUI's client failsafe
if not EllesmereUI then return end
-------------------------------------------------------------------------------
--  Pet XP block for EllesmereUI DataBars
--  DataBars has no public API for third-party blocks. Its module namespace is
--  published in EllesmereUI._ModuleNS for its own LoadOnDemand options file, and
--  that namespace holds the three tables a block type needs:
--    BLOCK_TYPES     the "Add Block" picker (key + label)
--    BLOCK_DEFAULTS  per-type settings copied into a new block; a type without
--                    an entry cannot be added
--    BlockFactories  typeKey -> function(blockCfg, slot, content, barCtx) -> inst
--  The factory contract is documented at the top of DataBars' Blocks\Shared.lua.
--  This file mirrors the XP / Reputation block (Blocks\XPRep.lua) so the pet bar
--  looks the same: label on top, thin bar underneath.
--
--  Everything is checked before use, so a DataBars update that renames these
--  tables leaves the block missing from the picker instead of raising errors.
--  The bars are built in DataBars' OnEnable (PLAYER_LOGIN); OptionalDeps in the
--  .toc loads DataBars first, so registering at file load is early enough.
-------------------------------------------------------------------------------
local _, ns = ...

local TYPE_KEY = "petxp"
local TYPE_LABEL = "Pet XP Bar"

local db = EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIDataBars
if not (db and db.BLOCK_TYPES and db.BLOCK_DEFAULTS and db.BlockFactories and db.BlockKit) then return end
local K = db.BlockKit
if not (K.InstKey and K.MakeEventFrame and K.RegisterInstEvents and K.UnregisterInstEvents
    and K.HBudget and K.VSlotW and K.MaybeRelayout and K.CONTENT_BASE) then return end

local CreateFrame = CreateFrame
local floor, max, min = math.floor, math.max, math.min

local CONTENT_BASE = K.CONTENT_BASE

-- Picker entry, right after the XP / Reputation block.
local pos = #db.BLOCK_TYPES + 1
for i, t in ipairs(db.BLOCK_TYPES) do
    if t.key == TYPE_KEY then return end
    if t.key == "xprep" then pos = i + 1 end
end
table.insert(db.BLOCK_TYPES, pos, { key = TYPE_KEY, label = TYPE_LABEL })
db.BLOCK_DEFAULTS[TYPE_KEY] = {}

local function BlockColorOf(blockCfg)
    if K.BlockColorOf then return K.BlockColorOf(blockCfg) end
    return 1, 1, 1
end

db.BlockFactories[TYPE_KEY] = function(blockCfg, slot, content, barCtx)
    local inst = { cfg = blockCfg, slot = slot, content = content, ctx = barCtx }
    inst.key = K.InstKey(barCtx, blockCfg)
    -- PLAYER_REGEN_ENABLED: geometry and the click overlay wait for the end of
    -- combat, so the block needs a pass there.
    inst.events = {
        "PLAYER_ENTERING_WORLD", "PET_UI_UPDATE", "PLAYER_LEVEL_UP",
        "UNIT_PET", "UNIT_PET_EXPERIENCE", "UNIT_LEVEL", "PLAYER_REGEN_ENABLED",
    }

    local hit = CreateFrame("Frame", nil, content)
    hit:SetAllPoints()
    hit:EnableMouse(true)
    local nameText = content:CreateFontString(nil, "OVERLAY")
    if K.AttachTextOffset then K.AttachTextOffset(inst, nameText) end
    local barTrack = content:CreateTexture(nil, "BACKGROUND")
    local bar = CreateFrame("StatusBar", nil, content)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")

    -- label, cur, max, level; nil when the pet has no experience (no pet out,
    -- or a warlock demon) or is at the hunter's level, which collapses the
    -- block out of the bar.
    local function ComputeState()
        local cur, maxXP, level = ns.PetXP()
        if not cur then return nil end
        local label = (PET or "Pet") .. " " .. floor(cur / maxXP * 100) .. "% to level " .. (level + 1)
        return label, cur, maxXP, level
    end

    local function ShowTooltip()
        local _, cur, maxXP, level = ComputeState()
        if not cur or not db.Tip_Begin then return end
        local bl = BreakUpLargeNumbers
        db.Tip_Begin(hit)
        db.Tip_AddLine(UnitName("pet") or PET or "Pet", 1, 1, 1)
        db.Tip_AddDouble(LEVEL or "Level", tostring(level), 0.6, 0.6, 0.6, 1, 1, 1)
        db.Tip_AddDouble(XP or "XP", bl(cur) .. " / " .. bl(maxXP), 0.6, 0.6, 0.6, 1, 1, 1)
        db.Tip_AddDouble("Remaining", ns.Abbreviate(maxXP - cur), 0.6, 0.6, 0.6, 1, 1, 1)
        db.Tip_AddLine(" ")
        db.Tip_AddLine("Click to open the pet window.", 0.6, 0.6, 0.6)
        db.Tip_Show()
    end
    local function HideTooltip()
        if db.Tip_Hide then db.Tip_Hide(hit) end
    end
    hit:SetScript("OnEnter", ShowTooltip)
    hit:SetScript("OnLeave", HideTooltip)
    hit:SetScript("OnMouseUp", ns.OpenPetFrame)

    -- Secure click overlay from Click.lua; it puts this block's whole bar under
    -- protection, so from then on sizing, anchoring and Show/Hide of content
    -- only happen out of combat.
    local clickBtn
    local function EnsureClickButton()
        if not clickBtn then clickBtn = ns.MakeClickButton(hit, ShowTooltip, HideTooltip) end
    end

    function inst:Refresh()
        EnsureClickButton()
        local barCfg = barCtx.cfg
        local barH = barCtx.GetThickness()
        local textHeight = max(9, floor(CONTENT_BASE * 0.4333 + 0.5))

        local label, cur, maxXP = ComputeState()
        local locked = InCombatLockdown() and content:IsProtected()
        if not label then
            if locked then return end
            content:Hide()
            K.MaybeRelayout(inst)
            return
        end

        nameText:SetTextColor(BlockColorOf(blockCfg))
        bar:SetStatusBarColor(ns.FillColor())
        bar:SetMinMaxValues(0, maxXP)
        bar:SetValue(cur)
        db.SetFont(nameText, textHeight, barCfg)
        if locked then
            nameText:SetText(label)
            return
        end
        content:Show()

        if barCtx.IsVertical() then
            -- Vertical bar: label stacked above the bar, both centred.
            local slotW = K.VSlotW(inst)
            local innerW = max(24, slotW - 8)
            nameText:SetText(label)
            db.SetWrappedText(nameText, innerW, "CENTER")
            nameText:ClearAllPoints()
            nameText:SetPoint("TOP", content, "TOP", 0, -3)
            local textH = db.SnapToPixelGrid(nameText:GetStringHeight())
            local bH = 4
            barTrack:ClearAllPoints()
            barTrack:SetPoint("TOP", content, "TOP", 0, -(3 + textH + 3))
            barTrack:SetSize(innerW, bH)
            barTrack:SetColorTexture(1, 1, 1, 0.1)
            bar:ClearAllPoints()
            bar:SetSize(innerW, bH)
            bar:SetPoint("TOP", content, "TOP", 0, -(3 + textH + 3))
            content:SetSize(slotW, max(3 + textH + 3 + bH + 3, 40))
        else
            -- Horizontal bar: label on top, bar underneath sharing its left
            -- edge and running 40px past the text, the stack centred vertically.
            local slotW = max(K.HBudget(inst, 300), 60)
            local bH = max(2, floor(CONTENT_BASE * 0.2 + 0.5) - 1)
            db.ResetInlineText(nameText, "LEFT")
            nameText:SetText(label)

            local textW = nameText:GetStringWidth() or 0
            local maxTextW = max(20, slotW)
            if textW > maxTextW then
                textW = maxTextW
                nameText:SetWidth(textW)
            end
            if textW < 20 then textW = 20 end
            textW = db.SnapToPixelGrid(textW)
            local barW = min(textW + 40, maxTextW)

            local textH = db.SnapToPixelGrid(nameText:GetStringHeight() or textHeight)
            local pad = max(0, floor((barH - (textH + 2 + bH)) / 2 + 0.5))
            content:SetSize(min(slotW, barW), barH)
            nameText:ClearAllPoints()
            nameText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -pad)
            barTrack:ClearAllPoints()
            barTrack:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(pad + textH + 2))
            barTrack:SetSize(barW, bH)
            barTrack:SetColorTexture(1, 1, 1, 0.1)
            bar:ClearAllPoints()
            bar:SetSize(barW, bH)
            bar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(pad + textH + 2))
        end
        K.MaybeRelayout(inst)
    end

    -- RegisterEvent delivers UNIT_* for every unit; only the pet and the
    -- player change what this block shows.
    inst.eventFrame = K.MakeEventFrame(inst, function(self, event, unit)
        if event:sub(1, 5) == "UNIT_" and unit ~= "pet" and unit ~= "player" then return end
        self:Refresh()
    end)

    function inst:Enable()
        if not InCombatLockdown() then content:Show() end
        EnsureClickButton()
        K.RegisterInstEvents(self)
    end

    function inst:Disable()
        K.UnregisterInstEvents(self)
        if not InCombatLockdown() then content:Hide() end
    end

    function inst:GetAutoLength()
        if not content:IsShown() then return 0 end
        if barCtx.IsVertical() then
            return max(content:GetHeight() or 40, 40)
        end
        local tw = nameText:GetStringWidth() or 0
        if tw < 20 then tw = 120 end
        return tw + 40
    end

    function inst:Destroy()
        self._dead = true
        if clickBtn and K.ParkSecureFrame then
            K.ParkSecureFrame(clickBtn, self.key .. "_petxp")
            clickBtn = nil
        end
        if not InCombatLockdown() then content:Hide() end
    end

    return inst
end
