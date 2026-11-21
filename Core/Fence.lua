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
-- The key is the guild's NAME ALONE; a character with no guild has its own book ("-").
-- Templates, quick replies, the auto-reply's words and every setting stay the account's: they speak
-- through tokens ({guild}, {discord}, {needs}), which read the live book.
--
-- NO REALM (Forever 1.60.1 Live Update 2, 21 Nov 2026, permanent): GetRealmName, GetRealmID, GetGuildInfo's
-- realm and C_BattleNet answer "" or 0. The key was "Name-Realm" and became "Name-?" overnight, so Settle
-- PARKED the real book and opened a fresh empty one. Two keys of one guild had split a book before that too
-- ("CAMWOW US1 Realm 2 PvP" and "CAMWOWUS1Realm6PvP"). Now: the key is the guild's name, and every book of
-- the realm days whose key is "<Name>-<anything>" is the SAME guild. The first login of that guild after
-- this version JOINS them into one live book (F.Join, rules beside it) and moves every one of them, as it
-- was, into db.guildsWithRealm - never read again, never deleted, there for a hand to reach in if ever.
-- It runs once: afterwards no "<Name>-..." book is left in db.guilds, so there is nothing to join.

local ADDON, NS = ...
local U = NS.Util

local F = {}
NS.Fence = F

F.KEYS = { "needs", "needsAt", "needsBy", "raidTimes", "discord", "guildName", "content", "preText", "postText",
           "customEnabled", "customText", "responders", "team", "stats", "scoutSeen" }
F.NONE = "-"
F.ASIDE = "guildsWithRealm"     -- db.guildsWithRealm: the realm days' books, moved aside by F.Join, as they were
-- the words a person types: the newest book where somebody changed them from the default wins
F.PLAIN = { "raidTimes", "discord", "guildName", "content", "preText", "postText", "customEnabled", "customText" }

local function plain(v) if U.Hidden(v) or type(v) ~= "string" or v == "" then return nil end return v end

--- This character's guild by name ("The Heathens"), "-" with none, or nil while the game has not said yet.
--- No realm in it: Forever stopped telling addons the realm on 21 Nov 2026, so a realm in the key would
--- split the book again the day it came back or changed its spelling.
function F.Key()
    if not (IsInGuild and IsInGuild()) then return F.NONE end
    return plain((GetGuildInfo("player")))
end

--- Is `old` a realm-days key of the guild `key` ("The Heathens-Dreamscythe", "The Heathens-?")?
--- A plain prefix compare - no pattern, so a guild name with % . - ( in it cannot misfire.
function F.Realmed(old, key)
    if type(old) ~= "string" or type(key) ~= "string" or key == F.NONE then return false end
    return #old > #key + 1 and old:sub(1, #key + 1) == key .. "-"
end

function F.Ready() return F.ready == true end

--------------------------------------------------------------------
-- JOINING the realm days' books of one guild
--------------------------------------------------------------------

local function copy(v) if type(v) == "table" then return U.CopyTable(v) end return v end

-- changed from the default? A table is changed when any value in it is; a key the default has and the book
-- lacks is not a change (an older book never wrote it).
local function edited(v, def)
    if v == nil then return false end
    if type(v) == "table" and type(def) == "table" then
        for k, x in pairs(v) do if edited(x, def[k]) then return true end end
        return false
    end
    return v ~= def
end

-- the last thing that happened in a book: a whisper, a prospect, a post, a scout card, the needs
local function lastAt(b)
    local n = tonumber(b.needsAt) or 0
    for _, r in pairs(type(b.responders) == "table" and b.responders or {}) do
        if type(r) == "table" then n = math.max(n, tonumber(r.timestamp) or 0) end
    end
    for _, r in pairs(type(b.team) == "table" and b.team or {}) do
        if type(r) == "table" then n = math.max(n, tonumber(r.at) or 0) end
    end
    local posts = type(b.stats) == "table" and type(b.stats.posts) == "table" and b.stats.posts or {}
    for _, p in ipairs(posts) do if type(p) == "table" then n = math.max(n, tonumber(p.at) or 0) end end
    for _, at in pairs(type(b.scoutSeen) == "table" and b.scoutSeen or {}) do n = math.max(n, tonumber(at) or 0) end
    return n
end

-- one person on two desks: the newer row, keeping what the older one knew and the newer lacks
local function joinRow(a, b)
    local new, old = a, b
    if (tonumber(b.timestamp) or 0) > (tonumber(a.timestamp) or 0) then new, old = b, a end
    local row = copy(new)
    -- a whisper after the split ("new") does not undo "contacted" from before it
    if (row.status or "new") == "new" and old.status and old.status ~= "new" then row.status = old.status end
    if U.Trim(row.note) == "" and U.Trim(old.note) ~= "" then row.note = old.note end
    for _, k in ipairs({ "class", "level", "guild", "sentReplies" }) do
        if row[k] == nil and old[k] ~= nil then row[k] = copy(old[k]) end
    end
    local seen, msgs = {}, {}
    for _, src in ipairs({ old.messages, new.messages }) do
        for _, m in ipairs(type(src) == "table" and src or {}) do
            local id = tostring(m.at) .. "\0" .. tostring(m.text)
            if not seen[id] then seen[id] = true msgs[#msgs + 1] = copy(m) end
        end
    end
    table.sort(msgs, function(x, y) return (tonumber(x.at) or 0) < (tonumber(y.at) or 0) end)
    row.messages = msgs
    return row
end

--- Join books of one guild into one. `list` = { {key=, book=}, ... } OLDEST FIRST. Nothing in `list` is changed.
--- THE RULES (21 Nov 2026):
---   words (F.PLAIN: raid times, Discord, guild name, content, pre/post, custom text and its switch) - the
---     newest book that CHANGED them from the default. The fresh book the bug opened holds the defaults, so the
---     real words come back - unless somebody typed new ones into it since, then those stay.
---   needs - the newest officer stamp (needsAt) wins, with its needsAt/needsBy; no stamp anywhere: as the words.
---   desk (responders) - everybody from every book; one person on two: the newer row, the older's status if
---     the newer is still "new", the note, class and every message of both (each once, oldest first).
---   the guild's list (team) - everybody; one person on two: the newer `at`, as Team takes a REC.
---   scout cards (scoutSeen) - everybody, the latest time.
---   stats - every post once (the same when, where, template and channel is the same post), newest first,
---     capped like Stats keeps them; nothing is added up twice.
function F.Join(list)
    local fresh = NS.Defaults()
    local out = {}
    for _, k in ipairs(F.PLAIN) do
        out[k] = copy(fresh[k])
        for _, c in ipairs(list) do
            if edited(c.book[k], fresh[k]) then out[k] = copy(c.book[k]) end
        end
        if type(fresh[k]) == "table" then out[k] = U.ApplyDefaults(out[k], fresh[k]) end
    end

    local stamped
    for _, c in ipairs(list) do
        local at = tonumber(c.book.needsAt)
        if at and type(c.book.needs) == "table" and (not stamped or at >= (tonumber(stamped.needsAt) or 0)) then
            stamped = c.book
        end
    end
    if stamped then
        out.needs, out.needsAt, out.needsBy = copy(stamped.needs), stamped.needsAt, stamped.needsBy
    else
        out.needs = copy(fresh.needs)
        for _, c in ipairs(list) do
            if edited(c.book.needs, fresh.needs) then out.needs = copy(c.book.needs) end
        end
    end
    out.needs = U.ApplyDefaults(out.needs, fresh.needs)

    out.responders, out.team, out.scoutSeen = {}, {}, {}
    out.stats = { posts = {}, whispers = {} }
    local seenPost = {}
    for _, c in ipairs(list) do
        local b = c.book
        for name, r in pairs(type(b.responders) == "table" and b.responders or {}) do
            if type(r) == "table" then
                out.responders[name] = out.responders[name] and joinRow(out.responders[name], r) or copy(r)
            end
        end
        for name, r in pairs(type(b.team) == "table" and b.team or {}) do
            local have = out.team[name]
            if type(r) == "table" and (not have or (tonumber(r.at) or 0) >= (tonumber(have.at) or 0)) then
                out.team[name] = copy(r)
            end
        end
        for name, at in pairs(type(b.scoutSeen) == "table" and b.scoutSeen or {}) do
            if (tonumber(at) or 0) >= (tonumber(out.scoutSeen[name]) or 0) then out.scoutSeen[name] = at end
        end
        local st = type(b.stats) == "table" and b.stats or {}
        for _, p in ipairs(type(st.posts) == "table" and st.posts or {}) do
            if type(p) == "table" then
                local id = table.concat({ tostring(p.at), tostring(p.where), tostring(p.tpl),
                                          tostring(p.chatType), tostring(p.target) }, "\0")
                if not seenPost[id] then
                    seenPost[id] = true
                    out.stats.posts[#out.stats.posts + 1] = copy(p)
                end
            end
        end
        for k, v in pairs(type(st.whispers) == "table" and st.whispers or {}) do out.stats.whispers[k] = copy(v) end
    end
    table.sort(out.stats.posts, function(x, y) return (tonumber(x.at) or 0) > (tonumber(y.at) or 0) end)
    local keep = (NS.Stats and NS.Stats.KEEP) or 300
    for i = #out.stats.posts, keep + 1, -1 do out.stats.posts[i] = nil end
    return out
end

--- The realm days' books of THIS guild (live or parked) joined into one, under the name-only key: live if the
--- live book was this guild's, else parked in db.guilds[key] for the swap below to bring out. Answers how
--- many books were joined (0 = nothing to do - every login after the first).
function F.Gather(db, key)
    if key == F.NONE then return 0 end
    local realmed = 0
    for k in pairs(db.guilds) do if F.Realmed(k, key) then realmed = realmed + 1 end end
    local liveOurs = db.guildKey == key or F.Realmed(db.guildKey, key)
    if F.Realmed(db.guildKey, key) then realmed = realmed + 1 end
    if realmed == 0 then return 0 end

    local list = {}
    for k, b in pairs(db.guilds) do
        if type(b) == "table" and (k == key or F.Realmed(k, key)) then
            -- the bug's own book ("<Name>-?") is younger than any book with a real realm in its key
            list[#list + 1] = { key = k, book = b, rank = (k:sub(-2) == "-?") and 1 or 0, at = lastAt(b) }
        end
    end
    if liveOurs then
        local live = {}
        for _, k in ipairs(F.KEYS) do live[k] = db[k] end
        list[#list + 1] = { key = db.guildKey, book = live, rank = 2, at = lastAt(live) }   -- live last = newest
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.at ~= b.at then return a.at < b.at end
        return a.key < b.key
    end)
    local joined = F.Join(list)

    -- every one of them moves aside AS IT WAS (the live one's own tables, which the joined copy no longer uses)
    db[F.ASIDE] = type(db[F.ASIDE]) == "table" and db[F.ASIDE] or {}
    local aside = db[F.ASIDE]
    for _, c in ipairs(list) do
        local k, n = c.key, 1
        while aside[k] ~= nil do n = n + 1 k = c.key .. " #" .. n end
        aside[k] = c.book
        db.guilds[c.key] = nil
    end
    if liveOurs then
        for _, k in ipairs(F.KEYS) do db[k] = joined[k] end
        db.guildKey = key
    else
        db.guilds[key] = joined
    end
    F.joined = #list
    if NS.Say then
        NS.Say(("%d guild books from before Forever hid the realm joined into one for <%s>"):format(#list, key), "good")
    end
    return #list
end

--- Make the live book this guild's. Answers true once the guild is known; a change of guild swaps books.
function F.Settle()
    local db = NS.db
    if not db then return false end
    local key = F.Key()
    if not key then F.ready = false return false end
    db.guilds = type(db.guilds) == "table" and db.guilds or {}
    -- the first time (a save from before the fence): what is here belongs to the first guild that logs in
    if db.guildKey == nil then db.guildKey = key end
    local changed = F.Gather(db, key) > 0
    if db.guildKey ~= key then
        changed = true
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
    end
    if changed and NS.UI and NS.UI.frame then NS.UI:Refresh() NS.UI:OnDataChanged() end
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
