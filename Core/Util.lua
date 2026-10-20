-- Nebbinator - Core/Util.lua
-- Shared data tables and small helpers. No side effects.

local ADDON, NS = ...


NS.Util = {}
local U = NS.Util

--------------------------------------------------------------------
-- Palette
--
-- BiSTheme when it is installed, the same values inline when it is not:
-- Nebbinator must never need a second addon to draw itself. Every file
-- that paints reads NS.T, so there is one palette and not six opinions.
-- Looked up at call time, because BiSTheme may load after us.
--------------------------------------------------------------------

local HEX = {
    bg = "121020", surface = "1a1730", sunken = "221d3c",
    line = "2a2446", line2 = "3a3260",
    ink = "ece8f6", ink2 = "c6bedd", muted = "968ead", dim = "8e86a6",
    accent = "b980ff", accentSoft = "2c2148",
    good = "4fd0cf", warn = "f08cb0", gold = "e5c04a", slate = "8fb4d6",
    epic = "c08cff", rare = "5fa8f0", uncommon = "5fd06f",
}

local function FallbackRGB(name)
    local hex = HEX[name] or name or "ffffff"
    local r = tonumber(string.sub(hex, 1, 2), 16)
    local g = tonumber(string.sub(hex, 3, 4), 16)
    local b = tonumber(string.sub(hex, 5, 6), 16)
    if not r or not g or not b then return 1, 1, 1 end
    return r / 255, g / 255, b / 255
end

NS.T = {}
NS.T.hex = HEX

-- Per NAME, not per call: a colour BiSTheme has never heard of falls back to
-- the inline table instead of returning nil into SetColorTexture.
function NS.T.rgb(name)
    local real = _G.BiSTheme
    if real and real.hex and real.hex[name] and real.rgb then return real.rgb(name) end
    return FallbackRGB(name)
end

function NS.T.rgba(name, a)
    local r, g, b = NS.T.rgb(name)
    return r, g, b, a or 1
end

function NS.T.text(name, str)
    local real = _G.BiSTheme
    if real and real.hex and real.hex[name] then
        return "|cff" .. real.hex[name] .. tostring(str or "") .. "|r"
    end
    return "|cff" .. (HEX[name] or "ffffff") .. tostring(str or "") .. "|r"
end

-- (one palette: the block that used to sit above this file's helpers built a second one from BiSTheme
-- at load and was thrown away here - 21 Oct 2026, the review)
local T = NS.T

--------------------------------------------------------------------
-- Class / spec data (TBC). Order here is the order used everywhere:
-- the UI grid, the built message, and the saved variables.
--------------------------------------------------------------------

NS.ROLES = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }

NS.CLASSES = {
    { key = "warrior", name = "Warrior", file = "WARRIOR", specs = {
        { key = "prot",   name = "Prot",    role = "TANK"   },
        { key = "arms",   name = "Arms",    role = "DPS"    },
        { key = "fury",   name = "Fury",    role = "DPS"    },
    }},
    { key = "paladin", name = "Paladin", file = "PALADIN", specs = {
        { key = "prot",   name = "Prot",    role = "TANK"   },
        { key = "holy",   name = "Holy",    role = "HEALER" },
        { key = "ret",    name = "Ret",     role = "DPS"    },
    }},
    { key = "druid",   name = "Druid",   file = "DRUID", specs = {
        { key = "feral",  name = "Bear",    role = "TANK"   },
        { key = "resto",  name = "Resto",   role = "HEALER" },
        { key = "balance",name = "Boomkin", role = "DPS"    },
        { key = "cat",    name = "Cat",     role = "DPS"    },
    }},
    { key = "priest",  name = "Priest",  file = "PRIEST", specs = {
        { key = "holy",   name = "Holy",    role = "HEALER" },
        { key = "disc",   name = "Disc",    role = "HEALER" },
        { key = "shadow", name = "Shadow",  role = "DPS"    },
    }},
    { key = "shaman",  name = "Shaman",  file = "SHAMAN", specs = {
        { key = "resto",  name = "Resto",   role = "HEALER" },
        { key = "ele",    name = "Ele",     role = "DPS"    },
        { key = "enh",    name = "Enh",     role = "DPS"    },
    }},
    { key = "mage",    name = "Mage",    file = "MAGE", specs = {
        { key = "dps",    name = "DPS",     role = "DPS"    },
    }},
    { key = "warlock", name = "Warlock", file = "WARLOCK", specs = {
        { key = "dps",    name = "DPS",     role = "DPS"    },
    }},
    { key = "hunter",  name = "Hunter",  file = "HUNTER", specs = {
        { key = "dps",    name = "DPS",     role = "DPS"    },
    }},
    { key = "rogue",   name = "Rogue",   file = "ROGUE", specs = {
        { key = "dps",    name = "DPS",     role = "DPS"    },
    }},
}

NS.DAYS = {
    { key = "monday",    name = "Monday",    short = "Mon" },
    { key = "tuesday",   name = "Tuesday",   short = "Tue" },
    { key = "wednesday", name = "Wednesday", short = "Wed" },
    { key = "thursday",  name = "Thursday",  short = "Thu" },
    { key = "friday",    name = "Friday",    short = "Fri" },
    { key = "saturday",  name = "Saturday",  short = "Sat" },
    { key = "sunday",    name = "Sunday",    short = "Sun" },
}

NS.STATUSES = {
    { key = "new",       name = "New",       color = { T.rgb("ink") } },
    { key = "contacted", name = "Contacted", color = { T.rgb("slate") } },
    { key = "invited",   name = "Invited",   color = { T.rgb("accent") } },
    { key = "trial",     name = "Trial",     color = { T.rgb("gold") } },
    { key = "accepted",  name = "Accepted",  color = { T.rgb("good") } },
    { key = "declined",  name = "Declined",  color = { T.rgb("warn") } },
}

-- Fallback class colours; RAID_CLASS_COLORS is used when available.
local FALLBACK_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER  = { 0.67, 0.83, 0.45 }, ROGUE   = { 1.00, 0.96, 0.41 },
    PRIEST  = { 1.00, 1.00, 1.00 }, SHAMAN  = { 0.00, 0.44, 0.87 },
    MAGE    = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.58, 0.51, 0.79 },
    DRUID   = { 1.00, 0.49, 0.04 },
}

function U.ClassColor(fileName)
    if not fileName then return T.rgb("muted") end
    fileName = fileName:upper()
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[fileName]
    if c then return c.r, c.g, c.b end
    local f = FALLBACK_COLORS[fileName]
    if f then return f[1], f[2], f[3] end
    return T.rgb("muted")
end

function U.ClassHex(fileName)
    local r, g, b = U.ClassColor(fileName)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Localised class name -> file name, built lazily so we work in any locale.
local localizedToFile
function U.FileNameFromLocalized(localized)
    if not localized or localized == "" then return nil end
    if not localizedToFile then
        localizedToFile = {}
        if LOCALIZED_CLASS_NAMES_MALE then
            for file, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
                localizedToFile[name:lower()] = file
            end
        end
        if LOCALIZED_CLASS_NAMES_FEMALE then
            for file, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
                localizedToFile[name:lower()] = file
            end
        end
        for _, c in ipairs(NS.CLASSES) do
            localizedToFile[c.name:lower()] = c.file
        end
    end
    return localizedToFile[localized:lower()]
end

--------------------------------------------------------------------
-- Strings
--------------------------------------------------------------------

-- Alert sounds, BY SOUND KIT ID ONLY (21 Oct 2026, the review). This used to try a game FILE first, and
-- on Forever's engine PlaySoundFile with a game path plays nothing AND reports success - BiS Gamba lost an
-- evening to it on 17 Sep - so every alert, the default bell included (a file only), was silent and the
-- kit behind it was never tried. Kit ids from Wowhead's Classic sound data; UNVERIFIED in game until heard
-- (the options stepper plays each one as you pick it).
-- `short` is what the options stepper shows between its < and >: 48 px at 8 pt
-- is about nine characters, and a name trimmed to "Raid wa..." tells you
-- nothing. `name` is still the full one for tooltips and chat.
NS.SOUNDS = {
    { key = "none",     name = "No sound",          short = "none" },
    { key = "bell",     name = "Bell toll",         short = "bell",     kit = 6594 },   -- BellTollAlliance
    { key = "bell2",    name = "Bell, deeper",      short = "bell 2",   kit = 6595 },   -- BellTollHorde
    { key = "auction",  name = "Auction house",     short = "auction",  kit = 5274 },
    { key = "ping",     name = "Map ping",          short = "ping",     kit = 3175 },
    { key = "queue",    name = "Queue pop",         short = "queue",    kit = 8458 },
    { key = "levelup",  name = "Level up",          short = "level up", kit = 888 },
    { key = "murloc",   name = "Murloc",            short = "murloc",   kit = 416 },
    { key = "raidhorn", name = "Raid warning horn", short = "horn",     kit = 8959 },
    { key = "whisper",  name = "Whisper ding",      short = "whisper",  kit = 3081 },
}

--- The 1-based position of a sound key in the list, for the options stepper.
function U.SoundIndex(key)
    for i, sound in ipairs(NS.SOUNDS) do
        if sound.key == key then return i end
    end
    return 2
end

function U.SoundByKey(key)
    for _, sound in ipairs(NS.SOUNDS) do
        if sound.key == key then return sound end
    end
    return NS.SOUNDS[2]
end

function U.PlayAlert(key)
    local sound = U.SoundByKey(key)
    if not sound or sound.key == "none" then return end

    -- "Master" so it is heard even with sound effects turned down
    if not (sound.kit and PlaySound) then return end
    local ok, willPlay = pcall(PlaySound, sound.kit, "Master")
    if ok and willPlay ~= false then return true end
    pcall(PlaySound, sound.kit)
end

function U.Trim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- IS THIS HIDDEN BY THE GAME? (12 Oct 2026). On Forever a chat line - a whisper, a channel line,
--- a system line - can arrive SECRET while chat is locked down in an instance, and reading one is
--- an error, not a nil. Arn's BugSack the same evening: Questie, 46 times, "attempt to perform
--- string conversion on a secret string value" off CHAT_MSG_SYSTEM. BiSMemories hit it on 21 Sep
--- and asks first; so does this now. A client without the call hides nothing.
function U.Hidden(v)
    if v == nil or not issecretvalue then return false end
    local ok, yes = pcall(issecretvalue, v)
    return (not ok) or yes == true
end

function U.StripRealm(name)
    if type(name) ~= "string" then return "" end
    return (name:gsub("%-.*$", ""))
end

-- Splits a message so every piece fits in WoW's 255-character chat limit.
-- Breaks on separators / spaces where possible instead of mid-word.
function U.SplitMessage(text, limit)
    limit = limit or 255
    local out = {}
    text = U.Trim(text)
    if text == "" then return out end

    while #text > limit do
        local slice = text:sub(1, limit)
        -- Take the latest usable seam so each part is as full as possible.
        local cut = 0
        for _, pattern in ipairs({ ".*()%s%-%s", ".*(),%s", ".*()%s" }) do
            local found = slice:match(pattern)
            if found and found > cut then cut = found end
        end
        if cut < math.floor(limit * 0.5) then
            cut = limit + 1                        -- hard break, no good seam
        end
        table.insert(out, U.Trim(text:sub(1, cut - 1)))
        -- Drop the separator we broke on so the next part never starts with ", ".
        text = U.Trim(text:sub(cut):gsub("^[%s,%-]+", ""))
    end

    if text ~= "" then table.insert(out, text) end
    return out
end

-- "a, b, c" -> { "a", "b", "c" } (lowercased, blanks dropped)
function U.SplitList(s)
    local out = {}
    for word in tostring(s or ""):gmatch("[^,]+") do
        word = U.Trim(word):lower()
        if word ~= "" then table.insert(out, word) end
    end
    return out
end

-- Chat is for /slash answers only (the header law, BiSTheme 1.1.0). NS.Print is
-- what a slash command answers with; everything the addon wants to say about
-- what it is DOING goes through NS.Say, into the "BiS> _" prompt in the header.
function U.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(NS.T.text("accent", "BiS") .. " Nebbinator: " .. tostring(msg))
end

NS.Print = U.Print

-- Reached through NS.UI, never a bare local: the window loads after this file.
-- Before the window exists (an error at load) it falls back to chat rather than
-- swallowing the line.
function NS.Say(text, colour)
    local ui = NS.UI
    if ui and ui.con then
        ui.con:Say(text, colour)
    else
        U.Print(text)
    end
end

function U.TimeAgo(ts)
    if not ts then return "" end
    local d = time() - ts
    if d < 60 then return d .. "s ago" end
    if d < 3600 then return math.floor(d / 60) .. "m ago" end
    if d < 86400 then return math.floor(d / 3600) .. "h ago" end
    return math.floor(d / 86400) .. "d ago"
end

-- Recursive defaults fill: adds missing keys, never clobbers user values.
-- A LIST IS THE PLAYER'S (21 Oct 2026, the review): the templates and the quick replies are numbered
-- lists, and filling a deleted number back in from the defaults brought a template the player had removed
-- back at every login. A default that is a list only fills in when the player has no list at all.
local function isList(t) return type(t) == "table" and t[1] ~= nil end
function U.ApplyDefaults(target, source)
    if type(target) ~= "table" then target = {} end
    for k, v in pairs(source) do
        if isList(v) and type(target[k]) == "table" then
            -- the player's own list, as they left it
        elseif type(v) == "table" then
            target[k] = U.ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

function U.CopyTable(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = type(v) == "table" and U.CopyTable(v) or v
    end
    return out
end
