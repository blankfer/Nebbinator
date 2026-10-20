-- Nebbinator - Core/Message.lua
-- Template tokens, message assembly, chat-safe splitting and sending.

local ADDON, NS = ...
local U = NS.Util

NS.Message = {}
local M = NS.Message

function M:Initialize()
    self.lastSend = {}      -- [targetKey] = timestamp
    self.lastAny  = 0
    self.queue    = {}      -- whispers held while the game holds chat back (M:Locked)
    self.sending  = false
    self.pending  = {}      -- [targetKey] = { segments, next } - the rest of a long ad, a click each
end

--- IS THE GAME HOLDING CHAT BACK? (21 Oct 2026, the review.) On Forever an addon may not send chat while
--- C_ChatInfo.InChatMessagingLockdown() says so (inside instances, around boss fights). Sending then fails;
--- so a post says so, and a whisper waits (M:Flush) until the game lets it go.
function M:Locked()
    local fn = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if not fn then return false end
    local ok, locked = pcall(fn)
    if not ok or U.Hidden(locked) then return true end
    return locked == true
end

M.FLUSH_EVERY, M.FLUSH_FOR = 5, 600   -- look again every 5 s; a whisper older than 10 min is dropped

--- Send the whispers that waited, once the game allows chat again.
function M:Flush()
    self.flushing = nil
    if #self.queue == 0 then return 0 end
    if self:Locked() then
        self.flushing = true
        C_Timer.After(self.FLUSH_EVERY, function() M:Flush() end)
        return 0
    end
    local now, sent = GetTime(), 0
    local list = self.queue
    self.queue = {}
    if NS.Cards then NS.Cards.Done("held") end
    for _, w in ipairs(list) do
        if now - w.at <= self.FLUSH_FOR then
            self:SendWhisper(w.name, w.text)
            sent = sent + 1
        end
    end
    if sent > 0 then NS.Say(sent .. " held whisper" .. (sent == 1 and "" or "s") .. " sent", "good") end
    return sent
end

--------------------------------------------------------------------
-- Token sources
--------------------------------------------------------------------

-- "2 Resto Shaman, 1 Prot Warrior" - always in the same declared order,
-- unlike v1 which walked the table with pairs() and shuffled every build.
function M:NeedsText(short)
    local parts = {}
    for _, class in ipairs(NS.CLASSES) do
        local counts = NS.db.needs[class.key]
        if counts then
            for _, spec in ipairs(class.specs) do
                local n = tonumber(counts[spec.key]) or 0
                if n > 0 then
                    if #class.specs == 1 then
                        table.insert(parts, n .. " " .. class.name)
                    elseif short then
                        table.insert(parts, n .. " " .. spec.name .. " " .. class.name:sub(1, 4))
                    else
                        table.insert(parts, n .. " " .. spec.name .. " " .. class.name)
                    end
                end
            end
        end
    end
    return table.concat(parts, ", ")
end

--- What we need of one class, as words ("2 Resto Shaman"), or nil when none (R:NeedFor, the scout).
function M:NeedsOf(class)
    local counts = NS.db.needs[class.key]
    if not counts then return nil end
    local parts = {}
    for _, spec in ipairs(class.specs) do
        local n = tonumber(counts[spec.key]) or 0
        if n > 0 then
            parts[#parts + 1] = (#class.specs == 1) and (n .. " " .. class.name) or (n .. " " .. spec.name .. " " .. class.name)
        end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

function M:RoleCounts()
    local tanks, healers, dps = 0, 0, 0
    for _, class in ipairs(NS.CLASSES) do
        local counts = NS.db.needs[class.key]
        if counts then
            for _, spec in ipairs(class.specs) do
                local n = tonumber(counts[spec.key]) or 0
                if spec.role == "TANK" then tanks = tanks + n
                elseif spec.role == "HEALER" then healers = healers + n
                else dps = dps + n end
            end
        end
    end
    return tanks, healers, dps
end

-- Days that share a time get folded together: "Tue/Thu 8-11pm, Sun 7pm".
function M:TimesText(useFullNames)
    local order, byTime = {}, {}
    for _, day in ipairs(NS.DAYS) do
        local value = U.Trim(NS.db.raidTimes[day.key])
        if value ~= "" then
            if not byTime[value] then
                byTime[value] = {}
                table.insert(order, value)
            end
            table.insert(byTime[value], useFullNames and day.name or day.short)
        end
    end
    local groups = {}
    for _, value in ipairs(order) do
        table.insert(groups, table.concat(byTime[value], "/") .. " " .. value)
    end
    return table.concat(groups, ", ")
end

function M:GuildName()
    local override = U.Trim(NS.db.guildName)
    if override ~= "" then return override end
    local name = GetGuildInfo("player")
    return name or "our guild"
end

function M:Tokens()
    local tanks, healers, dps = self:RoleCounts()
    return {
        needs          = self:NeedsText(false),
        ["needs:short"]= self:NeedsText(true),
        times          = self:TimesText(false),
        ["times:full"] = self:TimesText(true),
        guild          = self:GuildName(),
        discord        = U.Trim(NS.db.discord),
        content        = U.Trim(NS.db.content),
        pre            = U.Trim(NS.db.preText),
        post           = U.Trim(NS.db.postText),
        player         = UnitName("player") or "",
        level          = tostring(UnitLevel("player") or ""),
        realm          = GetRealmName() or "",
        faction        = UnitFactionGroup("player") or "",
        tanks          = tostring(tanks),
        healers        = tostring(healers),
        dps            = tostring(dps),
        total          = tostring(tanks + healers + dps),
        nextraid       = self:NextRaid(),
    }
end

--- {nextraid}: the raid pasted into BiS Guild ("Wed 20:00"), or "" without one (or without BiS Guild).
function M:NextRaid()
    local api = _G.BiSGuildAPI
    if not (api and api.RaidNight) then return "" end
    local ok, e = pcall(api.RaidNight)
    if not ok or type(e) ~= "table" then return "" end
    local now = (GetServerTime and GetServerTime()) or time()
    if tonumber(e.start) then
        if e.start < now - 4 * 3600 then return "" end            -- over: not an invitation any more
        if e.start - now < 6 * 86400 then
            return date("%a", e.start) .. " " .. (e.time or date("%H:%M", e.start))
        end
    end
    return U.Trim(((e.date or "") .. " " .. (e.time or "")))
end

NS.TOKEN_HELP = {
    "{needs}", "{needs:short}", "{times}", "{times:full}", "{guild}",
    "{discord}", "{content}", "{tanks}", "{healers}", "{dps}", "{total}",
    "{pre}", "{post}", "{player}", "{level}", "{realm}", "{faction}", "{nextraid}",
}

--------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------

-- Replaces tokens, then tidies the punctuation left behind by empty ones
-- so "Discord: {discord}." never renders as "Discord: ."
function M:Render(template)
    local tokens = self:Tokens()
    local missing = {}

    local text = tostring(template or ""):gsub("{([%w:]+)}", function(key)
        local value = tokens[key:lower()]
        if value == nil then return "{" .. key .. "}" end
        if value == "" then missing[key:lower()] = true end
        return value
    end)

    text = text:gsub("%s+", " ")
    text = text:gsub("[%(%[]%s*[%)%]]", "")
    text = text:gsub("%s*([:,;])%s*([%.!,])", "%2")
    text = text:gsub("([:,;-])%s*$", "")
    text = text:gsub("%s+([%.,!%?])", "%1")
    text = text:gsub("%s*,%s*,", ",")

    local missingList = {}
    for key in pairs(missing) do table.insert(missingList, "{" .. key .. "}") end
    table.sort(missingList)

    return U.Trim(text), missingList
end

function M:ActiveTemplate()
    local index = NS.db.activeTemplate or 1
    return NS.db.templates[index] or NS.db.templates[1]
end

function M:Build()
    -- Override wins: whatever is in the box is what goes out. Tokens still
    -- work there, so {discord} keeps doing its job if they want it.
    if NS.db.customEnabled then
        return self:Render(NS.db.customText or "")
    end
    local template = self:ActiveTemplate()
    return self:Render(template and template.text or "")
end

--------------------------------------------------------------------
-- Channels
--------------------------------------------------------------------

-- Every numbered channel you are actually in, plus any custom names
-- from settings. v1 hardcoded 1/2/3, which is wrong on most realms.
function M:GetChannels()
    local list, seen = {}, {}
    local raw = { GetChannelList() }
    for i = 1, #raw, 3 do
        local id, name = raw[i], raw[i + 1]
        if type(id) == "number" and type(name) == "string" and name ~= "" then
            local short = name:match("^([^%-]+)") or name
            short = U.Trim(short)
            if not seen[short:lower()] then
                seen[short:lower()] = true
                table.insert(list, { id = id, name = short, label = id .. ". " .. short })
            end
        end
    end
    for _, name in ipairs(U.SplitList(NS.db.customChannels)) do
        if not seen[name] then
            local id = GetChannelName(name)
            table.insert(list, { id = id, name = name, label = (id and id > 0 and (id .. ". ") or "") .. name })
        end
    end
    return list
end

--------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------

local function TargetKey(chatType, target)
    return chatType .. ":" .. tostring(target or "")
end

-- When was this target last posted to? Channels are keyed by id internally,
-- so resolve the name the button carries.
function M:LastSendTime(chatType, target)
    if chatType == "CHANNEL" then
        local id = GetChannelName(target)
        if not id or id == 0 then return nil end
        target = id
    end
    return self.lastSend[TargetKey(chatType, target)]
end

function M:CanSend(chatType, target)
    local now = GetTime()
    local cooldown = tonumber(NS.db.sendCooldown) or 10
    local last = self.lastSend[TargetKey(chatType, target)]
    if last and (now - last) < cooldown then
        return false, math.ceil(cooldown - (now - last))
    end
    return true
end

-- POSTING NEEDS A CLICK, EACH PART (21 Oct 2026, the review). On the modern engine a public channel (and
-- say and yell) only takes a message sent straight from a click. A long ad's second part used to follow a
-- second later on a timer - which the game refuses. So the click sends part one, and the same button then
-- says "2/2" and sends the next part on the next click. Party, raid, guild and whispers take timers fine.
M.CLICK_ONLY = { CHANNEL = true, SAY = true, YELL = true }

--- The rest of a long ad waiting on this button: "2/3", or nil.
function M:PendingFor(chatType, target)
    if chatType == "CHANNEL" then
        local id = GetChannelName(target)
        if not id or id == 0 then return nil end
        target = id
    end
    local p = self.pending[TargetKey(chatType, target)]
    if not p then return nil end
    return ("%d/%d"):format(p.next, #p.segments)
end

function M:Send(chatType, target)
    if chatType == "CHANNEL" then
        local id = GetChannelName(target)
        if not id or id == 0 then
            NS.Say("not in " .. tostring(target), "warn")
            return
        end
        target = id
    end

    if self:Locked() then
        NS.Say("the game is holding chat back here - post when you are out", "warn")
        return
    end

    -- the next part of a long ad, on this click
    local key = TargetKey(chatType, target)
    local p = self.pending[key]
    if p then
        SendChatMessage(p.segments[p.next], chatType, nil, target)
        NS.Say(("part %d of %d sent"):format(p.next, #p.segments), "good")
        p.next = p.next + 1
        if p.next > #p.segments then self.pending[key] = nil end
        return
    end

    local message, missing = self:Build()

    if message == "" then
        NS.Say("nothing to send", "warn")
        return
    end

    local ok, wait = self:CanSend(chatType, target)
    if not ok then
        NS.Say(wait .. "s cooldown left", "warn")
        return
    end

    if #missing > 0 then
        NS.Say("empty: " .. table.concat(missing, " "), "gold")
    end

    local segments = U.SplitMessage(message, NS.CHAT_LIMIT)

    if NS.db.previewMode then
        -- the text itself is in the window's preview box already; chat gets nothing
        NS.Say("preview - not sent", "warn")
        return
    end

    self.lastSend[TargetKey(chatType, target)] = GetTime()
    self.lastAny = GetTime()

    if self.CLICK_ONLY[chatType] then
        SendChatMessage(segments[1], chatType, nil, target)
        if #segments > 1 then
            self.pending[key] = { segments = segments, next = 2 }
            NS.Say(("part 1 of %d sent - click again for the next"):format(#segments), "gold")
        else
            NS.Say("sent to " .. (chatType == "CHANNEL" and ("/" .. target) or chatType:lower()), "good")
        end
    else
        -- not a public channel: the rest may follow on a timer (the server drops bursts)
        for i, segment in ipairs(segments) do
            if i == 1 then
                SendChatMessage(segment, chatType, nil, target)
            else
                C_Timer.After((i - 1) * 1.2, function() SendChatMessage(segment, chatType, nil, target) end)
            end
        end
        NS.Say("sent to " .. chatType:lower() .. (#segments > 1 and (" x" .. #segments) or ""), "good")
    end
    if NS.Stats and NS.Stats.Posted then NS.Stats.Posted(chatType, target) end
end

function M:SendWhisper(playerName, text)
    if not playerName or playerName == "" or not text or text == "" then return false end
    if NS.db.previewMode then
        NS.Say("preview - " .. playerName .. " not whispered", "warn")
        return true
    end
    if self:Locked() then
        -- held, not lost: sent the moment the game allows it (M:Flush)
        self.queue[#self.queue + 1] = { name = playerName, text = text, at = GetTime() }
        NS.Say(playerName .. " - held until the game allows chat", "gold")
        if NS.Cards then
            NS.Cards.Working("held", ("%d WHISPER%s WAITING"):format(#self.queue, #self.queue == 1 and "" or "S"),
                "the game is holding chat back here - they go the moment it lets them")
        end
        if not self.flushing then
            self.flushing = true
            C_Timer.After(self.FLUSH_EVERY, function() M:Flush() end)
        end
        return true
    end
    for i, segment in ipairs(U.SplitMessage(text, NS.CHAT_LIMIT)) do
        if i == 1 then
            SendChatMessage(segment, "WHISPER", nil, playerName)
        else
            C_Timer.After((i - 1) * 1.2, function()
                SendChatMessage(segment, "WHISPER", nil, playerName)
            end)
        end
    end
    return true
end
