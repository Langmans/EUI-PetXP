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

-- v when it is a plain value of the wanted type; nil for a secret value (the
-- client may hide some in combat), which cannot be compared or concatenated.
local function Plain(v, kind)
    if v == nil or (issecretvalue and issecretvalue(v)) or type(v) ~= kind then return nil end
    return v
end

-- cur, max, level of the current pet; nil when the pet has no experience,
-- cannot gain any (at the hunter's level) or the client hides the numbers.
function ns.PetXP()
    if not (HasPetUI and HasPetUI()) then return nil end
    local cur, nextXP = GetPetExperience()
    cur, nextXP = Plain(cur, "number") or 0, Plain(nextXP, "number")
    if not nextXP or nextXP <= 0 then return nil end
    local level = Plain(UnitLevel("pet"), "number")
    local playerLevel = Plain(UnitLevel("player"), "number")
    if not level or not playerLevel or level >= playerLevel then return nil end
    return cur, nextXP, level
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

-- English rank names, only for a client whose loyalty API returns a bare number.
local LOYALTY_NAMES = { "Rebellious", "Unruly", "Submissive", "Dependable", "Faithful", "Best Friend" }

-- First return of fn(), or nil when fn is missing, errors or returns a secret.
local function Call(fn, kind)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn)
    return ok and Plain(v, kind) or nil
end

-- Loyalty rank 1..6 from the training points, which total
-- pet level * (rank - 1); this needs no localized names. A total that does
-- not divide evenly leaves the rank unknown rather than guessed.
local function RankFromTrainingPoints()
    local total = Call(C_PetInfo and C_PetInfo.GetPetTrainingPoints or GetPetTrainingPoints, "number")
    local level = Plain(UnitLevel("pet"), "number")
    if not total or not level or level <= 0 or total % level ~= 0 then return nil end
    local rank = total / level + 1
    if rank < 1 or rank > MAX_LOYALTY then return nil end
    return rank
end

-- name, rank of the pet's loyalty; either may be nil. WoW Forever's
-- C_PetInfo.GetPetLoyalty() returns the rank name ("Faithful"), the classic
-- global GetPetLoyalty() "Loyalty Level 3 (Faithful)", and a bare number is
-- handled too.
local function Loyalty()
    local raw = Call(C_PetInfo and C_PetInfo.GetPetLoyalty, "string")
        or Call(GetPetLoyalty, "string")
        or Call(C_PetInfo and C_PetInfo.GetPetLoyalty, "number")
    local name, rank
    if type(raw) == "number" then
        rank = raw
        name = LOYALTY_NAMES[raw]
    elseif raw and raw ~= "" then
        name = raw:match("%((.-)%)") or raw
        rank = tonumber(raw:match("%d"))
    end
    return name, RankFromTrainingPoints() or rank
end

-- The loyalty name coloured by its rank; uncoloured without a rank.
local function LoyaltyText()
    local name, rank = Loyalty()
    if not name then return nil end
    if not rank then return name end
    local r, g, b = ns.LoyaltyColor(rank)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
end

-- "<pet name>, <loyalty>, <level>", the shared head of the bar text and the
-- DataBars label.
function ns.PetTitle(level)
    local parts = { Plain(UnitName("pet"), "string") or PET or "Pet" }
    parts[#parts + 1] = LoyaltyText()
    parts[#parts + 1] = Plain(level, "number") and tostring(level)
    return table.concat(parts, ", ")
end

-- WoW Forever shows raw XP below 10,000 unabbreviated, like the player XP bar.
ns.Abbreviate = (EllesmereUI.IS_FOREVER and EllesmereUI.ForeverAbbreviateLargeNumbers)
    or AbbreviateLargeNumbers
