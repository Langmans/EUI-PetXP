if EUI_CLIENT_BLOCKED then return end -- EllesmereUI's client failsafe: dormant when EllesmereUI is
if not EllesmereUI then return end
-------------------------------------------------------------------------------
--  EUI-PetXP: shared state and helpers
--  Loaded first; every other file reads the settings and the pet's experience
--  through ns.
--
--  GetPetExperience() returns 0 / 0 for a pet that has no experience (warlock
--  demons, no pet out), the same test Blizzard's PetPaperDollFrame uses to hide
--  its own bar, so everything here only shows for a hunter pet.
-------------------------------------------------------------------------------
local _, ns = ...

local DEFAULTS = { enabled = true, width = 400, height = 12, textSize = 9 }

-- Saved settings table, created on first write.
function ns.Cfg()
    EUIPetXPDB = EUIPetXPDB or {}
    return EUIPetXPDB
end

function ns.Get(key)
    local v = EUIPetXPDB and EUIPetXPDB[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

function ns.FillColor()
    local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS).HUNTER
    if cc then return cc.r, cc.g, cc.b end
    return 0.67, 0.83, 0.45
end

-- cur, max, level of the current pet; nil when the pet has no experience.
function ns.PetXP()
    if not (HasPetUI and HasPetUI()) then return nil end
    local cur, nextXP = GetPetExperience()
    if not nextXP or nextXP <= 0 then return nil end
    return cur or 0, nextXP, UnitLevel("pet") or 0
end

-- WoW Forever shows raw XP below 10,000 unabbreviated, like the player XP bar.
ns.Abbreviate = (EllesmereUI.IS_FOREVER and EllesmereUI.ForeverAbbreviateLargeNumbers)
    or AbbreviateLargeNumbers
