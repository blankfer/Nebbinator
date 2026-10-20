-- Nebbinator - Core/Responders.lua
-- Whisper capture, instant class detection, auto-reply, applicant tracking.

local ADDON, NS = ...
local U = NS.Util

NS.Responders = {}
local R = NS.Responders

function R:Initialize()
    self.whoPending   = nil
    self.whoBusy      = false
    self.replyLog     = {}     -- timestamps of auto-replies, for the rate cap
    self.guildRoster  = {}

    local f = CreateFrame("Frame")
    self.frame = f
    f:RegisterEvent("CHAT_MSG_WHISPER")
    f:RegisterEvent("CHAT_MSG_CHANNEL")
    f:RegisterEvent("WHO_LIST_UPDATE")
    f:RegisterEvent("CHAT_MSG_SYSTEM")
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            R:OnWhisper(...)
        elseif event == "CHAT_MSG_CHANNEL" then
            R:OnChannelMessage(...)
        elseif event == "WHO_LIST_UPDATE" then
            R:OnWhoResult()
        elseif event == "CHAT_MSG_SYSTEM" then
            R:OnSystemMessage(...)
        elseif event == "GUILD_ROSTER_UPDATE" then
            -- READ WHEN ASKED, NOT WHEN PINGED (7 Oct 2026, the cost pass). This fires whenever any
            -- addon or the guild pane asks for the roster and whenever anyone logs on or off - a
            -- 500-member walk each time. The one reader is the auto-reply, once per whisper.
            R.rosterDirty = true
        end
    end)

    self:InstallChatFilter()
    self:Tidy()

    if IsInGuild() then
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
        elseif GuildRoster then GuildRoster() end
    end
end

--------------------------------------------------------------------
-- Guild roster (so we never cold-pitch our own members)
--------------------------------------------------------------------

function R:RefreshGuildRoster()
    wipe(self.guildRoster)
    self.guildRanks = {}            -- name -> rank index (0 = guild master), for Team.IsOfficer
    local total = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, total do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name and not U.Hidden(name) then
            local key = U.StripRealm(name):lower()
            self.guildRoster[key] = true
            if type(rankIndex) == "number" and not U.Hidden(rankIndex) then self.guildRanks[key] = rankIndex end
        end
    end
end

-- the guild hears about a desk row that changed (Core/Team.lua); free when there is no team
local function Share(entry) if NS.Team and NS.Team.Changed then NS.Team.Changed(entry) end end
R.Share = Share

function R:IsGuildMember(name)
    if self.rosterDirty then
        self.rosterDirty = nil
        self:RefreshGuildRoster()
    end
    return self.guildRoster[name:lower()] == true
end

--------------------------------------------------------------------
-- Incoming whispers
--------------------------------------------------------------------

--- WHAT THE GAME HID, counted per event and never read (12 Oct 2026). A whisper that arrives while
--- chat is locked down is still in the player's chat frame - only the desk cannot see it - so the
--- first one says so, once, until a readable whisper comes in again.
R.hidden = {}
function R:Hid(event, ...)
    for i = 1, select("#", ...) do
        if U.Hidden((select(i, ...))) then
            self.hidden[event] = (self.hidden[event] or 0) + 1
            if event == "CHAT_MSG_WHISPER" and not self.toldHidden then
                self.toldHidden = true
                U.Print("a whisper came in while the game hides chat from addons - it is in your"
                    .. " chat, not on the desk.")
            end
            return true
        end
    end
    return false
end

function R:OnWhisper(text, sender, _, _, _, _, _, _, _, _, _, guid)
    if self:Hid("CHAT_MSG_WHISPER", text, sender, guid) then return end
    self.toldHidden = false
    sender = U.StripRealm(sender or "")
    if sender == "" then return end

    local db = NS.db.responders
    local entry = db[sender]
    local isNew = false

    if not entry then
        isNew = true
        entry = {
            name      = sender,
            status    = "new",
            class     = nil,
            level     = nil,
            guild     = nil,
            note      = "",
            source    = "whisper",
            timestamp = time(),
            messages  = {},
        }
        db[sender] = entry
    end

    entry.timestamp = time()
    table.insert(entry.messages, { text = text, at = time() })
    while #entry.messages > 10 do table.remove(entry.messages, 1) end

    -- The whisper carries the sender's GUID: class is free and instant,
    -- no /who round trip needed just to colour the name.
    if guid and not entry.class then
        local ok, _, englishClass = pcall(GetPlayerInfoByGUID, guid)
        if ok and englishClass then entry.class = englishClass end
    end

    local settings = NS.db.autoReply
    if settings.playSound and (isNew or not settings.soundOnlyNew) then
        U.PlayAlert(settings.sound)
    end
    if isNew then
        NS.Say(sender .. " whispered", "gold")
    end

    self:MaybeAutoReply(entry, text)
    if isNew then
        Share(entry)
        if NS.Stats then NS.Stats.Whispered(sender) end        -- which post brought them (Core/Stats.lua)
    end
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
    -- API.lua's callbacks; free when nobody listens
    if NS.APIFire then
        if isNew then NS.APIFire("Nebbinator_NewRecruit", sender, "whisper") end
        NS.APIFire("Nebbinator_Whisper", sender, text)
    end
end

--------------------------------------------------------------------
-- Passive lead finder: people advertising for a guild in your channels
--------------------------------------------------------------------

local LEAD_PATTERNS = {
    "lf%s*guild", "looking for a? ?guild", "lfguild", "guildless",
    "need a? ?guild", "want to join a? ?guild",
}

function R:OnChannelMessage(text, sender, _, _, _, _, _, _, channelName)
    if not NS.db.leadFinder then return end
    if self:Hid("CHAT_MSG_CHANNEL", text, sender, channelName) then return end
    sender = U.StripRealm(sender or "")
    -- my own whole name, asked once a session (a city's channels are hundreds of lines an hour)
    if not R.me then R.me = U.WholeName("player") end
    if sender == "" or sender == R.me then return end
    if NS.db.responders[sender] then return end

    local lower = (text or ""):lower()
    local hit = false
    for _, pattern in ipairs(LEAD_PATTERNS) do
        if lower:find(pattern) then hit = true break end
    end
    if not hit then return end

    NS.db.responders[sender] = {
        name = sender, status = "new", note = "", source = "channel",
        channel = channelName, timestamp = time(),
        messages = { { text = text, at = time() } },
    }
    if NS.db.autoReply.playSound then U.PlayAlert(NS.db.autoReply.sound) end
    Share(NS.db.responders[sender])
    NS.Say(sender .. " wants a guild", "gold")
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
    if NS.APIFire then NS.APIFire("Nebbinator_NewRecruit", sender, "channel") end
end

--------------------------------------------------------------------
-- Auto-reply
--------------------------------------------------------------------

function R:MatchesKeywords(text)
    local settings = NS.db.autoReply
    if settings.mode == "any" then return true end
    local lower = (text or ""):lower()
    for _, word in ipairs(U.SplitList(settings.keywords)) do
        if lower:find(word, 1, true) then return true end
    end
    return false
end

function R:UnderRateCap()
    local now = time()
    for i = #self.replyLog, 1, -1 do
        if now - self.replyLog[i] > 60 then table.remove(self.replyLog, i) end
    end
    return #self.replyLog < (tonumber(NS.db.autoReply.maxPerMinute) or 6)
end

function R:MaybeAutoReply(entry, text)
    local settings = NS.db.autoReply
    if not settings.enabled then return end
    if settings.skipGuildies and self:IsGuildMember(entry.name) then return end
    -- LAUNCH-DAY MODE (21 Oct 2026): everyone gets the "we're swamped" line, keywords or not
    if not settings.busy and not self:MatchesKeywords(text) then return end

    -- Don't ping-pong with another addon echoing our own link back at us.
    local discord = U.Trim(NS.db.discord)
    if discord ~= "" and (text or ""):find(discord, 1, true) then return end

    local cooldown = tonumber(settings.cooldown) or 900
    if entry.lastReply and (time() - entry.lastReply) < cooldown then return end

    if not self:UnderRateCap() then
        NS.Say("reply cap hit", "warn")
        return
    end

    local body = NS.Message:Render(settings.busy and settings.busyText or settings.text)
    if body == "" then return end
    -- CLASS-AWARE (21 Oct 2026): their class is one we need - say so, with the specs
    local want = settings.classAware ~= false and self:NeedFor(entry, text)
    if want then body = body .. " " .. want end

    if NS.Message:SendWhisper(entry.name, body) then
        NS.Say(entry.name .. " auto-replied", "good")
        entry.lastReply = time()
        entry.autoReplied = true
        if entry.status == "new" then entry.status = "contacted" Share(entry) end
        table.insert(self.replyLog, time())
    end
end

--------------------------------------------------------------------
-- /who lookup
--
-- SendWho() is protected: Blizzard only allows it straight out of a
-- hardware event, so this must be called from a button's OnClick, never
-- from an event handler or a timer.
--
-- Results arrive one of two ways depending on the client's who-to-UI
-- setting: through WHO_LIST_UPDATE, or printed to chat as a system
-- message. We handle both, because the UI list is empty in the second
-- case and that is what actually happens here.
--------------------------------------------------------------------

function R:LookupPlayer(name)
    if not (C_FriendList and C_FriendList.SendWho) then
        NS.Say("no /who on this client", "warn")
        return
    end
    if self.whoBusy then
        NS.Say("still looking up", "muted")
        return
    end

    self.whoBusy    = true
    self.whoPending = name
    self.whoGotResult = false

    -- Ask for results in the UI list. Some builds ignore or hide this, which
    -- is why the chat parser below exists.
    if C_FriendList.SetWhoToUI then C_FriendList.SetWhoToUI(true)
    elseif SetWhoToUI then SetWhoToUI(1) end

    C_FriendList.SendWho('n-"' .. name .. '"')
    if NS.Cards then NS.Cards.Working("who", "LOOKING UP " .. name:upper(), "asking the game who they are", 6) end

    C_Timer.After(6, function()
        if self.whoBusy and self.whoPending == name then
            if not self.whoGotResult then
                local entry = NS.db.responders[name]
                if entry then entry.online, entry.lookedUp = false, true end
                NS.Say(name .. " looks offline", "muted")
            end
            self:FinishLookup()
        end
    end)
end

function R:FinishLookup()
    if C_FriendList and C_FriendList.SetWhoToUI then C_FriendList.SetWhoToUI(false)
    elseif SetWhoToUI then SetWhoToUI(0) end
    self.whoBusy, self.whoPending = false, nil
    if NS.Cards then NS.Cards.Done("who") end
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:ApplyWhoData(name, level, className, guild, zone)
    local entry = NS.db.responders[name]
    if not entry then return false end

    if level and level > 0 then entry.level = level end
    if className and className ~= "" then
        entry.className = className
        entry.class = U.FileNameFromLocalized(className) or entry.class
    end
    entry.guild    = (guild and guild ~= "") and guild or "No guild"
    entry.zone     = zone or entry.zone
    entry.online   = true
    entry.lookedUp = true

    self.whoGotResult = true
    return true
end

-- Path 1: the who list actually got populated.
function R:OnWhoResult()
    if not self.whoBusy then return end

    local count = C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults() or 0
    for i = 1, count do
        local info = C_FriendList.GetWhoInfo(i)
        if info and info.fullName then
            self:ApplyWhoData(U.StripRealm(info.fullName), info.level, info.classStr,
                info.fullGuildName, info.area)
        end
    end

    if count > 0 then self:FinishLookup() end
end

-- Path 2: "[Kumlance]: Level 70 Gnome Mage <Guild> - Shattrath City"
-- Pulled apart by landmark instead of by the localised format string, so
-- it survives locales and client differences.
local function LocalizedClassFromLine(line)
    for _, table_ in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
        if table_ then
            for _, localized in pairs(table_) do
                if localized ~= "" and line:find(localized, 1, true) then return localized end
            end
        end
    end
end

function R:ParseWhoLine(line)
    if not line or line == "" then return false end

    local name = line:match("|Hplayer:([^|:%]]+)") or line:match("^%[(.-)%]")
    if not name then return false end
    name = U.StripRealm(name)
    if not NS.db.responders[name] then return false end

    local body  = line:match("%]%s*|?h?:?%s*(.*)$") or line
    local level = tonumber(body:match("(%d+)"))
    local guild = line:match("<(.-)>")
    local zone  = line:match("%s%-%s([^%-]+)%s*$")

    return self:ApplyWhoData(name, level, LocalizedClassFromLine(line), guild, zone and U.Trim(zone))
end

function R:OnSystemMessage(text)
    if self:Hid("CHAT_MSG_SYSTEM", text) then return end
    if self:GuildNews(text) then return end
    if not self.whoBusy then return end
    if self:ParseWhoLine(text) then
        C_Timer.After(0.1, function()
            if self.whoBusy then self:FinishLookup() end
        end)
    end
end

-- Keep the /who noise out of the chat frame while one of our lookups is in
-- flight. Manual /who typed by the player is untouched.
function R:InstallChatFilter()
    if self.chatFilterInstalled or not ChatFrame_AddMessageEventFilter then return end
    self.chatFilterInstalled = true
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text)
        if not R.whoBusy then return false end
        if U.Hidden(text) then return false end      -- hidden: shown as the game shows it
        if text and (text:find("|Hplayer:", 1, true) or text:match("^%d+ ")) then
            return true
        end
        return false
    end)
end

--------------------------------------------------------------------
-- Actions used by the responders window
--------------------------------------------------------------------

function R:SetStatus(name, status)
    local entry = NS.db.responders[name]
    if entry then
        entry.status = status
        Share(entry)
        NS.UI:OnDataChanged()
        NS.Minimap:Update()
    end
end

function R:Remove(name)
    NS.db.responders[name] = nil
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:ClearWithStatus(status)
    for name, entry in pairs(NS.db.responders) do
        if not status or entry.status == status then
            NS.db.responders[name] = nil
        end
    end
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:CountNew()
    local n = 0
    for _, entry in pairs(NS.db.responders) do
        if entry.status == "new" then n = n + 1 end
    end
    return n
end

function R:SortedList(filter)
    local list = {}
    for _, entry in pairs(NS.db.responders) do
        if not filter or filter == "all" or entry.status == filter then
            table.insert(list, entry)
        end
    end
    table.sort(list, function(a, b)
        if (a.timestamp or 0) == (b.timestamp or 0) then
            return (a.name or "") < (b.name or "")
        end
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
    return list
end

function R:LogsUrl(name)
    local url = U.Trim(NS.db.logsUrl)
    if url == "" then return "" end
    -- the realm as Warcraft Logs writes it ("living-flame"), the region from the client (21 Oct 2026: it
    -- said "us" whoever you were)
    local realm = (GetRealmName() or ""):gsub("'", ""):gsub("%s+", "-"):lower()
    return (url:gsub("{(%w+)}", function(token)
        token = token:lower()
        if token == "name"   then return (U.StripRealm(name):gsub("%s+", "-"):lower()) end
        if token == "realm"  then return realm end
        if token == "region" then return R.Region() end
        return "{" .. token .. "}"
    end))
end

function R:ShowLogs(name)
    local url = self:LogsUrl(name)
    if url == "" then
        NS.Say("no logs address set", "warn")
        return
    end
    NS.Kit.ShowCopyBox(url, "Logs for " .. name)
end

function R:WhisperTo(name)
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat("/w " .. name .. " ")
    end
end

function R:InviteToGroup(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(name)
    elseif InviteUnit then
        InviteUnit(name)
    end
end

function R:InviteToGuild(name)
    if not IsInGuild() then
        NS.Say("not in a guild", "warn")
        return
    end
    if not (CanGuildInvite and CanGuildInvite()) then
        NS.Say("rank cannot invite", "warn")
        return
    end
    GuildInvite(name)
    NS.Say(name .. " invited", "good")
    -- INVITED, not trial (21 Oct 2026): they have not said yes yet. The game's "has joined the guild"
    -- line moves them on by itself (R:GuildNews).
    local entry = NS.db.responders[name]
    if entry then entry.invitedAt = time() end
    self:SetStatus(name, "invited")
end

function R:SendQuickReply(name, index)
    local reply = NS.db.quickReplies[index]
    if not reply or U.Trim(reply.text) == "" then
        NS.Say("reply " .. index .. " is empty", "warn")
        return
    end

    local body = NS.Message:Render(reply.text)
    if body == "" then return end

    NS.Message:SendWhisper(name, body)
    NS.Say(name .. " <- " .. (NS.Util.Trim(reply.label) ~= "" and reply.label or ("reply " .. index)), "good")

    local entry = NS.db.responders[name]
    if entry then
        entry.lastReply = time()
        entry.sentReplies = entry.sentReplies or {}
        entry.sentReplies[index] = true
        if entry.status == "new" then entry.status = "contacted" Share(entry) end
    end
    NS.UI:OnDataChanged()
    NS.Minimap:Update()
end

function R:SendDiscord(name)
    local link = U.Trim(NS.db.discord)
    if link == "" then
        NS.Say("no discord link set", "warn")
        return
    end
    NS.Message:SendWhisper(name, NS.Message:Render(NS.db.autoReply.text))
    local entry = NS.db.responders[name]
    if entry then
        entry.lastReply = time()
        if entry.status == "new" then entry.status = "contacted" Share(entry) end
    end
    NS.UI:OnDataChanged()
end

--------------------------------------------------------------------
-- 21 Oct 2026, the review
--------------------------------------------------------------------

--- The region as Warcraft Logs writes it, from the client (us when it will not say).
local REGIONS = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }
function R.Region()
    local fn = GetCurrentRegion
    if not fn then return "us" end
    local ok, n = pcall(fn)
    return (ok and REGIONS[n]) or "us"
end

--- A client sentence ("%s has joined the guild.") as a pattern, its %s a capture.
function R.Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local body = fmt:gsub("%%%d?%$?s", "\1")
    body = body:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    body = body:gsub("\1", "(.+)")
    return "^" .. body .. "$"
end

--- JOINED, BY ITSELF (21 Oct 2026, the review: nothing noticed when somebody actually joined). The game
--- says so in a system line; somebody on the desk who joins is Accepted, one who declines the invite is
--- Declined. Answers true when the line was one of these.
function R:GuildNews(text)
    if type(text) ~= "string" then return false end
    local lines = {
        { _G.ERR_GUILD_JOIN_S or "%s has joined the guild.", "accepted" },
        { _G.ERR_GUILD_DECLINE_S or "%s declines your guild invitation.", "declined" },
    }
    for _, l in ipairs(lines) do
        local pat = R.Pattern(l[1])
        local who = pat and text:match(pat)
        if who then
            who = U.StripRealm(who)
            local entry = NS.db.responders[who]
            if entry then
                entry.status = l[2]
                if l[2] == "accepted" then
                    entry.joinedAt = time()
                    NS.Say(who .. " joined the guild", "good")
                    if NS.Cards and NS.Cards.Show then
                        NS.Cards.Show(who:upper() .. " JOINED THE GUILD", "On the desk since " .. U.TimeAgo(entry.firstAt or entry.timestamp) .. " - welcome them in!")
                    end
                    if NS.APIFire then NS.APIFire("Nebbinator_Joined", who) end
                end
                if NS.Team and NS.Team.Changed then NS.Team.Changed(entry) end
                NS.UI:OnDataChanged()
                NS.Minimap:Update()
            end
            return true
        end
    end
    return false
end

--- A DESK THAT FORGETS (21 Oct 2026, the review: it never did, and a month of recruiting is hundreds of
--- rows). Somebody who never got further than a word is gone after R.KEEP_DAYS; anybody else after
--- R.KEEP_LONG; and never more than R.KEEP_MAX, the oldest going first. Answers how many went.
R.KEEP_DAYS, R.KEEP_LONG, R.KEEP_MAX = 30, 90, 300
local SHORT = { new = true, contacted = true, declined = true, invited = true }
function R:Tidy(now)
    now = now or time()
    local gone, list = 0, {}
    for name, e in pairs(NS.db.responders) do
        local age = (now - (tonumber(e.timestamp) or now)) / 86400
        if age > (SHORT[e.status] and self.KEEP_DAYS or self.KEEP_LONG) then
            NS.db.responders[name] = nil
            gone = gone + 1
        else
            list[#list + 1] = e
        end
    end
    if #list > self.KEEP_MAX then
        table.sort(list, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
        for i = self.KEEP_MAX + 1, #list do
            NS.db.responders[list[i].name] = nil
            gone = gone + 1
        end
    end
    return gone
end

--- CLASS-AWARE (21 Oct 2026): what we need of their class - "We need 2 Resto Shaman right now." - when
--- their class (from their whisper's GUID, or named in what they wrote) is on the needs list. Else nil.
function R:NeedFor(entry, text)
    local lower = (text or ""):lower()
    for _, class in ipairs(NS.CLASSES) do
        local theirs = entry and entry.class == class.file
        local loc = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class.file]
        local named = lower:find(class.name:lower(), 1, true)
            or (type(loc) == "string" and lower:find(loc:lower(), 1, true))
        if theirs or named then
            local want = NS.Message:NeedsOf(class)
            if want then return "We need " .. want .. " right now." end
        end
    end
    return nil
end
