if EUI_CLIENT_BLOCKED then return end -- EllesmereUI's client failsafe
if not EllesmereUI then return end
-------------------------------------------------------------------------------
--  /petxp bar [on|off]: switches the standalone bar; without on/off it toggles.
--  The DataBars block is separate and is added or removed in DataBars itself.
-------------------------------------------------------------------------------
local _, ns = ...

local PREFIX = "|cff0cd29fEUI-PetXP|r: "

SLASH_EUIPETXP1 = "/petxp"
SlashCmdList.EUIPETXP = function(msg)
    local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
    if cmd ~= "bar" then
        print(PREFIX .. "/petxp bar [on||off] - show or hide the standalone pet XP bar")
        return
    end
    local on
    if arg == "on" then on = true
    elseif arg == "off" then on = false
    else on = not ns.Get("enabled") end
    ns.Cfg().enabled = on
    ns.RefreshBar()
    print(PREFIX .. "standalone bar " .. (on and "on" or "off"))
end
