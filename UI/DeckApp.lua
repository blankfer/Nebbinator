--[[ Nebbinator :: UI/DeckApp.lua - THE RECRUITING DESK ON THE PHONE (22 Nov 2026).

  Arn, 22 Nov: "start nebbinator" - the mock's plan (https://claude.ai/artifact/HZHvD2uqp3iG6bpPQTwREu) and its pick: posting the ad
  from the phone, YES ("one click posts one line to one channel, the same as today"). The phone is BiSTheme's deck (it comes with
  BiS Tools): an app hands in DATA, never a frame. Without it nothing here runs. Everything is the desk's own: the responders
  (R:SortedList), the four quick replies (R:SendQuickReply), the invites (R:InviteToGuild / R:InviteToGroup), the status words
  (R:SetStatus), the ad (M:Build) and its send (M:Send - one part per click on a public channel, as the send bar), the stats.

   DESK      everybody who whispered, newest first, in their class's colour; one opens to their words and your ready answers
   AD        the ad as it will post, and where it can go now (POST / the seconds to wait / 2/2 for a long one)
   STATS     what works: where, which ad, what time of day
   SETTINGS  the options window's own switches, and the door to the desk window

  THE CARD: NEW RECRUIT while somebody new waits (REPLY, INVITE).
]]
local ADDON, NS = ...
local A = {}
NS.DeckApp = A
local ID = ADDON .. ":desk"

local function plain(v)
    if v == nil then return nil end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return nil end
    end
    return v
end
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return plain(a), plain(b) end
end
local function Deck()
    local T = _G.BiSTheme
    return type(T) == "table" and T.Deck or nil
end
local function now() return ask(time) or 0 end
local function ago(t)
    t = tonumber(t)
    if not t then return "" end
    local s = math.max(0, now() - t)
    if s < 60 then return "now" elseif s < 3600 then return math.floor(s / 60) .. " m" elseif s < 86400 then return math.floor(s / 3600) .. " h" end
    return math.floor(s / 86400) .. " d"
end
local function cap(s) s = tostring(s or "") return s:sub(1, 1):upper() .. s:sub(2):lower() end
local function R() return NS.Responders end
local function M() return NS.Message end

A.WORD = { new = "NEW", contacted = "TALKED", invited = "INVITED", trial = "TRIAL", accepted = "JOINED", declined = "NO" }
A.INK = { new = "gold", contacted = "accent", invited = "good", trial = "good", accepted = "good", declined = "dim" }

--- Their class as a token ("MAGE"), from what the desk kept.
local function token(e)
    local c = e.classFile or e.class
    c = type(c) == "string" and c:upper():gsub("%s", "") or nil
    return c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c] and c or (c and c:match("^%u+$")) or nil
end
local function list()
    local ok, l = pcall(function() return R():SortedList("all") end)
    return ok and type(l) == "table" and l or {}
end
local function lastWords(e)
    local m = type(e.messages) == "table" and e.messages[#e.messages] or nil
    return m and type(m.text) == "string" and m.text or nil
end

-- one recruit's page
local pick                                     -- a name
local function open(name) pick = name end
local function entry(name) return NS.db and NS.db.responders and NS.db.responders[name] or nil end

local function recruitRows(e)
    local out = { { mark = "<", text = "Back", act = { word = "back", peek = true, fn = function() pick = nil end } } }
    local msgs = type(e.messages) == "table" and e.messages or {}
    out[#out + 1] = { head = true, text = "THEIR WORDS", right = #msgs > 0 and tostring(#msgs) or "" }
    for i = math.max(1, #msgs - 2), #msgs do
        local m = msgs[i]
        if m then out[#out + 1] = { mark = "-", text = tostring(m.text or ""), right = ago(m.at), ink = "ink2" } end
    end
    if #msgs == 0 then out[#out + 1] = { mark = "-", text = "seen asking for a guild", done = true } end
    out[#out + 1] = { head = true, text = "YOUR ANSWER", right = "" }
    local sent = type(e.sentReplies) == "table" and e.sentReplies or {}
    for i, r in ipairs(NS.db.quickReplies or {}) do
        local text = NS.Util.Trim(r.text or "")
        if text ~= "" then
            local label = NS.Util.Trim(r.label or "") ~= "" and r.label or ("reply " .. i)
            out[#out + 1] = { text = cap(label), sub = text, right = sent[i] and "SENT" or nil, ink = sent[i] and "good" or nil, verb = "SEND",
                tip = "Whispers it to " .. e.name, act = { word = "SEND", fn = function() R():SendQuickReply(e.name, i) end } }
        end
    end
    if NS.Util.Trim(NS.db.discord or "") ~= "" then
        out[#out + 1] = { text = "The Discord link", verb = "SEND", act = { word = "SEND", fn = function() R():SendDiscord(e.name) end } }
    end
    return out
end
local function recruitBoxes(e)
    return { { "LEVEL", e.level or "?", "ink" }, { "CLASS", e.class and cap(e.class) or "?", token(e) or "ink2" },
        { "GUILD", e.guild or "?", e.guild == "No guild" and "good" or "ink2" } }
end
local function recruitKeys(e)
    local out = {}
    if e.status ~= "trial" then out[#out + 1] = { word = "TRIAL", fn = function() R():SetStatus(e.name, "trial") end } end
    if e.status ~= "declined" then out[#out + 1] = { word = "DECLINE", fn = function() R():SetStatus(e.name, "declined") end } end
    out[#out + 1] = { word = "WHISPER", peek = true, tip = "Opens a whisper to them", fn = function() R():WhisperTo(e.name) end }
    return out
end

-- the tabs
local function deskRows()
    local out = {}
    local D = Deck()
    for _, e in ipairs(list()) do
        local tk = token(e)
        local pic, co
        if D and D.ClassPic then pic, co = D.ClassPic(tk) end
        local bits = {}
        if e.level then bits[#bits + 1] = tostring(e.level) end
        if e.class then bits[#bits + 1] = cap(e.class) end
        local words = lastWords(e)
        local subw = table.concat(bits, " ") .. (words and ((#bits > 0 and ": " or "") .. words) or "")
        out[#out + 1] = { pic = pic, coords = co, mark = not pic and "-" or nil, text = e.name, tint = e.status == "declined" and nil or tk,
            sub = subw ~= "" and subw or nil, right = (A.WORD[e.status] or tostring(e.status or "")) .. " " .. ago(e.timestamp), ink = A.INK[e.status] or "ink2",
            done = e.status == "declined" or nil, act = { word = "open", peek = true, fn = function() open(e.name) end } }
    end
    return out
end
local function deskBoxes()
    local n = { new = 0, contacted = 0, trial = 0, invited = 0 }
    for _, e in ipairs(list()) do if n[e.status] then n[e.status] = n[e.status] + 1 end end
    return { { "NEW", n.new, n.new > 0 and "gold" or "dim" }, { "TALKED", n.contacted, "accent" }, { "INVITED", n.invited, "good" }, { "TRIAL", n.trial, "good" } }
end
local function adText()
    local ok, t = pcall(function() return M():Build() end)
    return ok and type(t) == "string" and t or ""
end
local function adRows()
    local out = {}
    local ok, targets = pcall(function() return NS.UI:SendTargets() end)
    for _, t in ipairs(ok and targets or {}) do
        -- (the send bar's own clock: LastSendTime knows a channel by its number, as the send keeps it)
        local cooldown = tonumber(NS.db.sendCooldown) or 10
        local last = M():LastSendTime(t.chatType, t.target)
        local since = last and ((ask(GetTime) or 0) - last) or nil
        local can = not since or since >= cooldown
        local wait = since and math.ceil(cooldown - since) or 0
        local part = M():PendingFor(t.chatType, t.target)
        local word = part or (can and "POST" or "WAIT")
        out[#out + 1] = { text = t.label, right = not can and (wait .. " s") or (part and "next part") or "", ink = can and "good" or "dim",
            verb = word, tip = t.tip, act = can and { word = word, fn = function() M():Send(t.chatType, t.target) end } or nil }
    end
    return out
end
local function adBoxes()
    local text = adText()
    return { { "LETTERS", #text, #text > 255 and "warn" or "ink" }, { "PREVIEW", NS.db.preview and "ON" or "OFF", NS.db.preview and "warn" or "good" },
        { "WAIT", (tonumber(NS.db.sendCooldown) or 10) .. " s", "ink2" } }
end
local function stats()
    local ok, s = pcall(function() return NS.Stats.Summary() end)
    return ok and type(s) == "table" and s or nil
end
local function statRows()
    local out = {}
    for _, how in ipairs({ { "where", "WHERE" }, { "tpl", "WHICH AD" }, { "part", "WHEN" } }) do
        local ok, lines = pcall(NS.Stats.Lines, how[1])
        if ok and type(lines) == "table" and #lines > 0 then
            out[#out + 1] = { head = true, text = how[2], right = "whispers / posts" }
            for i, l in ipairs(lines) do
                local key, w, p = l:match("^(.-)%s%s(%d+) / (%d+)$")
                out[#out + 1] = { mark = tostring(i), text = key or l, right = w and (w .. " / " .. p) or "", ink = i == 1 and "gold" or "ink2", tint = i == 1 and "gold" or nil }
            end
        end
    end
    return out
end
local function statBoxes()
    local s = stats()
    if not s or s.posts == 0 then return {} end
    return { { "POSTS", s.posts, "accent" }, { "WHISPERS", s.whispers, s.whispers > 0 and "good" or "dim" },
        { "PER POST", ("%.1f"):format(s.whispers / math.max(1, s.posts)), "gold" } }
end
local function settingRows()
    local out = {}
    local ok, o = pcall(function() return NS.UI:OptionTables() end)
    for _, k in ipairs({ "preview", "autoReply", "classAware", "busy", "sound", "soundOnlyNew", "leadFinder", "scout", "minimap", "channel" }) do
        local opt = ok and o[k]
        if opt and opt.kind == "toggle" then
            local is = opt.get(NS.db) and true or false
            out[#out + 1] = { text = cap(opt.label), right = is and "ON" or "OFF", ink = is and "good" or "dim", tip = opt.help,
                act = { word = "switch", chip = true, fn = function() opt.set(NS.db, not opt.get(NS.db)) end } }
        end
    end
    out[#out + 1] = { head = true, text = "THE WINDOWS", right = "" }
    out[#out + 1] = { text = "The desk window", verb = "OPEN", act = { word = "OPEN", peek = true, fn = function() if NebbinatorAPI then NebbinatorAPI.Open("Desk") end end } }
    out[#out + 1] = { text = "Every setting", verb = "OPEN", act = { word = "OPEN", peek = true, fn = function() if NS.UI.ToggleOptions then NS.UI:ToggleOptions() end end } }
    return out
end

-- THE CARD ----------------------------------------------------------------------------------------------------------------------

function A.Newest()
    for _, e in ipairs(list()) do if e.status == "new" then return e end end
end
local function newCount() local n = 0 for _, e in ipairs(list()) do if e.status == "new" then n = n + 1 end end return n end
function A.CardPrio(out)
    if A.Newest() then return 7 end
    return out and #list() > 0 and 1 or nil
end
function A.CardLines()
    local e, n = A.Newest(), newCount()
    if not e then return { "RECRUITS", "", "Nobody new", tostring(#list()), "dim", list = {} } end
    local who = e.name .. (e.level and (", " .. e.level) or "") .. (e.class and (" " .. e.class:lower()) or "")
    local words = lastWords(e)
    local l = {}
    if words then l[1] = { "Says", words } end
    if n > 1 then l[#l + 1] = { "Waiting", tostring(n) } end
    return { "NEW RECRUIT", "", who, ago(e.timestamp), "gold", hot = true, list = l }
end
function A.CardButtons()
    local e = A.Newest()
    if not e then return { { word = "OPEN", peek = true, fn = function() local D = Deck() if D then D.Open(ID) end end } } end
    local out = { { word = "REPLY", peek = true, fn = function() open(e.name) local D = Deck() if D then D.Open(ID) end end } }
    if ask(CanGuildInvite) then out[2] = { word = "INVITE", fn = function() R():InviteToGuild(e.name) end } end
    return out
end

-- REGISTER ----------------------------------------------------------------------------------------------------------------------

function A.Register()
    local D = Deck()
    if A.handle or not (D and D.Register) or not (NS.Responders and NS.Message and NS.db) then return false end
    A.handle = D.Register{
        owner = ADDON, key = "desk", name = "Nebbinator", icon = "Ne", order = 60,
        about = "Your guild's recruiting desk: who whispered, your ready answers, the ad and where it can go.",
        badge = function() local n = newCount() return n > 0 and n or nil end,
        card = { tick = true, prio = A.CardPrio, lines = A.CardLines, buttons = A.CardButtons },
        page = {
            tick = true,
            tour = { { text = "Everybody who whispered, newest first. Press one: their words, and your ready answers - one click each.", note = "AD: the line as it will post." },
                { text = "Posting is always your own click: one line, one channel, as the desk window does it." } },
            title = function() return pick or "Nebbinator" end,
            kicker = function()
                if pick then local e = entry(pick) return e and (A.WORD[e.status] or e.status) or "" end
                local n = newCount()
                return n > 0 and (n .. " waiting") or "recruiting"
            end,
            tabs = function() return { "DESK", "AD", "STATS", "SETTINGS" } end,
            boxes = function(tab)
                local e = pick and entry(pick)
                if pick and not e then pick = nil end
                if e then return recruitBoxes(e) end
                if tab == 1 then return deskBoxes() elseif tab == 2 then return adBoxes() elseif tab == 3 then return statBoxes() end
                return {}
            end,
            rows = function(tab)
                local e = pick and entry(pick)
                if e then return recruitRows(e) end
                if tab == 1 then return deskRows() elseif tab == 2 then return adRows() elseif tab == 3 then return statRows() end
                return settingRows()
            end,
            text = function(tab)
                if pick then return nil end
                if tab == 1 and #list() == 0 then return "Nobody has whispered yet. Post the ad from AD: who answers lands here." end
                if tab == 2 then local t = adText() return t ~= "" and t or "No ad yet: write one in the desk window (Message)." end
                if tab == 3 and not statBoxes()[1] then return "No posts counted yet." end
                return nil
            end,
            say = function(tab)
                if pick then return nil end
                if tab == 2 then return NS.db.preview and "Preview is on: nothing really sends" or "One click, one line, one channel" end
                if tab == 1 and newCount() > 0 then return newCount() .. " wait for an answer" end
            end,
            big = function(tab)
                local e = pick and entry(pick)
                if e then
                    if not ask(CanGuildInvite) then return nil end
                    return { word = "INVITE TO THE GUILD", fn = function() R():InviteToGuild(e.name) end }
                end
                if tab == 1 then
                    local n = A.Newest()
                    return n and { word = "REPLY TO " .. n.name:match("^%S+"):upper(), peek = true, fn = function() open(n.name) end } or nil
                end
                return nil
            end,
            keys = function(tab)
                local e = pick and entry(pick)
                if e then return recruitKeys(e) end
                return { { word = "POP OUT", peek = true, tip = "The desk window on your screen", fn = function()
                    if NebbinatorAPI then NebbinatorAPI.Open(tab == 2 and "Message" or tab == 3 and "Stats" or "Desk") end
                    local D = Deck()
                    if D then D.page = "home" if D.Dirty then D.Dirty(true) end end
                end } }
            end,
        },
    }
    -- the desk changed (a whisper, a status, a reply): the phone repaints with the window
    local UI = NS.UI
    if UI and type(UI.OnDataChanged) == "function" and not UI.bisDeckHooked then
        local old = UI.OnDataChanged
        UI.OnDataChanged = function(self, ...)
            local r = old(self, ...)
            if A.handle and A.handle.Dirty then pcall(A.handle.Dirty, A.handle) end
            return r
        end
        UI.bisDeckHooked = true
    end
    return true
end
A.ID = ID
A.Open = function(name) pick = name end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() if C_Timer and C_Timer.After then C_Timer.After(0, function() A.Register() end) else A.Register() end end)
A.boot = ev
