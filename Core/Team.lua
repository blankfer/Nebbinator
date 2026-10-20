-- Nebbinator - Core/Team.lua
-- THE GUILD'S DESK (Arn, 21 Oct 2026): "add potential recruits and people contacted to the BiS guild in a
-- list so officers can see and maybe officers can tell what we need and it updates everyone's Nebbinator";
-- then "a crest shared to the guild ... so if another person parties with them they know to nudge them".
--
-- On the shared BiS channel, GUILD only (LibBiSComm's guild-scoped MOD "NEB"):
--   REC   name status class level by at note   - a desk row changed (anyone sends; one line per change).
--                                               Officers keep the summary (Arn's pick: "summary only" -
--                                               never what the recruit whispered); everyone else keeps
--                                               only who is a prospect and who is talking to them, for the
--                                               crest and the party scout.
--   NEEDS stamp needs                          - an officer set what the guild needs; every Nebbinator in
--                                               the guild takes the newest one an officer sent (Arn's pick:
--                                               officers only).
--   ASK   what                                 - at login: "N" asks for the needs, "R" (officers) asks for
--                                               everyone's desk. Answers are capped: the channel carries
--                                               about one BiS message a second for every addon together.
-- Officers are guild ranks 0..db.officerRank (1 by default - BiS Guild's rule and number).

local ADDON, NS = ...
local U = NS.Util

local T = {}
NS.Team = T

T.MOD = "NEB"
T.KEEP_DAYS = 30           -- a prospect nobody has touched for this long leaves the guild's list
T.ANSWER_MAX = 15          -- desk rows one client sends back to an officer's ASK
T.NOTE_MAX = 60

local function Lib() return _G.LibBiSComm end
local function db() return NS.db end

--------------------------------------------------------------------
-- who is an officer
--------------------------------------------------------------------

--- The rank index (0 = guild master) of a guildmate, or nil when they are not in the guild roster.
--- A FIRST NAME ALONE ("Arn", from an older client's message) finds the one roster name it begins - the
--- online one when several do (BiS Guild's X.Rank, the same rule); a whole name must match whole.
function T.Rank(name)
    local R = NS.Responders
    if R.rosterDirty or not R.guildRanks then
        R.rosterDirty = nil
        R:RefreshGuildRoster()
    end
    local key = U.StripRealm(name or ""):lower()
    local ranks = R.guildRanks or {}
    if ranks[key] ~= nil then return ranks[key] end
    if key == "" or key:find(" ", 1, true) then return nil end
    local found
    for whole, rank in pairs(ranks) do
        if whole:match("^(%S+)") == key then
            if found ~= nil then return nil end             -- two of them: not guessed
            found = rank
        end
    end
    return found
end

function T.IsOfficer(name)
    local rank = T.Rank(name or T.Me())
    return rank ~= nil and rank <= (tonumber(db().officerRank) or 1)
end

function T.Me() return U.WholeName("player") or "?" end

--------------------------------------------------------------------
-- the guild's list
--------------------------------------------------------------------

function T.List()
    db().team = type(db().team) == "table" and db().team or {}
    return db().team
end

local function clean(s, max)
    s = tostring(s or ""):gsub("[\r\n]", " ")
    if max and #s > max then s = s:sub(1, max) end
    return s
end

--- A desk row changed here: tell the guild (REC). Called by Responders on every change that matters.
function T.Changed(entry)
    if type(entry) ~= "table" or not entry.name then return false end
    if not NS.Fence.Ready() then return false end                   -- which guild's? not known yet
    -- my own copy first, so the officer who is also the recruiter sees it at once
    T.Took(T.Me(), entry.name, entry.status, entry.class, entry.level, T.Me(), entry.timestamp or time(), entry.note)
    local lib = Lib()
    if not (lib and lib.SendTo and IsInGuild and IsInGuild()) then return false end
    return lib:SendTo("GUILD", T.MOD, "REC", clean(entry.name, 48), entry.status or "new", entry.class or "",
        tostring(entry.level or ""), T.Me(), tostring(entry.timestamp or time()), clean(entry.note, T.NOTE_MAX)) and true
end

--- A REC heard (or our own): kept in full by an officer, as a prospect by everyone else.
function T.Took(sender, name, status, class, level, by, at, note)
    if type(name) ~= "string" or name == "" then return nil end
    if not NS.Fence.Ready() then return nil end
    local key = U.StripRealm(name)
    local L = T.List()
    local old = L[key]
    at = tonumber(at) or time()
    if old and (old.at or 0) > at then return old end                -- an older word about them
    local row = { name = key, status = status or "new", by = U.StripRealm(by or sender or "?"), at = at }
    if T.IsOfficer() then
        row.class = (class ~= "" and class) or nil
        row.level = tonumber(level)
        row.note = (note ~= "" and note) or nil
    end
    L[key] = row
    if NS.UI and NS.UI.OnTeamChanged then NS.UI:OnTeamChanged() end
    if NS.APIFire then NS.APIFire("Nebbinator_TeamChanged", key) end
    return row
end

--- Is this name somebody the guild is talking to? -> true, who, status (the crest, the party scout).
--- Joined (accepted) or declined is not a prospect any more.
function T.Prospect(name)
    local row = T.List()[U.StripRealm(name or "")]
    if not row or row.status == "accepted" or row.status == "declined" then return false end
    if time() - (row.at or 0) > T.KEEP_DAYS * 86400 then return false end
    return true, row.by, row.status
end

function T.Tidy(now)
    now = now or time()
    local L, gone = T.List(), 0
    for k, row in pairs(L) do
        if now - (row.at or 0) > T.KEEP_DAYS * 86400 then L[k] = nil gone = gone + 1 end
    end
    return gone
end

--------------------------------------------------------------------
-- what the guild needs
--------------------------------------------------------------------

--- The needs as one line: "shaman.resto=2,druid.feral=1" (only the ones above 0).
function T.Pack(needs)
    local parts = {}
    for _, class in ipairs(NS.CLASSES) do
        for _, spec in ipairs(class.specs) do
            local n = tonumber(needs[class.key] and needs[class.key][spec.key]) or 0
            if n > 0 then parts[#parts + 1] = class.key .. "." .. spec.key .. "=" .. n end
        end
    end
    return table.concat(parts, ",")
end

--- The line back into a needs table (every known spec present, 0 unless named).
function T.Unpack(line)
    local out = {}
    for _, class in ipairs(NS.CLASSES) do
        out[class.key] = {}
        for _, spec in ipairs(class.specs) do out[class.key][spec.key] = 0 end
    end
    for c, s, n in tostring(line or ""):gmatch("(%a+)%.(%a+)=(%d+)") do
        if out[c] and out[c][s] then out[c][s] = math.min(9, tonumber(n)) end
    end
    return out
end

--- An officer sets the needs for the guild. Answers true, or nil and why.
function T.SetNeeds(needs, quiet)
    if not NS.Fence.Ready() then return nil, "the guild is not known yet" end
    if not T.IsOfficer() then return nil, "officers only" end
    local stamp = (GetServerTime and GetServerTime()) or time()
    local line = T.Pack(needs or db().needs)
    T.Adopt(T.Me(), stamp, line)
    local lib = Lib()
    if lib and lib.SendTo and IsInGuild and IsInGuild() then lib:SendTo("GUILD", T.MOD, "NEEDS", tostring(stamp), line) end
    if not quiet then NS.Say("the guild's needs sent to everyone", "good") end
    return true
end

--- Needs heard from an officer: the newest wins, and the ad follows.
function T.Adopt(sender, stamp, line)
    stamp = tonumber(stamp)
    if not NS.Fence.Ready() then return false end
    if not stamp or not T.IsOfficer(sender) then return false end
    if stamp <= (tonumber(db().needsAt) or 0) then return false end
    db().needs = T.Unpack(line)
    db().needsAt, db().needsBy = stamp, U.StripRealm(sender)
    if NS.UI and NS.UI.Refresh then NS.UI:Refresh() end
    if U.StripRealm(sender) ~= T.Me() then NS.Say("needs set by " .. U.StripRealm(sender), "gold") end
    if NS.APIFire then NS.APIFire("Nebbinator_NeedsChanged", U.StripRealm(sender)) end
    return true
end

--------------------------------------------------------------------
-- the channel
--------------------------------------------------------------------

function T.OnAsk(sender, what)
    local lib = Lib()
    if not (lib and lib.SendTo) or U.StripRealm(sender) == T.Me() then return end
    if not NS.Fence.Ready() then return end
    if what == "N" and T.IsOfficer() and db().needsAt then
        -- the newest needs this officer knows, after a moment (another officer may answer first)
        local at = db().needsAt
        C_Timer.After(1 + math.random() * 3, function()
            if db().needsAt == at and (T.lastNeedsHeard or 0) < at then
                lib:SendTo("GUILD", T.MOD, "NEEDS", tostring(at), T.Pack(db().needs))
            end
        end)
    elseif what == "R" and T.IsOfficer(sender) then
        local list = NS.Responders:SortedList("all")
        for i = 1, math.min(#list, T.ANSWER_MAX) do
            local e = list[i]
            lib:SendTo("GUILD", T.MOD, "REC", clean(e.name, 48), e.status or "new", e.class or "",
                tostring(e.level or ""), T.Me(), tostring(e.timestamp or time()), clean(e.note, T.NOTE_MAX))
        end
    end
end

function T.Boot()
    local lib = Lib()
    if T.booted or not (lib and lib.RegisterHandler) then return end
    T.booted = true
    if lib.RegisterGuildMod then lib:RegisterGuildMod(T.MOD) end
    lib:RegisterHandler(T.MOD, "REC", function(sender, ...) T.Took(sender, ...) end)
    lib:RegisterHandler(T.MOD, "NEEDS", function(sender, stamp, line)
        T.lastNeedsHeard = math.max(T.lastNeedsHeard or 0, tonumber(stamp) or 0)
        T.Adopt(sender, stamp, line)
    end)
    lib:RegisterHandler(T.MOD, "ASK", function(sender, what) T.OnAsk(sender, what) end)
    T.Tidy()
    -- a moment after login: the guild's needs, and (an officer) everyone's desk
    -- (and only once the fence knows which guild this is: a few tries, then it waits for the next login)
    local tries = 0
    local function ask()
        if not (IsInGuild and IsInGuild() and lib.SendTo) then return end
        if not NS.Fence.Ready() then
            tries = tries + 1
            if tries < 6 then C_Timer.After(10, ask) end
            return
        end
        lib:SendTo("GUILD", T.MOD, "ASK", "N")
        if T.IsOfficer() then lib:SendTo("GUILD", T.MOD, "ASK", "R") end
    end
    C_Timer.After(10, ask)
end
