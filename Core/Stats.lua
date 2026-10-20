-- Nebbinator - Core/Stats.lua
-- WHAT ACTUALLY WORKS (21 Oct 2026, the review): every post is kept (when, where, which template), and a new
-- whisper within S.WINDOW of a post is credited to it. So: "Trade brought 8 whispers in 12 posts, General 2
-- in 10; Short beats Standard; evenings beat mornings". And THE REMINDER: S.REMIND minutes after your last
-- post, in a city, a small card offers the same post again - its button is a click, which the game needs.

local ADDON, NS = ...
local U = NS.Util

local S = {}
NS.Stats = S

S.WINDOW = 15 * 60          -- a whisper this soon after a post is that post's
S.KEEP = 300                -- posts kept

local function db()
    local st = NS.db.stats
    if type(st) ~= "table" then st = {} NS.db.stats = st end
    st.posts = type(st.posts) == "table" and st.posts or {}
    return st
end

local function Where(chatType, target)
    if chatType == "CHANNEL" then
        local _, name = GetChannelName(target)
        if type(name) == "string" then return (name:match("^([^%-]+)") or name):gsub("%s+$", "") end
        return "channel " .. tostring(target)
    end
    return chatType:lower()
end

--- A post went out (Message:Send). Kept, and the reminder set.
function S.Posted(chatType, target)
    local st = db()
    local tpl = NS.db.customEnabled and "custom" or ((NS.Message:ActiveTemplate() or {}).name or "?")
    table.insert(st.posts, 1, { at = time(), where = Where(chatType, target), tpl = tpl, whispers = 0,
                                chatType = chatType, target = target })
    for i = #st.posts, S.KEEP + 1, -1 do st.posts[i] = nil end
    S.Remind(chatType, target)
end

--- Somebody new whispered: credit the newest post inside the window.
function S.Whispered(name, now)
    now = now or time()
    for _, p in ipairs(db().posts) do
        if now - p.at <= S.WINDOW then p.whispers = (p.whispers or 0) + 1 return p end
        if now - p.at > S.WINDOW then break end
    end
    return nil
end

--- The posts, added up three ways: by where, by template, by the hour of the day (in four parts).
local PART = function(h) return (h < 6 and "night") or (h < 12 and "morning") or (h < 18 and "afternoon") or "evening" end
function S.Summary()
    local out = { where = {}, tpl = {}, part = {}, posts = 0, whispers = 0 }
    for _, p in ipairs(db().posts) do
        out.posts, out.whispers = out.posts + 1, out.whispers + (p.whispers or 0)
        local hour = tonumber(date("%H", p.at)) or 0
        for k, key in pairs({ where = p.where, tpl = p.tpl, part = PART(hour) }) do
            local b = out[k][key] or { posts = 0, whispers = 0 }
            b.posts, b.whispers = b.posts + 1, b.whispers + (p.whispers or 0)
            out[k][key] = b
        end
    end
    return out
end

--- One way of the summary as lines, best first: "Trade - 8 whispers from 12 posts".
function S.Lines(byWhat)
    local rows = {}
    for key, b in pairs(S.Summary()[byWhat] or {}) do rows[#rows + 1] = { key = key, b = b } end
    table.sort(rows, function(a, b)
        local ra, rb = a.b.whispers / math.max(1, a.b.posts), b.b.whispers / math.max(1, b.b.posts)
        if ra ~= rb then return ra > rb end
        return a.key < b.key
    end)
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = ("%s - %d whisper%s from %d post%s"):format(r.key, r.b.whispers, r.b.whispers == 1 and "" or "s",
            r.b.posts, r.b.posts == 1 and "" or "s")
    end
    return out
end

--- THE REMINDER: one, for the newest post; a later post moves it.
function S.Remind(chatType, target)
    local mins = tonumber(NS.db.remind) or 0
    if mins <= 0 then return end
    S.remindN = (S.remindN or 0) + 1                             -- a count, not the clock: two posts in one second
    local stamp = S.remindN
    S.remindFor = stamp
    C_Timer.After(mins * 60, function()
        if S.remindFor ~= stamp then return end                  -- posted again since
        if IsResting and not IsResting() then return end         -- not in a city or an inn
        if NS.Cards and NS.Cards.Remind then NS.Cards.Remind(mins, chatType, target, Where(chatType, target)) end
    end)
end
