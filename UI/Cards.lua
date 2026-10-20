-- Nebbinator - UI/Cards.lua
-- THE CARDS (Arn, 21 Oct 2026: "I like the cards from the survivor game ... the one that says ally answered
-- call", "maybe a progress bar of it thinking or working"): SURVIVOR's rally band - a dark band, a gold call
-- in thick outline, the answer under it - over the top of the screen, with a thin bar along its foot.
--   a card    the bar DRAINS: when it is gone, so is the card (the mouse over a card holds it)
--   working   the bar FILLS: the /who lookup, whispers held while the game holds chat back; it goes when
--             the work is done (C.Done), whatever the bar says
-- Up to C.MAX at once, stacked downwards; the oldest goes for a new one. Nothing ticks while none is up.

local ADDON, NS = ...
local K = NS.Kit

local C = {}
NS.Cards = C

C.MAX = 3
C.SECS = 12                -- a card's life
C.BIG = { w = 520, h = 74, title = 18, line = 12, gap = 6 }
C.SMALL = { w = 400, h = 54, title = 13, line = 11, gap = 4 }
C.TOP = -150               -- the first card's top, from the top of the screen

C.up = {}                  -- the cards on screen, newest last
local pool = {}

local function Font(fs, size, outline)
    pcall(fs.SetFont, fs, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, outline)
    if not fs:GetFont() then K.font(fs, size) end
end

local function Make()
    local c = CreateFrame("Frame", nil, UIParent)
    c:SetFrameStrata("HIGH")
    c:EnableMouse(true)
    c.band = c:CreateTexture(nil, "BACKGROUND")
    c.band:SetAllPoints()
    c.band:SetColorTexture(0, 0, 0, 0.6)
    c.title = c:CreateFontString(nil, "OVERLAY")
    c.line = c:CreateFontString(nil, "OVERLAY")
    c.sub = c:CreateFontString(nil, "OVERLAY")
    c.barBg = c:CreateTexture(nil, "ARTWORK")
    c.barBg:SetColorTexture(1, 1, 1, 0.08)
    c.barBg:SetPoint("BOTTOMLEFT")
    c.barBg:SetPoint("BOTTOMRIGHT")
    c.barBg:SetHeight(3)
    c.bar = c:CreateTexture(nil, "OVERLAY")
    c.bar:SetPoint("BOTTOMLEFT")
    c.bar:SetHeight(3)
    c.buttons = {}
    c.close = K.Button(c, "x", 16, 16, function() C.Hide(c) end, "muted")
    c.close:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4)
    c:SetScript("OnEnter", function(self) self.held = true end)
    c:SetScript("OnLeave", function(self) self.held = nil end)
    return c
end

local function Place()
    local y = C.TOP
    for _, c in ipairs(C.up) do
        c:ClearAllPoints()
        c:SetPoint("TOP", UIParent, "TOP", 0, y)
        y = y - c.size.h - c.size.gap - 8
    end
end

--- The ticker: one OnUpdate for all the cards, only while one is up.
local ticker = CreateFrame("Frame")
function C.Tick(dt)
    for i = #C.up, 1, -1 do
        local c = C.up[i]
        if c.working then
            c.t = c.t + dt
            local f = c.secs and math.min(1, c.t / c.secs) or ((c.t % 2) / 2)    -- no end known: it sweeps
            c.bar:SetWidth(math.max(1, c.size.w * f))
        elseif not c.held then
            c.t = c.t + dt
            local left = 1 - c.t / c.secs
            if left <= 0 then C.Hide(c) else c.bar:SetWidth(math.max(1, c.size.w * left)) end
        end
    end
end
local function Arm()
    if #C.up > 0 then ticker:SetScript("OnUpdate", function(_, dt) C.Tick(dt) end)
    else ticker:SetScript("OnUpdate", nil) end
end
C.ticker = ticker

--- A card up: opts = { title, line, sub, big, secs, tone, key, working, buttons = { {label, fn, tone} } }.
--- The same key replaces its card in place (a lookup's progress, the held count). Answers the card.
function C.Show(opts)
    local c
    if opts.key then
        for _, o in ipairs(C.up) do if o.key == opts.key then c = o break end end
    end
    if not c then
        if #C.up >= C.MAX then C.Hide(C.up[1]) end
        c = table.remove(pool) or Make()
        C.up[#C.up + 1] = c
    end
    c.key, c.working, c.held = opts.key, opts.working, nil
    c.size = opts.big and C.BIG or C.SMALL
    c.secs = opts.secs or (not opts.working and C.SECS) or nil
    c.t = 0
    c:SetSize(c.size.w, c.size.h)

    Font(c.title, c.size.title, opts.big and "THICKOUTLINE" or "OUTLINE")
    if opts.big then c.title:SetTextColor(1, 0.82, 0.2, 1) else c.title:SetTextColor(K.shade(opts.tone or "ink", 1)) end
    c.title:SetText(opts.title or "")
    c.title:ClearAllPoints()
    c.title:SetPoint("TOP", c, "TOP", 0, -8)
    Font(c.line, c.size.line)
    c.line:SetTextColor(1, 1, 1, 0.92)
    c.line:SetText(opts.line or "")
    c.line:ClearAllPoints()
    c.line:SetPoint("TOP", c.title, "BOTTOM", 0, -5)
    Font(c.sub, c.size.line - 1)
    c.sub:SetTextColor(K.shade("gold", 1))
    c.sub:SetText(opts.sub or "")
    c.sub:ClearAllPoints()
    c.sub:SetPoint("TOP", c.line, "BOTTOM", 0, -3)
    c.bar:SetColorTexture(K.shade(opts.working and "accent" or (opts.big and "gold" or "ink2"), 0.9))
    c.bar:SetWidth(opts.working and 1 or c.size.w)

    for _, b in ipairs(c.buttons) do b:Hide() end
    local x = 8
    for i, def in ipairs(opts.buttons or {}) do
        local b = c.buttons[i]
        if not b then
            b = K.Button(c, "", 80, 18, function(self) C.Hide(c) if self.def then self.def[2]() end end)
            c.buttons[i] = b
        end
        b.def = def
        b:SetLabel(def[1])
        b:SetTone(def[3])
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", x, 8)
        b:Show()
        x = x + 86
    end
    c:Show()
    Place()
    Arm()
    return c
end

function C.Hide(c)
    for i, o in ipairs(C.up) do
        if o == c then
            table.remove(C.up, i)
            c:Hide()
            pool[#pool + 1] = c
            break
        end
    end
    Place()
    Arm()
end

--- Work finished: its card goes (no card, nothing to do).
function C.Done(key)
    for _, c in ipairs(C.up) do if c.key == key then C.Hide(c) return true end end
    return false
end

function C.Working(key, title, line, secs) return C.Show({ key = key, title = title, line = line, secs = secs, working = true }) end

--------------------------------------------------------------------
-- the cards themselves
--------------------------------------------------------------------

local function Ago(at)
    local d = math.max(0, time() - (at or time()))
    if d < 3600 then return "just now" end
    if d < 86400 then return math.floor(d / 3600) .. " h ago" end
    local n = math.floor(d / 86400)
    return n .. (n == 1 and " day ago" or " days ago")
end

--- The party scout's card: BIG and with a sound for a needed class without a guild, small and quiet for
--- one with a guild. Somebody the guild is already talking to says who, and "nudge them".
function C.Scout(look)
    local sub
    if look.prospect then
        local row = NS.Team and NS.Team.List()[look.name]
        sub = ("%s talked to them %s - nudge them to join"):format(look.by or "a guildmate", Ago(row and row.at))
    end
    local buttons = {
        { "Ask them", function() NS.Scout.Ask(look) end, "good" },
        { "To desk", function() NS.Scout.ToDesk(look) end },
    }
    if look.guild then
        return C.Show({ title = ("%s - %s of <%s>"):format(look.name, look.class.name, look.guild),
            line = ("We need %s. They have a guild: a friendly word, no pressure."):format(look.want),
            sub = sub, tone = "ink2", buttons = buttons, secs = C.SECS })
    end
    NS.Util.PlayAlert(NS.db.autoReply.sound)
    return C.Show({ big = true, title = ("%s - A %s WITHOUT A GUILD"):format(look.name:upper(), look.class.name:upper()),
        line = ("We need %s - ask if they want to raid with us"):format(look.want),
        sub = sub, buttons = buttons, secs = C.SECS * 2 })
end

--- The post reminder: the same post again, on a click (the game wants one for a channel).
function C.Remind(mins, chatType, target, where)
    return C.Show({ key = "remind", title = "TIME TO POST AGAIN",
        line = ("Your last ad in %s went out %d min ago"):format(where or "chat", mins), tone = "gold",
        buttons = { { "Post", function() NS.Message:Send(chatType, target) end, "good" } }, secs = 30 })
end
