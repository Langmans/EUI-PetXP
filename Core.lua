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
--
--  A pet at the hunter's level gains no experience until the hunter levels,
--  so the bar hides then too, the way EllesmereUI's XP block collapses at the
--  level cap.
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

-- cur, max, level of the current pet; nil when the pet has no experience or
-- cannot gain any (at the hunter's level).
function ns.PetXP()
    if not (HasPetUI and HasPetUI()) then return nil end
    local cur, nextXP = GetPetExperience()
    if not nextXP or nextXP <= 0 then return nil end
    local level = UnitLevel("pet") or 0
    if level >= (UnitLevel("player") or 0) then return nil end
    return cur or 0, nextXP, level
end

-- Loyalty colours run from Friendly to Exalted, the stops taken from the
-- reputation colours of EllesmereUI's Action Bars data bars.
local LOYALTY_STOPS = {
    { 0.30, 0.70, 0.25 }, -- Friendly
    { 0.25, 0.65, 0.50 }, -- Honored
    { 0.25, 0.50, 0.75 }, -- Revered
    { 0.35, 0.30, 0.80 }, -- Exalted
}
local MAX_LOYALTY = 6

-- r, g, b for loyalty level 1..6, spread evenly over the stops.
function ns.LoyaltyColor(level)
    local t = (math.min(math.max(level, 1), MAX_LOYALTY) - 1) / (MAX_LOYALTY - 1) * (#LOYALTY_STOPS - 1)
    local i = math.min(math.floor(t) + 1, #LOYALTY_STOPS - 1)
    local f = t - (i - 1)
    local a, b = LOYALTY_STOPS[i], LOYALTY_STOPS[i + 1]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- GetPetLoyalty() returns "Loyalty Level 3 (Faithful)": the number gives the
-- colour, the part in brackets is the localized name. Without brackets the whole
-- string is shown, without a number it stays uncoloured.
local function LoyaltyText()
    local raw = GetPetLoyalty and GetPetLoyalty()
    if not raw or raw == "" then return nil end
    local name = raw:match("%((.-)%)") or raw
    local level = tonumber(raw:match("%d"))
    if not level then return name end
    local r, g, b = ns.LoyaltyColor(level)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
end

-- "<pet name>, <loyalty>, <level>", the shared head of the bar text and the
-- DataBars label.
function ns.PetTitle(level)
    local parts = { UnitName("pet") or PET or "Pet" }
    parts[#parts + 1] = LoyaltyText()
    parts[#parts + 1] = tostring(level)
    return table.concat(parts, ", ")
end

-- WoW Forever shows raw XP below 10,000 unabbreviated, like the player XP bar.
ns.Abbreviate = (EllesmereUI.IS_FOREVER and EllesmereUI.ForeverAbbreviateLargeNumbers)
    or AbbreviateLargeNumbers
