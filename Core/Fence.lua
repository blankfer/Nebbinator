-- Nebbinator - Core/Fence.lua
-- FENCED INTO THE GUILD (Arn, 21 Oct 2026: "we gotta keep a fence into the guild, so if someone logs into an
-- alt with the Nebbinator addon, it's not spilling over to other guilds"). NebbinatorDB is the ACCOUNT's -
-- every character reads the same file. So everything that belongs to a guild (its needs, raid times, Discord,
-- the desk, the guild's list of prospects, what works) lives in a BOOK per guild, and only the book of the
-- guild this character is in is ever live in NS.db. Log onto an alt in another guild: the main's book is
-- parked in db.guilds, the alt's own comes out (a fresh one the first time). Nothing else reads db.guilds.
--
-- Until the game says which guild this is (GetGuildInfo answers nil for a few seconds after login), the
-- fence is SHUT: Team neither sends nor takes, the scout raises no card (F.Ready()).
-- The key is the guild's name and realm; a character with no guild has its own book ("-").
-- Templates, quick replies, the auto-reply's words and every setting stay the account's: they speak
-- through tokens ({guild}, {discord}, {needs}), which read the live book.

local ADDON, NS = ...
local U = NS.Util

local F = {}
NS.Fence = F

F.KEYS = { "needs", "needsAt", "needsBy", "raidTimes", "discord", "guildName", "content", "preText", "postText",
           "customEnabled", "customText", "responders", "team", "stats", "scoutSeen" }
F.NONE = "-"

local function plain(v) if U.Hidden(v) or type(v) ~= "string" or v == "" then return nil end return v end

--- This character's guild as "Name-Realm", "-" with none, or nil while the game has not said yet.
function F.Key()
    if not (IsInGuild and IsInGuild()) then return F.NONE end
    local name, _, _, realm = GetGuildInfo("player")
    name = plain(name)
    if not name then return nil end
    return name .. "-" .. (plain(realm) or plain(GetRealmName and GetRealmName()) or "?")
end

function F.Ready() return F.ready == true end

--- Make the live book this guild's. Answers true once the guild is known; a change of guild swaps books.
function F.Settle()
    local db = NS.db
    if not db then return false end
    local key = F.Key()
    if not key then F.ready = false return false end
    db.guilds = type(db.guilds) == "table" and db.guilds or {}
    -- the first time (a save from before the fence): what is here belongs to the first guild that logs in
    if db.guildKey == nil then db.guildKey = key end
    if db.guildKey ~= key then
        local park = {}
        for _, k in ipairs(F.KEYS) do park[k] = db[k] end
        db.guilds[db.guildKey] = park
        local book = db.guilds[key] or {}
        db.guilds[key] = nil
        local fresh = NS.Defaults()
        for _, k in ipairs(F.KEYS) do
            if book[k] ~= nil then db[k] = book[k] else db[k] = fresh[k] end
        end
        db.guildKey = key
        F.swapped = (F.swapped or 0) + 1
        -- whatever the last guild's roster said is not this one's
        if NS.Responders then NS.Responders.rosterDirty = true NS.Responders.guildRanks = nil end
        if NS.Team then NS.Team.lastNeedsHeard = nil end
        if NS.UI and NS.UI.frame then NS.UI:Refresh() NS.UI:OnDataChanged() end
    end
    F.ready = true
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_GUILD_UPDATE")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event)
    if not NS.db then return end
    -- the roster fires all evening; once the guild is known only joining or leaving one matters
    if event == "GUILD_ROSTER_UPDATE" and F.ready then return end
    F.Settle()
end)
F.frame = f
