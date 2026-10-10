if EUI_CLIENT_BLOCKED then return end -- EllesmereUI's client failsafe
if not EllesmereUI then return end
-------------------------------------------------------------------------------
--  Left click: open the pet page of the character window
--  ToggleCharacter called from addon Lua runs tainted, and on this client the
--  character window's show path then fails (EllesmereUI DataBars hits the same
--  wall in its item level block). So the click goes through a secure overlay
--  whose macro clicks Blizzard's own buttons, and the window opens from
--  Blizzard's handlers exactly as if the player had clicked them.
--
--  This client's character window is built like retail's: no CharacterFrameTabN
--  and no PetPaperDollFrame. The pet page is the fourth icon in the side pane
--  of the paper doll (PaperDollSidebarTab4), next to stats, titles and
--  equipment sets.
--    open   the micro button shows the window on the paper doll, then the
--           sidebar tab switches the side pane to the pet. When the paper doll
--           is already showing, only the sidebar tab is clicked: the micro
--           button would close the window.
--    close  the window's close button, picked in PreClick when the pet pane is
--           already showing. Attributes are locked in combat, so in combat the
--           overlay keeps the full open macro: it opens from a closed window,
--           but a second click does not close.
--  Overlays need to be created out of combat and make their parent protected
--  (no Show/Hide/SetSize in combat); until one exists the parent's plain
--  OnMouseUp fallback (ns.OpenPetFrame) is all there is.
-------------------------------------------------------------------------------
local _, ns = ...

local PET_SIDEBAR = 4
local PET_TAB_CLICK = "/click PaperDollSidebarTab" .. PET_SIDEBAR
local OPEN_MACRO = "/click CharacterMicroButton\n" .. PET_TAB_CLICK
local CLOSE_MACRO = "/click CharacterFrameCloseButton"
local clickButtons = setmetatable({}, { __mode = "k" })

-- The pet side pane, from Blizzard's sidebar list; nil if it cannot be found.
local function PetPane()
    local info = PAPERDOLL_SIDEBARS and PAPERDOLL_SIDEBARS[PET_SIDEBAR]
    return info and info.frame and _G[info.frame]
end

local function PickMacro(self)
    if InCombatLockdown() then return end
    local macro = OPEN_MACRO
    if PaperDollFrame and PaperDollFrame:IsVisible() then
        local pane = PetPane()
        macro = (pane and pane:IsVisible()) and CLOSE_MACRO or PET_TAB_CLICK
    end
    self:SetAttribute("*macrotext1", macro)
end

-- Secure overlay covering parent; nil in combat or without the micro button.
function ns.MakeClickButton(parent, onEnter, onLeave)
    if InCombatLockdown() or not _G.CharacterMicroButton then return nil end
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:SetAllPoints(parent)
    b:SetFrameLevel(parent:GetFrameLevel() + 5)
    b:RegisterForClicks("AnyUp")
    -- Without this the ActionButtonUseKeyDown CVar makes the template act on
    -- key-down only and the "AnyUp" clicks are dropped.
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("*type1", "macro")
    b:SetAttribute("*macrotext1", OPEN_MACRO)
    b:SetScript("PreClick", PickMacro)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", onLeave)
    clickButtons[b] = true
    return b
end

-- Fallback until an overlay exists (built in combat, or no micro button).
function ns.OpenPetFrame(_, button)
    if button ~= "LeftButton" or not (HasPetUI and HasPetUI()) then return end
    if ToggleCharacter then ToggleCharacter("PetPaperDollFrame") end
end

-- PLAYER_REGEN_DISABLED fires just before lockdown: leave every overlay on the
-- open macro, which is the one that still does something useful in combat.
local combatWatch = CreateFrame("Frame")
combatWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatch:SetScript("OnEvent", function()
    for b in pairs(clickButtons) do b:SetAttribute("*macrotext1", OPEN_MACRO) end
end)
