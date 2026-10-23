-- run from the addon root: lua5.1 dev/tests.lua
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(HERE .. "/harness.lua")
local ROOT = os.getenv("NEB") or (HERE .. "/..")

-- The TOC is the truth for what loads and in what order. This used to be a
-- hand-kept copy of the list, which is the same duplication that let NS.VERSION
-- disagree with the TOC for two weeks (landmine 0c) - a file added to one and
-- not the other is a test suite exercising a different addon than the client
-- loads. BiSTools has read its TOC since day one; this now does too.
local FILES = H.TOC(ROOT, "Nebbinator.toc")

-- A 3.x BETA SAVE (Forever only since 21 Oct 2026: the TBC 1.x migration is gone - Forever keeps its own
-- WTF folder, so no TBC save can be on its client). The upgrade fills in what is new and keeps the rest -
-- including a template list the player cut down to two, which used to grow back to three.
_G.NebbinatorDB = {
    dbVersion = 3,
    needs = { shaman = { resto = 2, ele = 0, enh = 0 },
              druid = { balance = 1, feral = 1, resto = 0, cat = 0 },
              warrior = { prot = 1, arms = 0, fury = 0 } },
    raidTimes = { tuesday = "5pm", sunday = "5pm server time" },
    preText = "lf raiders", postText = "SSC/TK",
    templates = {
        { name = "Mine", text = "<{guild}> needs {needs}. {times}. {discord}" },
        { name = "Short", text = "<{guild}> recruiting: {needs}. {times}. Whisper for info!" },
    },
    logsUrl = "https://fresh.warcraftlogs.com/character/us/dreamscythe/{name}",
    responders = { Dps4 = { name = "Dps4", message = "are you recruiting?", timestamp = os.time() } },
}

local NS = H.Load(ROOT, FILES)

H.section("load")
H.eq(#H.leaked, 0, "no accidental globals", table.concat(H.leaked, ", "))

-- THE API BEFORE LOGIN (playbook 5a): every call answers nil, "not ready" and none errors.
do
    local A = _G.NebbinatorAPI
    H.ok(type(A) == "table" and A.major == 1 and A.version == 2, "NebbinatorAPI is major 1, version 2")
    H.eq(A.Ready(), false, "(api) not ready before login")
    for _, fname in ipairs({ "Recruits", "Recruit", "CountNew", "Ad", "Status", "Open",
                             "Team", "IsProspect", "Needs", "IsOfficer", "Stats" }) do
        local ok, got, why = pcall(A[fname], fname == "Recruit" and "Dps4" or nil)
        H.ok(ok, "(api) " .. fname .. " does not error before login", got)
        H.eq(got, nil, "(api) " .. fname .. " answers nil before login")
        H.eq(why, "not ready", "(api) ...and says why: " .. fname)
    end
end

NS:Initialize()
H.ok(NS.db ~= nil, "db exists")
H.eq(NS.db.dbVersion, 4, "a 3.x save upgraded to v4")
H.eq(NS.db.needs.shaman.resto, 2, "its needs kept")
H.eq(NS.db.needs.druid.balance, 1, "every spec of them")
H.eq(NS.db.raidTimes.tuesday, "5pm", "its raid times kept")
H.ok(NS.db.responders.Dps4 ~= nil, "its desk kept")
H.eq(#NS.db.templates, 2, "a template list the player cut to two stays two (it grew back to three)")
H.eq(NS.db.templates[1].name, "Mine", "and in the player's order")
H.eq(NS.db.logsUrl, "https://fresh.warcraftlogs.com/character/{region}/{realm}/{name}",
     "the old fixed logs address becomes the one that reads your realm and region")
H.ok(NS.db.autoReply.busyText ~= nil and NS.db.autoReply.classAware == true and NS.db.scout == true,
     "and what is new is filled in")
H.eq(NS.db.windows, nil, "old two-window positions dropped")
H.eq(#NS.db.quickReplies, 4, "four quick replies")

H.section("one window, seven pages, the desk first")
local UI = NS.UI
H.ok(UI.frame ~= nil, "window built at login")
H.eq(UI.frame:IsShown(), false, "starts hidden")
H.eq(#UI.PAGES, 7, "seven pages: desk, team, stats, recruit, message, replies, about")
H.eq(UI.PAGES[1], "Desk", "the desk is the first")
H.eq(NS.db.uiTab, "Desk", "and a 3.x save opens on it (it opened on Recruit)")
H.eq(UI.frame:GetWidth(), UI.W, "the window is its width")
H.eq(UI.frame:GetHeight(), UI.H, "and its height")
H.ok(math.abs(UI.W / UI.H - 1.43) < 0.005, "the house shape: 1.43 to 1", UI.W / UI.H)
for _, name in ipairs(UI.PAGES) do
    H.ok(UI.pages[name] ~= nil, "page exists: " .. name)
end

for _, name in ipairs(UI.PAGES) do
    UI:ShowTab(name)
    local shownCount = 0
    for other, page in pairs(UI.pages) do
        if page:IsShown() then shownCount = shownCount + 1 end
    end
    H.eq(shownCount, 1, "exactly one page shown for " .. name)
    H.eq(UI:ShownTab(), name, "ShownTab reports " .. name)
    -- assert on the PAINT: the active tab label is really accent-coloured
    local ar, ag, ab = NS.T.rgb("accent")
    H.isColor(UI.tabs[name].label._color, ar, ag, ab, "active tab label is accent: " .. name)
    H.ok(UI.tabs[name].mark:IsShown(), "active tab has its accent bar: " .. name)
    local other = (name == "Recruit") and "Message" or "Recruit"
    local mr, mg, mb = NS.T.rgb("muted")
    H.isColor(UI.tabs[other].label._color, mr, mg, mb, "inactive tab label is muted: " .. other)
    H.ok(not UI.tabs[other].mark:IsShown(), "inactive tab has no bar: " .. other)
end

H.eq(NS.db.uiTab, "About", "last tab remembered")
UI:ShowTab("Recruit")

H.section("toggle")
UI:Toggle()
H.eq(UI.frame:IsShown(), true, "toggle opens a closed window")
UI:Toggle()
H.eq(UI.frame:IsShown(), false, "toggle closes an open window")
UI:Toggle("Replies")
H.eq(UI.frame:IsShown(), true, "toggle with a page opens")
H.eq(UI:ShownTab(), "Replies", "...on that page")
H.ok(UI.bookOpen, "...with the book rolled out")
UI:ShowTab("Recruit")
UI:Toggle("Replies")
H.eq(UI.frame:IsShown(), true, "toggle to another page keeps it open")
H.eq(UI:ShownTab(), "Replies", "...and switches to it")
UI:ToggleBook(false)

H.section("every control round-trips")
local EXPECTED = {
    "need.shaman.resto", "need.druid.balance", "need.warrior.prot", "time.tuesday", "time.sunday",
    "override", "guildName", "discord", "content", "preText", "postText",
    "templateName", "templateText",
    "quick1Label", "quick1Text", "quick4Label", "quick4Text",
    "autoReply", "replyMode", "keywords", "replyText", "replyCooldown", "replyRate", "skipGuildies",
}
-- previewMode / sendCooldown / playSound / soundOnlyNew / sound / minimap /
-- leadFinder left with the Settings tab: they live in the options window now
-- and are exercised in "the options window" below. logsUrl is the box on the
-- desk; customChannels is /bisn channels.
local ids = {}
for _, id in ipairs(UI:IDs()) do ids[id] = true end
for _, id in ipairs(EXPECTED) do H.ok(ids[id], "control exists: " .. id) end

local SAMPLES = {
    ["need.shaman.resto"] = 3, ["need.druid.balance"] = 2, ["need.warrior.prot"] = 1,
    ["time.tuesday"] = "8-11pm ST", ["time.sunday"] = "7pm",
    guildName = "The Heathens", discord = "discord.gg/heathens", content = "SSC and TK",
    preText = "lf raiders", postText = "toe beans",
    templateName = "Main ad", templateText = "<{guild}> needs {needs}. {times}. {discord}",
    quick1Label = "Times?", quick1Text = "Do the raid times work for you?",
    quick4Label = "Signups", quick4Text = "Sign ups are a must.",
    keywords = "recruit,guild,inv", replyText = "Join us: {discord}",
    replyCooldown = 600, replyRate = 4, replyMode = "any",
}
for id, value in pairs(SAMPLES) do
    H.ok(UI:Set(id, value), "Set works: " .. id)
    H.eq(UI:Get(id), value, "round-trip: " .. id)
end

for _, id in ipairs({ "override", "autoReply", "skipGuildies" }) do
    UI:Set(id, true);  H.eq(UI:Get(id), true,  "toggle on: " .. id)
    UI:Set(id, false); H.eq(UI:Get(id), false, "toggle off: " .. id)
end

H.section("sliders clamp instead of storing junk")
UI:Set("replyRate", 500)
H.eq(NS.db.autoReply.maxPerMinute, 20, "rate cap clamps")

H.section("the window writes the same key the slash command owns")
NS.db.autoReply.enabled = false
UI:Set("autoReply", true)
H.eq(NS.db.autoReply.enabled, true, "checkbox turned auto-reply on")
UI:Set("autoReply", true)
H.eq(NS.db.autoReply.enabled, true, "...and again is a no-op, not a flip")
SlashCmdList["NEBBINATOR"]("reply")
H.eq(NS.db.autoReply.enabled, false, "/bisn reply turns the same key off")

SlashCmdList["NEBBINATOR"]("discord discord.gg/fromslash")
H.eq(UI:Get("discord"), "discord.gg/fromslash", "/bisn discord reaches the field")

H.section("checkbox paint")
UI:ShowTab("Replies")
UI:Set("autoReply", true)
UI:Refresh()
local ar, ag, ab = NS.T.rgb("accent")
local found
for _, fr in ipairs(H.frames) do
    if fr._regions then
        for _, region in ipairs(fr._regions) do
            if region._color and math.abs(region._color[1] - ar) < 0.01
               and math.abs(region._color[2] - ag) < 0.01 then found = true end
        end
    end
end
H.ok(found, "a ticked box is really filled with the accent colour")

H.section("no page draws past the bottom of the window")
do
    -- Innervate shipped a page that ran straight off the frame. This is the
    -- arithmetic that would have caught it: everything anchored from the top
    -- of a page must end above the page's own bottom edge.
    for _, name in ipairs(UI.PAGES) do
        local pageH = UI.EDGE_TO_EDGE[name] and (UI.H - UI.HEADER - 2) or (UI.H - UI.HEADER - 18 - 16)
        local page = UI.pages[name]
        local worst, worstBottom = nil, 0
        for _, fr in ipairs(H.frames) do
            local host = fr._parent
            local viaColumn = host and host._parent == page
            if host == page or viaColumn then
                local _, y = fr:OffsetFor("TOPLEFT")
                if y and y < 0 then
                    local bottom = -y + (fr:GetHeight() or 0)
                    if bottom > worstBottom then worst, worstBottom = fr, bottom end
                end
            end
        end
        H.ok(worstBottom <= pageH, "page fits: " .. name,
             ("deepest widget ends at %d, page is %d tall"):format(worstBottom, pageH))
    end
end

H.section("send bar")
UI:ShowTab("Desk")
local bar = UI.send
H.ok(#bar.buttons >= 8, "a button per channel plus yell/say/guild", #bar.buttons)
local labels = {}
for _, b in ipairs(bar.buttons) do labels[#labels + 1] = b.text:GetText() end
H.ok(table.concat(labels, " "):find("/2 Trade", 1, true) ~= nil, "channels are named and numbered")
H.ok(bar.rows >= 2, "wraps onto more than one row", bar.rows)

NS.db.previewMode = false
NS.db.customEnabled = false
NS.db.templates[NS.db.activeTemplate].text = "<{guild}> needs {needs}. Raids {times}."
local sentBefore = #H.sent
for _, b in ipairs(bar.buttons) do if b.label == "/2 Trade" then b:Click() end end
H.eq(#H.sent - sentBefore, 1, "clicking a channel button posts the ad")
H.eq(H.sent[#H.sent].chatType, "CHANNEL", "...to a channel")
H.eq(H.sent[#H.sent].target, 2, "...the right one")

local trade
for _, b in ipairs(bar.buttons) do if b.label == "/2 Trade" then trade = b end end
UI:UpdateSendTimers()
H.eq(trade.enabled, false, "the button greys out while the cooldown runs")
H.ok(trade.timer:GetText():find("|cff" .. NS.T.hex.warn, 1, true) ~= nil,
     "the countdown is painted in the warn colour", trade.timer:GetText())
local blocked = #H.sent
trade:Click()
H.eq(#H.sent, blocked, "a greyed button cannot post")
H.clock = H.clock + 11
UI:UpdateSendTimers()
H.eq(trade.enabled, true, "it comes back when the cooldown expires")
H.ok(trade.timer:GetText():find("11s", 1, true) ~= nil, "then shows time since", trade.timer:GetText())

H.section("responders")
local R = NS.Responders
R:ClearWithStatus(nil)
R:OnWhisper("hi, are you recruiting? resto shaman here", "Kumlance-Dreamscythe",
    nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-0000ABC")
local entry = NS.db.responders.Kumlance
H.ok(entry ~= nil, "the whisper landed on the list")
H.eq(entry.class, "MAGE", "class came free from the whisper GUID")
H.eq(#H.who, 0, "no protected SendWho fired from an event")

UI:LayoutDesk()
local row = UI.rows[1]
H.ok(row ~= nil, "a queue row was built")
H.ok(row.name:GetText():find("Kumlance", 1, true) ~= nil, "the row names them")
H.eq(row:GetHeight(), UI.ROW_H, "one line tall, like BiSJC's queue")

-- clicking a row serves them, and only then do the buttons appear
H.ok(not UI.served:IsShown(), "nothing served yet, no block")
row:Click()
H.eq(UI.serving, "Kumlance", "clicking a row serves them")
H.ok(UI.served:IsShown(), "and the block opens")
H.ok(UI.served.title:GetText():find("Kumlance", 1, true) ~= nil, "naming who is being served")
H.ok(UI.served.who ~= UI.served.title, "the Who button did not eat the Serving label")
row:Click()
H.ok(UI.serving == nil, "clicking again puts them down")
H.ok(not UI.served:IsShown(), "and the block closes")
row:Click()

UI.served.whisper:Click()
H.ok(H.chatOpened ~= nil, "Whisper opens a whisper to them", tostring(H.chatOpened))

H.section("the served block fits inside itself")
do
    local s2 = UI.served
    local h = s2:GetHeight()
    local _, msgY = s2.message:OffsetFor("TOPLEFT")
    local msgBottom = -msgY + (s2.message._h or 12)
    local _, actY = s2.whisper:OffsetFor("TOPLEFT")
    H.ok(msgBottom <= -actY, "the message clears the action row",
         ("message ends %d, actions start %d"):format(msgBottom, -actY))
    local _, quickY = s2.quick[1]:OffsetFor("TOPLEFT")
    H.ok(-actY + s2.whisper:GetHeight() <= -quickY, "the actions clear the quick replies")
    H.ok(-quickY + s2.quick[1]:GetHeight() <= h, "the quick replies stay inside the block")
    local wide = s2.whisper:GetWidth() + s2.discord:GetWidth() + s2.invite:GetWidth()
        + s2.who:GetWidth() + s2.logs:GetWidth() + 4 * 4 + 20
    H.ok(wide <= UI.DESK_W, "every action button fits one row of the desk",
         ("needs %d, has %d"):format(wide, UI.DESK_W))
    H.ok(s2.quick[1]:GetWidth() * 4 + 9 + 20 <= UI.DESK_W, "four quick replies fit across")
end

H.section("status pipeline")
R:SetStatus("Kumlance", "new")
UI.served.status:Click("LeftButton")
H.eq(NS.db.responders.Kumlance.status, "contacted", "left click moves the status forward")
UI.served.status:Click("RightButton")
H.eq(NS.db.responders.Kumlance.status, "new", "right click moves it back")

H.section("logs")
NS.db.logsUrl = "https://fresh.warcraftlogs.com/character/us/dreamscythe/{name}"
UI.served.logs:Click()
local box = NS.Kit.copyBox
H.ok(box ~= nil and box:IsShown(), "the copy box opened")
H.eq(box.contents, "https://fresh.warcraftlogs.com/character/us/dreamscythe/kumlance",
     "the address is built and lowercased")
H.ok(box.well.edit._highlighted, "the text is already selected for Ctrl+C")
box.well.edit:Type("oops")
H.eq(box.well.edit:GetText(), box.contents, "typing in it cannot mangle the address")

H.section("write my own")
NS.db.customEnabled = false
NS.db.customText = ""
UI:ShowTab("Recruit")
UI:RefreshPreview()
local generated = UI.lastPreview
UI:Set("override", true)
H.eq(NS.db.customText, generated, "ticking it prefills with what the template just made")
UI.previewBox.edit:Type("<The Heathens> LF chill raiders. {discord}")
H.eq(NS.db.customText, "<The Heathens> LF chill raiders. {discord}", "typing writes the custom text")
NS.db.discord = "discord.gg/heathens"
H.eq((NS.Message:Build()), "<The Heathens> LF chill raiders. discord.gg/heathens",
     "the override is what gets built, tokens and all")
UI:Set("override", false)
H.ok((NS.Message:Build()) ~= "<The Heathens> LF chill raiders. discord.gg/heathens",
     "unticking goes back to the template")
H.ok(NS.db.customText ~= "", "the custom text is kept for next time")

H.section("message hints")
UI:ShowTab("Message")
NS.db.templates[NS.db.activeTemplate].text = "{pre} - {needs} - {times} - {post}"
UI:Refresh()
H.ok(UI.guildHint:GetText():find("{guild}", 1, true) ~= nil, "warns when the ad has no {guild}")
H.ok(UI.addGuildBtn:IsShown(), "and offers the fix")
UI:Run("addGuildToken")
H.ok(UI:AdUsesToken("{guild}"), "the fix adds the token")
UI:Refresh()
H.ok(not UI.addGuildBtn:IsShown(), "the offer goes away once it is in")

H.section("sound")
for _, sound in ipairs(NS.SOUNDS) do
    H.sounds = {}
    NS.Util.PlayAlert(sound.key)
    if sound.key == "none" then
        H.eq(#H.sounds, 0, "no sound plays nothing")
    else
        H.ok(#H.sounds >= 0, "sound resolves: " .. sound.key)
    end
    H.ok(not tostring(sound.kit or ""):find("READY"), "not the ready check: " .. sound.key)
    H.ok(not tostring(sound.file or ""):find("ReadyCheck"), "not the ready check file: " .. sound.key)
end

H.sounds = {}
NS.db.autoReply.playSound = true
NS.db.autoReply.soundOnlyNew = false
NS.db.autoReply.sound = "bell"
R:OnWhisper("recruiting?", "Dps2", nil,nil,nil,nil,nil,nil,nil,nil,nil,nil)
H.eq(#H.sounds, 1, "a whisper dings")

H.section("preview mode really stops the wire")
NS.db.previewMode = true
local pBefore = #H.sent
H.clock = H.clock + 999
UI:UpdateSendTimers()
for _, b in ipairs(bar.buttons) do if b.label == "Yell" then b:Click() end end
H.eq(#H.sent, pBefore, "nothing is sent in preview mode")
UI:PaintSlots()
H.ok(UI.con.slots.preview ~= nil, "and the prompt stands on it")
H.eq(UI.con.slots.preview.colour, "warn", "in the warn colour")
NS.db.previewMode = false
UI:Refresh()
H.ok(UI.con.slots.preview == nil, "slot clears the moment the state ends")

--------------------------------------------------------------------
-- the header is a prompt (BiSTheme 1.1.0, the header law)
--------------------------------------------------------------------

H.section("the BiS> prompt in the header")
UI:Open("Responders")

local BUDGET = UI.W - UI.STRIP - 8
local function plain()
    return (tostring(UI.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
-- Step the clock in small slices, painting every slice. A single 3 s jump
-- expires a 3 s event before it is ever drawn, which is a fact about the test
-- and not about the console.
local function step(seconds, stopWhen)
    local slices = math.max(1, math.floor(seconds / 0.05))
    for _ = 1, slices do
        H.clock = H.clock + 0.05
        UI:PaintConsole()
        if stopWhen and stopWhen() then return true end
    end
    return false
end
local function settle() step(0.6) end
-- wait for a line to appear on the prompt
local function await(text, seconds)
    return step(seconds or 8, function() return plain():find(text, 1, true) ~= nil end)
end

H.ok(UI.con and UI.con.fs == UI.title, "the title FontString is the BiSTheme console")
H.ok(UI.con.words:GetParent() == UI.title:GetParent(), "the words FontString lives in the header too")
H.eq(UI.HEADER, 16, "16 px header, the house bar")
settle()
H.ok(plain():find("^BiS> "), "the line starts BiS> ", plain())
H.ok(plain():find("_$") or plain():find(" $"), "and ends on the cursor", plain())
H.ok(UI.con:Width() <= BUDGET, "prompt fits the header budget (idle)", UI.con:Width())

-- nothing but the prompt and the button strip lives in that bar
H.eq(UI.closeBtn.slot, -3, "close sits at its computed slot")
H.eq(UI.optBtn.slot, -17, "and options at its own (the book's button went with the book)")
H.eq(UI.bookBtn, nil, "no book button: every page is a tab")
for _, b in ipairs({ UI.closeBtn, UI.optBtn }) do
    H.eq(b:GetWidth(), 12, "12 px boxes, all of them")
end
H.eq(UI.STRIP, 17 + UI.optBtn:GetWidth(), "the strip is exactly the far button plus its offset")
H.ok(UI.badge == nil and UI.preview == nil, "no badge, no preview pill - both are slots now")
local inHeader = 0
for _, fr in ipairs(H.frames) do if fr._parent == UI.head then inHeader = inHeader + 1 end end
-- This count is the guard that catches the NEXT thing somebody adds to a 16 px
-- bar without predicting what it is. It went 2 -> 3 on purpose when Settings
-- stopped being a tab and became the options window, and 3 -> 2 when the book went (21 Oct 2026).
H.eq(inHeader, 2, "two frames in the header: close, options")

-- slots: state that lasts, cleared the moment it ends
NS.db.responders = {}
NS.db.previewMode, NS.db.leadFinder = false, false
NS.db.autoReply.enabled = false
UI:PaintSlots() settle()
H.ok(UI.con.slots.name and UI.con.slots.name.text == "Nebbinator", "the name slot is always there")
H.ok(UI.con.slots["new"] == nil, "no new responders: no count slot")
NS.db.responders.Bob = { name = "Dps3", status = "new", timestamp = os.time(), messages = {} }
NS.db.responders.Dps1 = { name = "Dps1", status = "trial", timestamp = os.time(), messages = {} }
UI:PaintSlots()
H.ok(UI.con.slots["new"].text == "1 new" and UI.con.slots["new"].colour == "gold", "1 new, in gold")
H.ok(UI.con.slots.trial.text == "1 on trial" and UI.con.slots.trial.colour == "good", "1 on trial, in good")

-- the rotation: name now, the count after a cycle, and no hard cut between them
-- drop anything the earlier blocks queued, and let a held line expire, so what
-- we are watching really is the slot rotation
UI:Clear() step(4)
local seen = {}
step(20, function() seen[plain()] = true return false end)
local sawName, sawCount = false, false
for line in pairs(seen) do
    if line:find("Nebbinator", 1, true) then sawName = true end
    if line:find("1 new", 1, true) then sawCount = true end
end
H.ok(sawName and sawCount, "the slots rotate through name and count")

-- Watch one whole cycle boundary go by and record what the words did. The
-- handoff asks for exactly this shape: alpha down, swap at zero, alpha up.
UI:Clear() step(4)
local sawOut, sawMid, sawZero, sawSolid = false, false, false, false
local zeroText
step(12, function()
    local a = UI.con.words:GetAlpha()
    if UI.con.fading == "out" then sawOut = true end
    if sawOut and a > 0 and a < 1 then sawMid = true end
    if sawOut and a == 0 then sawZero = true zeroText = zeroText or plain() end
    if sawZero and a == 1 and not UI.con.fading then sawSolid = true end
    return sawSolid
end)
H.ok(sawOut, "a cycle comes due and the old words start fading")
H.ok(sawMid, "alpha on the way down, not a hard cut")
H.ok(sawZero, "the swap happens at zero")
H.ok(sawSolid, "and the new words come back up solid")

-- the cursor blinks at 2 Hz and is never trimmed away
H.clock = H.clock + 0.5 UI:PaintConsole() local c1 = plain():sub(-1)
H.clock = H.clock + 0.5 UI:PaintConsole() local c2 = plain():sub(-1)
H.ok((c1 == "_" and c2 == " ") or (c1 == " " and c2 == "_"), "cursor blinks", c1 .. c2)

-- events jump the rotation, hold, and queue; and none of it reaches chat
local chat0 = #H.prints
UI:Log("Bob whispered", "gold")
UI:Log("Bob replied", "ink2")
H.ok(await("Bob whispered", 2), "an event takes the prompt first", plain())
H.ok(UI.con:Width() <= BUDGET, "prompt fits while an event is up", UI.con:Width())
H.ok(await("Bob replied", 6), "queued events show one after the other", plain())
H.eq(#H.prints, chat0, "and the chat frame got none of it")

-- a normal recruiting line is nowhere near the budget in a window this wide
UI:Clear() step(7)
UI:Log("Kumlanceroo whispered", "gold")
H.ok(await("Kumlanceroo whispered", 2), "a real event line shows in full", plain())
H.ok(not plain():find("%.%.%."), "and is not trimmed")
-- the net still works: something absurd is cut to the budget, never under the buttons
UI:Clear() step(7)
UI:Log(string.rep("a very long line indeed ", 40), "warn")
step(1)
H.ok(UI.con:Width() <= BUDGET, "an absurd line is trimmed to the budget", UI.con:Width())
H.ok(plain():find("%.%.%."), "trimmed with an ellipsis", plain():sub(1, 40))
UI:Clear() step(7)

-- the addon's own chatter goes through the prompt, not the chat frame
local chat1 = #H.prints
NS.db.previewMode = false
NS.db.templates[NS.db.activeTemplate].text = "<{guild}> needs {needs}"
H.clock = H.clock + 999 UI:UpdateSendTimers()
for _, b in ipairs(UI.send.buttons) do if b.label == "Yell" then b:Click() end end
H.eq(#H.prints, chat1, "posting the ad says nothing in chat")
H.ok(await("sent to yell", 3), "the prompt says it went", plain())

-- a slash command still answers in chat: that is what chat is for
local chat2 = #H.prints
SlashCmdList["NEBBINATOR"]("help")
H.ok(#H.prints > chat2, "/bisn help still answers in the chat frame")

H.section("the command is /bisn, the old ones still work")
-- Arn, 12 Oct 2026: the family's /bis* commands. Typed through H.Slash, which
-- routes the way the client does (SLASH_KEY1..n, stops at a gap), so an alias
-- that is set but unreachable fails here.
H.eq(SLASH_NEBBINATOR1, "/bisn", "SLASH_NEBBINATOR1 is /bisn")
do
local function helpAfter(line)
    local before = #H.prints
    local key, fn = H.Slash(line)
    local out = {}
    for i = before + 1, #H.prints do
        out[#out + 1] = (tostring(H.prints[i]):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    return key, fn, table.concat(out, "\n")
end
local k1, f1, help = helpAfter("/bisn help")
H.eq(k1, "NEBBINATOR", "/bisn reaches Nebbinator")
H.ok(help:find("/bisn config", 1, true), "the help text says /bisn", help)
H.ok(not help:find("/nb", 1, true), "the help text no longer says /nb", help)
for _, alias in ipairs({ "/nb", "/ns", "/nebbinator", "/BISN", "/NB" }) do
    local k, f = helpAfter(alias .. " help")
    H.eq(k, "NEBBINATOR", alias .. " still reaches Nebbinator")
    H.ok(f == f1, alias .. " reaches the same handler as /bisn")
end
H.eq(H.Slash("/bisnope"), nil, "a longer word is not /bisn")
end

H.section("every queue row fits the desk")
NS.db.responders = {}
R:OnWhisper("recruiting? i am a resto shaman with kara gear and logs",
    "Kumlanceroo", nil,nil,nil,nil,nil,nil,nil,nil,nil, "Player-1-1")
NS.db.responders.Kumlanceroo.level = 70
NS.db.responders.Kumlanceroo.className = "Shaman"
NS.db.responders.Kumlanceroo.guild = "Some Very Long Guild Name"
UI:LayoutDesk()
for i, r in ipairs(UI.rows) do
    if r:IsShown() then
        local _, nameX = 0, select(1, r.name:OffsetFor("LEFT"))
        local infoX = select(1, r.info:OffsetFor("LEFT"))
        H.ok(nameX + r.name:GetStringWidth() <= infoX,
             "row " .. i .. ": the name clears the class column",
             math.floor(nameX + r.name:GetStringWidth()) .. " of " .. infoX)
        H.ok(infoX + r.info:GetStringWidth() + 60 <= UI.DESK_W,
             "row " .. i .. ": name + class + age fit the desk",
             math.floor(infoX + r.info:GetStringWidth() + 60) .. " of " .. UI.DESK_W)
    end
end

--------------------------------------------------------------------
-- the shared BiS channel
--------------------------------------------------------------------

H.section("the version has somewhere to live now the header dropped it")
UI:ShowTab("About")
UI:Refresh()
H.ok(UI.aboutVersion:GetText():find(NS.VERSION, 1, true), "About names the running version", UI.aboutVersion:GetText())
H.ok(UI.aboutVersion:GetText():find("shared channel", 1, true), "and whether the shared channel is up")
H.ok(UI.aboutVersion:GetStringWidth() <= UI.colW(UI.pages.About), "and it fits the page")
UI:ShowTab("Responders")

H.section("LibBiSComm is embedded, booted, and never gated by a feature")
local lib = _G.LibBiSComm
H.ok(lib ~= nil, "the lib loaded from Libs/")
H.eq(lib and lib.MINOR, 17, "minor 17, the current one (the tram, BiS> in)")
H.ok(lib and lib._booted, "booted from Core/Init, not lazily")
-- the stub answers GetAddOnMetadata with "test": if this ever reads a literal
-- like "2.0.1" the version has been hardcoded again and drifted from the TOC
H.eq(lib and lib.addons.Nebbinator, "test", "Nebbinator registered itself with the TOC's version, not a literal")
H.eq(NS.VERSION, "test", "NS.VERSION comes from the TOC")
H.ok(lib:Enabled(), "on by default")
H.eq(NS.db.comm, nil, "nothing persisted until a logout")

-- the hard rule: no Nebbinator setting may mute the raid's channel
for _, id in ipairs({ "autoReply", "previewMode", "leadFinder", "playSound", "minimap" }) do
    UI:Set(id, false)
    H.ok(lib:Enabled(), "turning off " .. id .. " leaves the lib on")
end
UI:Set("minimap", true)

-- /bis off is the user's own switch, and Nebbinator remembers it
local bootFrame
for _, fr in ipairs(H.frames) do
    if fr._events and fr._events.PLAYER_LOGOUT then bootFrame = fr end
end
H.ok(bootFrame ~= nil, "the addon listens for PLAYER_LOGOUT")
SlashCmdList["BISCOMM"]("off")
H.ok(not lib:Enabled(), "/bis off mutes the lib")
bootFrame:Fire("OnEvent", "PLAYER_LOGOUT")
H.eq(NS.db.comm, false, "logout persists the off switch")
SlashCmdList["BISCOMM"]("on")
bootFrame:Fire("OnEvent", "PLAYER_LOGOUT")
H.ok(NS.db.comm == true and lib:Enabled(), "/bis on persists too")

-- and it comes back off on the next login
NS.db.comm = false
lib._booted = nil
NS.Comm.Boot()
H.ok(not lib:Enabled(), "a saved off switch is restored at boot")
lib:SetEnabled(true)

--------------------------------------------------------------------
-- the desk: as tall as the list and no taller
--------------------------------------------------------------------

H.section("the window keeps its shape; the desk scrolls")
UI:ShowTab("Desk")
UI.serving = nil
NS.db.responders = {}
UI.filter = "all"
UI:LayoutDesk()
local W0, H0 = UI.frame:GetWidth(), UI.frame:GetHeight()
H.ok(W0 == UI.W and H0 == UI.H, "an empty desk: the window's own size")
H.ok(not UI.listHost:IsShown(), "and no list - the count line says why")
H.ok(UI.countText:GetText():find("Nobody yet", 1, true), "Nobody yet - post the ad", UI.countText:GetText())
for i = 1, 4 do
    NS.db.responders["P" .. i] = { name = "P" .. i, status = "new",
        timestamp = os.time() - i, messages = { { text = "hi", at = os.time() } } }
    UI:LayoutDesk()
    H.ok(UI.frame:GetWidth() == W0 and UI.frame:GetHeight() == H0, i .. " waiting: the same window")
end
H.ok(UI.listHost:IsShown(), "and a list once somebody waits")
H.ok(UI.MAX_ROWS >= 20, "the page holds twenty rows and more before it scrolls", UI.MAX_ROWS)
H.ok(UI.deskUsed <= UI.DESK_H(), "the desk's parts fit its page", UI.deskUsed .. " of " .. UI.DESK_H())
local rowsIdle = UI.MAX_ROWS

for i = 1, 60 do
    NS.db.responders["Q" .. i] = { name = "Q" .. i, status = "new",
        timestamp = os.time() - i, messages = { { text = "hi", at = os.time() } } }
end
UI:LayoutDesk()
H.ok(UI.frame:GetHeight() == H0, "sixty waiting: still the same window")
H.ok(UI.listScroll.track:IsShown(), "the list scrolls instead")
H.ok(UI.rows[1]:IsShown(), "the rows are there to scroll through")

-- serving one opens the block inside the page: the list gives up the room
UI:Serve("Q1")
H.eq(UI.frame:GetHeight(), H0, "serving opens the block, not the window")
H.ok(UI.MAX_ROWS < rowsIdle and UI.served:IsShown(), "the list gives the block its room", UI.MAX_ROWS .. " of " .. rowsIdle)
H.ok(UI.deskUsed <= UI.DESK_H(), "and it all still fits the page", UI.deskUsed .. " of " .. UI.DESK_H())
local rowsServed = UI.MAX_ROWS
UI:Serve("Q2")
H.eq(UI.MAX_ROWS, rowsServed, "serving somebody else does not stack another")
UI:Serve(nil)
H.eq(UI.MAX_ROWS, rowsIdle, "putting them down gives the rows back")

-- a served responder who gets removed stops being served
UI:Serve("Q1")
NS.Responders:Remove("Q1")
H.ok(UI:ServedName() == nil and not UI.served:IsShown(), "removing the served one un-serves them, and the block goes")
NS.db.responders = {}
UI:LayoutDesk()

H.section("the tabs: the desk and the rest")
UI:ShowTab("Recruit")
H.ok(UI.pages.Recruit:IsShown() and not UI.pages.Desk:IsShown(), "a page's tab shows that page")
UI:ToggleBook(false)
H.eq(UI:ShownTab(), "Desk", "/bisn book (the minimap's right click) steps back to the desk")
UI:ToggleBook()
H.eq(UI:ShownTab(), "Recruit", "and out again to the page you were on")
UI:ShowTab("Replies")
UI:ToggleBook(false)
UI:ToggleBook(true)
H.eq(UI:ShownTab(), "Replies", "whichever that was")
H.eq(UI.frame:GetHeight(), H0, "no tab changes the window's size")
UI:Open("Responders")
H.eq(UI:ShownTab(), "Desk", "Responders (the desk's old name) opens the desk")
UI:ShowTab("Desk")
UI:LayoutDesk()

H.section("send buttons: the clock never sits on the label")
do
    local widest
    for _, b in ipairs(UI.send.buttons) do
        if b.chatType then
            b.timer:SetText("|cfff08cb088|r")           -- the widest clock it can show
            -- the label must be LEFT anchored: centred in a box that also holds
            -- a clock is exactly how "/2 Trade" got a "23" through it
            local point = b.text:OffsetFor("LEFT")
            H.ok(point ~= nil, "label is left-anchored, not centred: " .. tostring(b.label))
            local labelEnd = 7 + b.text:GetStringWidth()
            local clockStart = b:GetWidth() - 6 - b.timer:GetStringWidth()
            H.ok(labelEnd <= clockStart,
                 "clock clears the label: " .. tostring(b.label),
                 math.floor(labelEnd) .. " vs " .. math.floor(clockStart))
            if not widest or b:GetWidth() > widest:GetWidth() then widest = b end
        end
    end
    H.ok(widest ~= nil, "there were buttons to check")
end

H.section("hiding a channel you never post to")
local function labels()
    local out = {}
    for _, b in ipairs(UI.send.buttons) do if b.chatType then out[#out + 1] = b.label end end
    return out
end
local all = #labels()
H.ok(all >= 8, "every target shows by default", all)
H.ok(not UI.AnyHidden(), "nothing hidden until you hide it")

local trade
for _, b in ipairs(UI.send.buttons) do if b.label == "/2 Trade" then trade = b end end
H.ok(trade ~= nil, "found Trade")
trade:Click("RightButton")
H.eq(#labels(), all - 1, "right-click takes it off the desk")
H.ok(UI.AnyHidden(), "and the addon knows something is hidden")
H.eq(NS.db.hiddenChannels["/2 Trade"], true, "remembered in the saved variables")

-- the arrow brings the whole set back for a moment
local arrow
for _, b in ipairs(UI.send.buttons) do if not b.chatType then arrow = b end end
H.ok(arrow ~= nil, "an arrow appeared once something was hidden")
arrow:Click()
H.eq(#labels(), all, "unrolled, every target is back")
for _, b in ipairs(UI.send.buttons) do if b.label == "/2 Trade" then trade = b end end
trade:Click("RightButton")
H.eq(NS.db.hiddenChannels["/2 Trade"], nil, "right-click again un-hides it")
UI.sendExpanded = false
UI:LayoutDesk()
H.eq(#labels(), all, "and it is back on the desk for good")


H.section("the window stays where it was put")
-- Arn, 10 Sep: "every time I right click to pin or unpin it shifts the window
-- down." Relayout re-anchored to `top - height` instead of `top`, so the frame
-- fell by its own height on every single call. The harness used to answer
-- GetTop() with a constant, which is why nothing here could see it.
UI:Open()
UI:LayoutDesk()
local topBefore = UI.frame:GetTop()
local leftBefore = UI.frame:GetLeft()
H.ok(topBefore ~= nil, "the window has a top edge", tostring(topBefore))

for _, b in ipairs(UI.send.buttons) do
    if b.label == "/2 Trade" then b:Click("RightButton") break end
end
H.eq(UI.frame:GetTop(), topBefore, "pinning a channel does not move the top edge")
H.eq(UI.frame:GetLeft(), leftBefore, "and it does not move sideways either")

for _, b in ipairs(UI.send.buttons) do
    if b.label == "/2 Trade" then b:Click("RightButton") break end
end
H.eq(UI.frame:GetTop(), topBefore, "un-pinning does not move it back down either")

UI:ShowTab("Recruit")
H.eq(UI.frame:GetTop(), topBefore, "another tab leaves the top alone")
UI:ShowTab("Desk")
H.eq(UI.frame:GetTop(), topBefore, "and back")

NS.db.responders["Topcheck"] = { name = "Topcheck", status = "new",
    timestamp = os.time(), messages = { { text = "any room?", at = os.time() } } }
UI:LayoutDesk()
H.eq(UI.frame:GetTop(), topBefore, "a whisper landing does not move it either")
NS.db.responders["Topcheck"] = nil
UI:LayoutDesk()
H.eq(UI.frame:GetTop(), topBefore, "and neither does dealing with them")

H.section("the filter buttons are on the desk, not in a phantom frame")
-- The old container had one anchor and no width, so it measured 0 wide and its
-- children never drew: the desk reserved 22 px and showed a blank band.
H.eq(#UI.filterButtons, 7, "seven filters (invited, since 21 Oct 2026)")
for _, entry in ipairs(UI.filterButtons) do
    H.eq(entry.button:GetParent(), UI.desk, "the " .. entry.key .. " button hangs off the desk")
    local x, y = entry.button:OffsetFor("TOPLEFT")
    H.ok(x ~= nil and y ~= nil, "the " .. entry.key .. " button is anchored")
    H.ok(x >= 0 and x + entry.button:GetWidth() <= UI.DESK_W,
         "the " .. entry.key .. " button fits across the desk",
         tostring(x and (x + entry.button:GetWidth())) .. " of " .. UI.DESK_W)
end
-- and they do not sit on top of the count line below them
do
    local _, fy = UI.filterButtons[1].button:OffsetFor("TOPLEFT")
    local _, cy = UI.countText:OffsetFor("TOPLEFT")
    H.ok(cy < fy - 17, "the count line clears the filter row",
         tostring(cy) .. " vs " .. tostring(fy))
end

H.section("the options window")
-- Settings stopped being a tab (Arn, 10 Sep: "replaced - tab goes away") and
-- became the window every BiS addon wears. Everything the tab used to prove is
-- proved here instead, against the shared kit.
local O = BiSTheme.OPTIONS
local opt = UI:BuildOptions()

local SECTIONS = { "nebbinator", "posting", "answering", "finding people", "the guild" }
local OPTIONS = {
    "minimap button", "BiS channel (/biscomm)", "reset window position",
    "preview - never sends", "cooldown per channel", "remind me to post",
    "auto-reply", "say the class we need", "launch day: answer all", "alert sound", "only the first one", "which sound",
    "watch for \"LF guild\"", "party scout",
    "officers: ranks 0 to",
}
-- 4.0 (Arn's screenshot, 21 Oct: the help strip said "no notes on this one yet"): every row says what it does
for _, s in ipairs(UI:OptionSections()) do
    for _, o in ipairs(s.options) do H.ok(type(o.help) == "string" and o.help ~= "", "a help line: " .. o.label) end
end
-- Counted from a written-down list, NOT from UI:OptionSections() - deriving the
-- expectation from the thing under test means deleting a section changes both
-- sides and the assert cannot fail.
local haveSections, haveOptions = {}, {}
for _, s in ipairs(UI:OptionSections()) do
    haveSections[s.title] = true
    for _, o in ipairs(s.options) do haveOptions[o.label] = true end
end
for _, name in ipairs(SECTIONS) do H.ok(haveSections[name], "section: " .. name) end
for _, name in ipairs(OPTIONS) do H.ok(haveOptions[name], "option: " .. name) end
H.eq(#opt.rows, #SECTIONS + #OPTIONS, "one row per section header and per option")
H.ok(opt:GetHeight() >= O.HEADER + math.ceil(#opt.rows / (opt.columns or 1)) * O.ROW, "tall enough for every row")
H.ok(math.abs(opt:GetWidth() / opt:GetHeight() - O.RATIO) < 0.01, "and the BiSTheme standard shape, 1.43:1")
H.ok(not opt:IsShown(), "built hidden; the toggle decides")

-- budgets
H.ok(opt.con:Width() <= O.W - 15 - 8, "the prompt fits its header", opt.con:Width())
for _, r in ipairs(opt.rows) do
    local budget = r.isSection and (O.W - 6 - O.CTL) or (O.W - O.INDENT - O.CTL)
    H.ok(r.name:GetStringWidth() <= budget, "label fits: " .. tostring(r.name:GetText()),
         math.floor(r.name:GetStringWidth()) .. " of " .. budget)
    -- and every one of OUR labels was picked to fit outright: the ellipsis is
    -- the net, not the plan
    H.ok(not tostring(r.name:GetText()):find("%.%.%.$"),
         "and was not trimmed to get there: " .. tostring(r.name:GetText()))
end

local function optRow(label)
    for _, r in ipairs(opt.rows) do if r.opt and r.opt.label == label then return r end end
end

H.section("every option calls the function the slash command owns")
-- The rule that matters: no `set` here writes a saved variable itself. Proven
-- by driving the control and the slash command at the same key and watching
-- them agree, both ways round.
NS.db.previewMode = false
opt:Paint()
local prev = optRow("preview - never sends")
H.ok(prev ~= nil, "there is a preview row")
prev.ctl:Click()
H.eq(NS.db.previewMode, true, "the box turned preview on")
SlashCmdList["NEBBINATOR"]("preview")
H.eq(NS.db.previewMode, false, "/bisn preview turns the same key off")
opt:Paint()
H.eq(prev.ctl.on, false, "and the box reads the slash command's change")

NS.db.minimap.hide = false
NS.Minimap:Update()
opt:Paint()
local mm = optRow("minimap button")
H.eq(mm.ctl.on, true, "the minimap box starts on")
mm.ctl:Click()
H.eq(NS.db.minimap.hide, true, "clicking it hides the button")
-- the side effect, not just the key: NS.ToggleMinimap also calls Minimap:Update,
-- and a `set` that wrote db.minimap.hide by hand would leave the button on
-- screen with the box saying otherwise
H.eq(NS.Minimap.button:IsShown(), false, "and the button really went away")
SlashCmdList["NEBBINATOR"]("minimap")
H.eq(NS.db.minimap.hide, false, "/bisn minimap shows it again")
H.eq(NS.Minimap.button:IsShown(), true, "and it really came back")

NS.db.autoReply.enabled = false
opt:Paint()
local ar = optRow("auto-reply")
ar.ctl:Click()
H.eq(NS.db.autoReply.enabled, true, "auto-reply toggles from the window")
SlashCmdList["NEBBINATOR"]("reply")
H.eq(NS.db.autoReply.enabled, false, "and from the slash command")

H.section("the stepper clamps, and the sound one plays what it lands on")
NS.SetCooldown(10)
opt:Paint()
local cd = optRow("cooldown per channel")
cd.ctl.plus:Click()
H.eq(NS.db.sendCooldown, 15, "> raises the cooldown")
for _ = 1, 40 do cd.ctl.plus:Click() end
H.eq(NS.db.sendCooldown, 120, "and it clamps at the top")
for _ = 1, 40 do cd.ctl.minus:Click() end
H.eq(NS.db.sendCooldown, 5, "and at the bottom")
NS.SetCooldown(10)

local snd = optRow("which sound")
NS.SetSoundIndex(2)
H.sounds = {}
snd.ctl.plus:Click()
H.eq(NS.db.autoReply.sound, NS.SOUNDS[3].key, "> walks to the next sound")
H.eq(#H.sounds, 1, "and plays it, so you hear what you landed on")
for _ = 1, 40 do snd.ctl.plus:Click() end
H.eq(NS.db.autoReply.sound, NS.SOUNDS[#NS.SOUNDS].key, "the sound stepper clamps at the end")
for _ = 1, 40 do snd.ctl.minus:Click() end
H.eq(NS.db.autoReply.sound, NS.SOUNDS[1].key, "and at the start")
-- and the name it shows fits between the arrows, un-trimmed, for EVERY sound
for i = 1, #NS.SOUNDS do
    NS.SetSoundIndex(i)
    opt:Paint()
    local shown = tostring(snd.ctl.val:GetText())
    H.ok(not shown:find("%.%.%.$"), "sound name fits whole: " .. shown)
    H.ok(snd.ctl.val:GetStringWidth() <= O.STEP_V, "...between the arrows: " .. shown,
         math.floor(snd.ctl.val:GetStringWidth()) .. " of " .. O.STEP_V)
end
NS.SetSoundIndex(2)

H.section("the button row, and the ways in")
local reset = optRow("reset window position")
NS.db.window = { point = "TOPLEFT", x = 5, y = 5 }
reset.ctl:Click()
H.eq(NS.db.window.point, nil, "reset put the window back")

H.ok(not opt:IsShown(), "still hidden")
SlashCmdList["NEBBINATOR"]("config")
H.ok(opt:IsShown(), "/bisn config opens it")
H.ok(UI.optBtn.marked, "and the header box lights while it is out")
UI.optBtn:Click()
H.ok(not opt:IsShown(), "the header box closes it again")

H.section("what did not fit the four kinds went somewhere real")
-- The law: a setting that is not a toggle, seg, step or button is a slash
-- command, not a fifth control kind.
for _, r in ipairs(opt.rows) do
    if r.opt then
        H.ok(BiSTheme.OptionKinds[r.opt.kind] ~= nil,
             "known kind: " .. tostring(r.opt.kind) .. " (" .. tostring(r.opt.label) .. ")")
    end
end
SlashCmdList["NEBBINATOR"]("channels world, lookingforgroup")
H.eq(NS.db.customChannels, "world, lookingforgroup", "/bisn channels took the extra channels")
H.ok(UI.logsBox ~= nil, "and the logs address is the box on the desk")
NS.db.logsUrl = "https://x/{name}"
UI:RefreshDesk()
H.eq(UI.logsBox:Get(), "https://x/{name}", "which round-trips")

H.section("chat stays clean when the window does the talking")
local chatBefore = #H.prints
prev.ctl:Click() prev.ctl:Click()
mm.ctl:Click() mm.ctl:Click()
cd.ctl.plus:Click() cd.ctl.minus:Click()
snd.ctl.plus:Click() snd.ctl.minus:Click()
H.eq(#H.prints, chatBefore, "not one line in chat from a round of clicks")
-- but the slash command still answers in chat, because that is what a slash is
SlashCmdList["NEBBINATOR"]("preview")
H.ok(#H.prints > chatBefore, "/bisn preview still answers in the chat frame")
SlashCmdList["NEBBINATOR"]("preview")

H.section("hidden chat (Forever)")
-- (12 Oct 2026) Questie threw 46 times in Arn's BugSack reading a CHAT_MSG_SYSTEM line the game
-- had hidden. Nebbinator read whispers, channel lines and /who system lines the same way. A
-- SECRET STRING SAYS "string" to type() on Forever and refuses everything else - so the mock
-- does too (BiSTools' shape); a plain table would be caught by any type check by luck.
do
    local secretMeta = { __index = function(_, k) error("attempt to use a secret value (" .. tostring(k) .. ")", 2) end,
                         __eq = function() error("attempt to compare a secret value", 2) end,
                         __concat = function() error("attempt to concatenate a secret value", 2) end }
    local function secret() return setmetatable({}, secretMeta) end
    local realType, keepIs = type, _G.issecretvalue
    _G.type = function(v) if getmetatable(v) == secretMeta then return "string" end return realType(v) end
    _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
    local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

    NS.db.responders = {}
    R.hidden, R.toldHidden = {}, false
    local said = #H.prints
    H.ok(pcall(R.OnWhisper, R, secret(), "Kumlust", nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-2"),
        "a hidden whisper is not read")
    H.ok(pcall(R.OnWhisper, R, "recruiting?", secret()), "nor one from a hidden sender")
    H.eq(count(NS.db.responders), 0, "and nobody lands on the desk from what could not be read")
    H.eq(R.hidden.CHAT_MSG_WHISPER, 2, "both are counted")
    H.eq(#H.prints, said + 1, "the player is told once, not per whisper")
    H.ok(tostring(H.prints[#H.prints]):find("it is in your chat", 1, true), "and told where it went")
    R:OnWhisper("recruiting? resto shaman", "Kumlust")
    H.eq(count(NS.db.responders), 1, "a readable whisper lands as before")
    R:OnWhisper(secret(), "Other")
    H.eq(#H.prints, said + 2, "and the next lockdown is told again")

    local keepLead = NS.db.leadFinder
    NS.db.leadFinder = true
    H.ok(pcall(R.OnChannelMessage, R, secret(), "Seeker", nil, nil, nil, nil, nil, nil, "LookingForGroup"),
        "a hidden channel line is not lowercased for the lead finder")
    H.eq(R.hidden.CHAT_MSG_CHANNEL, 1, "and is counted")
    -- LEAN: trade chat is hundreds of lines; the guard is three questions a line, no more
    local Cost = dofile("../_bisdev/dev/cost.lua")
    local n, by = Cost.Count(function()
        for _ = 1, 500 do R:OnChannelMessage("WTS stuff", "Trader", nil, nil, nil, nil, nil, nil, "Trade") end
    end)
    H.ok(n <= 500 * 4, "500 channel lines cost at most 4 client calls each: " .. n, Cost.Top(by, 4))
    H.say(("   cost: 500 channel lines = %d calls (%s)"):format(n, Cost.Top(by, 4)))
    NS.db.leadFinder = keepLead

    R.whoBusy = true
    H.ok(pcall(R.OnSystemMessage, R, secret()), "a hidden system line during our /who is not parsed")
    local filter = H.filters.CHAT_MSG_SYSTEM
    local okF, shown = pcall(filter, nil, nil, secret())
    H.ok(okF and shown == false, "and the chat filter leaves it for the game to show")
    R.whoBusy = false

    _G.type, _G.issecretvalue = realType, keepIs
    NS.db.responders = {}
    R.hidden, R.toldHidden = {}, false
end

H.section("every label fits its window")
-- (6 Oct 2026) Arn: "a check for cut offs or overflows that happens often".
-- H.fitsIn (harness) measures every shown label where it really starts and
-- wants it to end inside the window. Run over every window this suite drives,
-- empty, full, and with the longest real names it uses. Forever names carry a
-- surname ("Kumlust Surname", solved.md) and no realm, so the queue gets one.
do
    local LONG = "Kumlanceroo Wildhammer"
    local frame = UI.frame
    UI:Open()
    UI:ToggleBook(false)
    UI:Serve(nil)
    UI.filter = "all"
    NS.db.responders = {}
    NS.db.autoReply.enabled = false
    UI:LayoutDesk()
    H.fitsIn(frame, "the desk, empty")

    UI.filter = "declined"
    NS.db.responders.Dps1 = { name = "Dps1", status = "new", timestamp = os.time(), messages = {} }
    UI:LayoutDesk()
    H.fitsIn(frame, "the desk, a filter with nobody in it")
    UI.filter = "all"

    NS.db.autoReply.enabled = true
    R:OnWhisper("recruiting? i am a resto shaman with kara gear and logs", LONG,
        nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-2")
    local e = NS.db.responders[LONG]
    e.level, e.className, e.guild = 70, "Shaman", "Some Very Long Guild Name"
    NS.db.responders.Leadlady = { name = "Leadlady", status = "contacted", source = "channel",
        level = 70, className = "Warlock", guild = "Some Very Long Guild Name",
        timestamp = os.time() - 7200, messages = { { text = "LF guild", at = os.time() } } }
    UI:LayoutDesk()
    H.fitsIn(frame, "the desk, a long Forever name in the queue")

    UI:Serve(LONG)
    H.fitsIn(frame, "the desk, serving the long name")

    -- every send button with its clock running
    NS.db.previewMode = false
    H.clock = H.clock + 999
    for _, b in ipairs(UI.send.buttons) do if b.chatType then b:Click() end end
    UI:UpdateSendTimers()
    H.fitsIn(frame, "the desk, every send clock counting down")

    UI:Clear() step(7)
    UI:Log(LONG .. " whispered", "gold")
    await(LONG .. " whispered", 2)
    H.fitsIn(frame, "the header with an event up")

    UI:ToggleBook(true)
    for _, name in ipairs(UI.PAGES) do
        UI:ShowTab(name)
        H.fitsIn(frame, "the book: " .. name)
    end
    -- the Message page's warning only shows when the ad has no {guild}
    UI:ShowTab("Message")
    NS.db.templates[NS.db.activeTemplate].text = "{pre} - {needs} - {times} - {post}"
    UI:Refresh()
    H.fitsIn(frame, "the book: Message, warning up")
    UI:ToggleBook(false)

    UI.served.logs:Click()
    H.fitsIn(NS.Kit.copyBox, "the copy box")
    NS.Kit.copyBox:Hide()

    UI:ToggleOptions(true)
    for i = 1, #NS.SOUNDS do
        NS.SetSoundIndex(i)
        opt:Paint()
        H.fitsIn(opt, "the options window, sound " .. i)
    end
    NS.SetSoundIndex(2)
    UI:ToggleOptions(false)

    UI:Serve(nil)
    NS.db.responders = {}
    UI:LayoutDesk()
    if os.getenv("FIT") then
        for _, f in ipairs(H.fitLog) do H.say(("   fit: %-45s %d labels"):format(f.what, f.measured)) end
    end
end

H.section("embedded libs are the canonical bytes")
-- The lib is edited in _bisdev (Console in BiSTheme) and copied out by
-- _bisdev/sync.ps1; a stale copy in an addon is how three addons kept shipping
-- minor 4 after minor 5 fixed the phantom summon. Run from the addon folder, the
-- siblings are one level up; when they are not (a bare checkout) the check says
-- so and skips instead of lying green. Options.lua joined 11 Sep pm (minor 2).
do
    local function bytes(path)
        local fh = io.open(path, "rb")
        if not fh then return nil end
        local b = fh:read("*a") fh:close()
        return b
    end
    local canon = {
        { "Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua", "../_bisdev/LibBiSComm-1.0/LibBiSComm-1.0.lua" },
        { "Libs/BiSTheme/Console.lua",              "../BiSTheme/Console.lua" },
        { "Libs/BiSTheme/Options.lua",              "../BiSTheme/Options.lua" },
        { "Libs/BiSTheme/Minimap.lua",              "../BiSTheme/Minimap.lua" },
    }
    for _, pr in ipairs(canon) do
        local mine, ref = bytes(pr[1]), bytes(pr[2])
        H.ok(mine ~= nil, "embedded " .. pr[1] .. " is on disk")
        if ref then
            H.ok(mine == ref, "embedded " .. pr[1] .. " is byte-identical to " .. pr[2] .. " (run _bisdev/sync.ps1)")
        else
            H.say("   (canonical " .. pr[2] .. " not beside this checkout - embed check skipped)")
        end
    end
end

-- WHAT A SECOND COSTS, IN CLIENT CALLS (7 Oct 2026). BiSHealing asked the client ~630,000 things
-- a second and every suite was green; Arn: "make sure stuff like this does not happen". The one
-- thing here that runs all session is the send ticker. With the window CLOSED it should do
-- nothing at all; it used to walk every responder and repaint the prompt 4 times a second.
do
    local Cost = dofile("../_bisdev/dev/cost.lua")
    local tk = UI.sendTicker
    H.ok(tk ~= nil, "(cost) the send ticker is running")
    local function second() for _ = 1, 60 do H.clock = H.clock + 1 / 60 tk:Fire("OnUpdate", 1 / 60) end end
    local wasShown = UI.frame:IsShown()
    UI.frame:Show()
    local open, oby = Cost.Count(second)
    UI.frame:Hide()
    local closed, cby = Cost.Count(second)
    if wasShown then UI.frame:Show() end
    H.say(("   cost: send ticker, 1 s = %d calls open, %d closed"):format(open, closed))
    H.ok(closed == 0, "a closed window's ticker asks the client nothing: " .. closed, Cost.Top(cby, 4))
    H.ok(open <= 80, "an open window's second asks at most 80 things: " .. open, Cost.Top(oby, 4))

    -- THE GUILD ROSTER IS READ WHEN ASKED. GUILD_ROSTER_UPDATE fires whenever anyone logs on or
    -- off or any addon asks; a 500-member guild walked 500 rows each time. Fifty pings, no walk -
    -- then the auto-reply asks once and gets a fresh answer.
    local R = NS.Responders
    local realN, realInfo = _G.GetNumGuildMembers, _G.GetGuildRosterInfo
    local roster = {}
    for i = 1, 500 do roster[i] = "Member" .. i end
    _G.GetNumGuildMembers = function() return #roster end
    _G.GetGuildRosterInfo = function(i) return roster[i] end
    local pinged = Cost.Count(function()
        for _ = 1, 50 do R.frame:Fire("OnEvent", "GUILD_ROSTER_UPDATE") end
    end)
    H.ok(pinged == 0, "fifty roster pings read the roster zero times: " .. pinged)
    roster[501] = "Newbie-Realm"
    local asked = Cost.Count(function()
        H.ok(R:IsGuildMember("newbie"), "a member who joined during the pings is known when asked")
        H.ok(not R:IsGuildMember("stranger"), "and a stranger is not")
    end)
    H.ok(asked <= 510, "and asking reads it once, not once per ping: " .. asked)
    _G.GetNumGuildMembers, _G.GetGuildRosterInfo = realN, realInfo
end

H.section("api (NebbinatorAPI, playbook 5a)")
-- Every function, ready (here) and not ready (the load section, before login). Answers are copies:
-- edit one, ask again, unchanged. Nothing through the API posts or whispers.
do
    local A = _G.NebbinatorAPI
    local R = NS.Responders
    H.eq(A.Ready(), true, "(api) ready after login")

    -- callbacks first, so the whisper below is announced
    local heard = {}
    H.eq(A.RegisterCallback("Test", "Nebbinator_NewRecruit", function(ev, name, source)
        heard[#heard + 1] = ev .. ":" .. tostring(name) .. ":" .. tostring(source)
    end), true, "(api) a callback registers")
    H.ok(A.RegisterCallback("Test", "Nebbinator_Whisper", function(ev, name, text)
        heard[#heard + 1] = ev .. ":" .. tostring(name) .. ":" .. tostring(text)
    end), "(api) a second event registers")
    H.ok(A.RegisterCallback("Broken", "Nebbinator_Whisper", function() error("caller's bug") end),
        "(api) a broken callback registers too")
    local okBad, whyBad = A.RegisterCallback("Test", "Nebbinator_Nope", function() end)
    H.eq(okBad, nil, "(api) an unknown event is refused")
    H.eq(whyBad, "no such event", "(api) ...and says so")
    H.eq(select(2, A.RegisterCallback("Test", "Nebbinator_Whisper", "notafunction")), "bad callback",
        "(api) a callback that is not a function is refused")

    R:ClearWithStatus(nil)
    local wasAuto = NS.db.autoReply.enabled
    NS.db.autoReply.enabled = false      -- an auto-reply would move them to "contacted"
    local ok = pcall(R.OnWhisper, R, "recruiting? resto shaman", "Kumlance-Dreamscythe",
        nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-0000ABC")
    H.ok(ok, "(api) a caller's erroring callback never reaches the whisper handler")
    H.eq(heard[1], "Nebbinator_NewRecruit:Kumlance:whisper", "(api) NewRecruit fired with name and source")
    H.eq(heard[2], "Nebbinator_Whisper:Kumlance:recruiting? resto shaman", "(api) Whisper fired with the text")
    R:OnWhisper("still there?", "Kumlance-Dreamscythe")
    H.eq(#heard, 3, "(api) a second whisper is a Whisper, not a NewRecruit")
    H.eq(heard[3], "Nebbinator_Whisper:Kumlance:still there?", "(api) ...with its text")

    local wasLF = NS.db.leadFinder
    NS.db.leadFinder = true
    R:OnChannelMessage("LF guild, resto druid", "Leafy-Realm", nil, nil, nil, nil, nil, nil, "Trade")
    NS.db.leadFinder = wasLF
    H.eq(heard[4], "Nebbinator_NewRecruit:Leafy:channel", "(api) the lead finder announces a NewRecruit")

    local sentBefore = #H.sent

    -- Recruits / Recruit (the test runs inside one second; make Leafy plainly the newer)
    NS.db.responders.Leafy.timestamp = NS.db.responders.Kumlance.timestamp + 60
    local list = A.Recruits()
    H.eq(#list, 2, "(api) Recruits lists both")
    H.eq(list[1].name, "Leafy", "(api) newest first")
    local k = A.Recruit("Kumlance-Dreamscythe")
    H.ok(k ~= nil, "(api) Recruit finds a name with its realm on")
    H.eq(k.name, "Kumlance", "(api) ...keyed without the realm")
    H.eq(k.classFile, "MAGE", "(api) classFile from the whisper GUID")
    H.eq(k.source, "whisper", "(api) source")
    H.eq(k.status, "new", "(api) status")
    H.eq(#k.messages, 2, "(api) both whispers kept")
    H.eq(k.messages[2].text, "still there?", "(api) oldest first")
    H.ok(type(k.lastAt) == "number", "(api) lastAt is a number")
    k.name, k.status, k.messages[1].text = "Edited", "accepted", "edited"
    k.messages[3] = { text = "added" }
    local again = A.Recruit("Kumlance")
    H.eq(again.name, "Kumlance", "(api) editing a Recruit answer does not touch the desk: name")
    H.eq(again.status, "new", "(api) ...status")
    H.eq(again.messages[1].text, "recruiting? resto shaman", "(api) ...messages")
    H.eq(#again.messages, 2, "(api) ...message count")
    H.eq(#NS.db.responders.Kumlance.messages, 2, "(api) ...and the saved table is untouched")
    list[1].status = "declined"
    table.remove(list, 2)
    local list2 = A.Recruits()
    H.eq(#list2, 2, "(api) editing a Recruits answer does not touch the desk: count")
    H.eq(list2[1].status, "new", "(api) ...status")
    H.eq(#A.Recruits("new"), 2, "(api) Recruits filters by status")
    H.eq(#A.Recruits("trial"), 0, "(api) ...an empty status is an empty list")
    H.eq(select(2, A.Recruits("bogus")), "no such status", "(api) an unknown status is refused")
    H.eq(select(2, A.Recruit("Nobody")), "no such recruit", "(api) an unknown name says so")
    H.eq(select(2, A.Recruit("")), "no name", "(api) a blank name says so")
    H.eq(select(2, A.Recruit(42)), "no name", "(api) a number is not a name")

    -- CountNew
    H.eq(A.CountNew(), 2, "(api) CountNew")
    R:SetStatus("Leafy", "contacted")
    H.eq(A.CountNew(), 1, "(api) CountNew follows the desk")

    -- Ad
    local text, missing = A.Ad()
    local want = NS.Message:Build()
    H.eq(text, want, "(api) Ad is what the send bar would post")
    H.ok(type(missing) == "table", "(api) Ad answers the empty tokens as a list")
    missing[#missing + 1] = "{edited}"
    local _, missing2 = A.Ad()
    H.eq(#missing2, #missing - 1, "(api) editing Ad's list does not stick")

    -- Status
    local s = A.Status()
    H.eq(s.version, NS.VERSION, "(api) Status version")
    H.eq(s.preview, NS.db.previewMode and true or false, "(api) Status preview")
    H.eq(s.recruits, 2, "(api) Status recruits")
    H.eq(s.new, 1, "(api) Status new")
    H.eq(s.template, NS.Message:ActiveTemplate().name, "(api) Status template")
    H.ok(s.lastPostAt == nil or type(s.lastPostAt) == "number", "(api) lastPostAt is a time or nil")
    s.preview, s.recruits = "edited", 99
    local s2 = A.Status()
    H.eq(s2.recruits, 2, "(api) editing Status does not stick")
    H.eq(s2.preview, NS.db.previewMode and true or false, "(api) ...nor change the setting")

    -- Open
    UI:Hide()
    H.eq(A.Open(), true, "(api) Open answers true")
    H.eq(UI.frame:IsShown(), true, "(api) ...and the window is open")
    H.eq(A.Open("Replies"), true, "(api) Open on a page")
    H.eq(UI:ShownTab(), "Replies", "(api) ...shows that page")
    H.eq(select(2, A.Open("Nope")), "no such page", "(api) an unknown page is refused")
    UI:ShowTab("Recruit")
    UI:Hide()

    H.eq(#H.sent, sentBefore, "(api) nothing the API did posted or whispered")

    -- unregister: silence, and unknown pairs are harmless
    H.eq(A.UnregisterCallback("Test", "Nebbinator_Whisper"), true, "(api) unregister answers true")
    A.UnregisterCallback("Test", "Nebbinator_NewRecruit")
    A.UnregisterCallback("Broken", "Nebbinator_Whisper")
    H.ok(pcall(A.UnregisterCallback, "Nobody", "Nebbinator_Nope"), "(api) unregistering nothing is harmless")
    R:OnWhisper("hello again", "Kumlance")
    H.eq(#heard, 4, "(api) after unregistering, nothing is heard")
    R:ClearWithStatus(nil)
    NS.db.autoReply.enabled = wasAuto
end

-- ===================================================================== 21 Oct 2026: the review
-- Arn: "this is a forever addon no more tbc support" - the Forever fixes. A function: the main chunk is
-- near Lua's 200 locals.
;(function()
    local R, M, U = NS.Responders, NS.Message, NS.Util
    local wasPreview = NS.db.previewMode
    NS.db.previewMode = false

    H.section("review: sounds by kit id only (a game file is silent on Forever)")
    local played, files = {}, 0
    local realPS, realPSF = _G.PlaySound, _G.PlaySoundFile
    _G.PlaySound = function(id) played[#played + 1] = id return true end
    _G.PlaySoundFile = function() files = files + 1 return true end
    for _, snd in ipairs(NS.SOUNDS) do
        H.ok(snd.key == "none" or (type(snd.kit) == "number" and snd.file == nil), "a kit id, no file: " .. snd.key)
    end
    U.PlayAlert("bell")
    H.ok(played[1] == 6594 and files == 0, "the default bell plays its kit, and no file is ever tried", tostring(played[1]))
    _G.PlaySound, _G.PlaySoundFile = realPS, realPSF

    H.section("review: a long ad, a click per part")
    local realBuild = M.Build
    local long = string.rep("word ", 70)                        -- 350 characters: two parts
    M.Build = function() return U.Trim(long), {} end
    M.lastSend = {}
    local before = #H.sent
    M:Send("CHANNEL", "Trade")
    H.eq(#H.sent, before + 1, "the click sends part one, and only part one")
    H.RunTimers()
    H.eq(#H.sent, before + 1, "nothing follows on a timer - the game refuses a public post without a click")
    H.eq(M:PendingFor("CHANNEL", "Trade"), "2/2", "the button says part 2 of 2 is waiting")
    M:Send("CHANNEL", "Trade")
    H.ok(#H.sent == before + 2 and H.sent[#H.sent].chatType == "CHANNEL", "the next click sends part two")
    H.eq(M:PendingFor("CHANNEL", "Trade"), nil, "and the button is a send button again")
    M.lastSend = {}
    before = #H.sent
    M:Send("GUILD")
    H.RunTimers()
    H.eq(#H.sent, before + 2, "guild chat is no public channel: both parts, the second on a timer")
    M.Build = realBuild

    H.section("review: when the game holds chat back")
    local locked = true
    _G.C_ChatInfo.InChatMessagingLockdown = function() return locked end
    M.lastSend = {}
    before = #H.sent
    M:Send("CHANNEL", "Trade")
    H.eq(#H.sent, before, "no post while the game holds chat back")
    M:SendWhisper("Kumlance", "hello there")
    H.eq(#H.sent, before, "a whisper waits")
    H.eq(#M.queue, 1, "held, not lost")
    locked = false
    H.RunTimers()
    H.ok(#H.sent == before + 1 and H.sent[#H.sent].target == "Kumlance" and #M.queue == 0, "and goes the moment it is allowed")
    _G.C_ChatInfo.InChatMessagingLockdown = nil

    H.section("review: the logs address reads your realm and region")
    local realRealm, realRegion = _G.GetRealmName, _G.GetCurrentRegion
    _G.GetRealmName = function() return "Living Flame" end
    _G.GetCurrentRegion = function() return 3 end
    local keepUrl = NS.db.logsUrl
    NS.db.logsUrl = "https://fresh.warcraftlogs.com/character/{region}/{realm}/{name}"   -- the new default
    H.eq(R:LogsUrl("Kumlance"), "https://fresh.warcraftlogs.com/character/eu/living-flame/kumlance",
         "realm and region from the client, as Warcraft Logs writes them")
    _G.GetRealmName, _G.GetCurrentRegion = realRealm, realRegion
    NS.db.logsUrl = keepUrl

    H.section("review: joined, declined and invited")
    R:ClearWithStatus(nil)
    R:OnWhisper("hi, recruiting?", "Joiner")
    R:OnWhisper("hi", "Decliner")
    _G.ERR_GUILD_JOIN_S, _G.ERR_GUILD_DECLINE_S = "%s has joined the guild.", "%s declines your guild invitation."
    R.frame:Fire("OnEvent", "CHAT_MSG_SYSTEM", "Joiner has joined the guild.")
    H.ok(NS.db.responders.Joiner.status == "accepted" and NS.db.responders.Joiner.joinedAt,
         "the game says they joined: Accepted, by itself")
    R.frame:Fire("OnEvent", "CHAT_MSG_SYSTEM", "Decliner declines your guild invitation.")
    H.eq(NS.db.responders.Decliner.status, "declined", "declined the invite: Declined")
    R:OnWhisper("hi", "Invitee")
    R:InviteToGuild("Invitee")
    H.eq(NS.db.responders.Invitee.status, "invited", "invited is Invited - not Trial before they say yes")

    H.section("review: a desk that forgets")
    local now = os.time()
    NS.db.responders = {
        Old = { name = "Old", status = "contacted", timestamp = now - 40 * 86400 },
        Trialist = { name = "Trialist", status = "trial", timestamp = now - 40 * 86400 },
        Ancient = { name = "Ancient", status = "accepted", timestamp = now - 100 * 86400 },
        Fresh = { name = "Fresh", status = "new", timestamp = now - 86400 },
    }
    H.eq(R:Tidy(now), 2, "a word a month ago, or anything three months ago, goes")
    H.ok(NS.db.responders.Fresh and NS.db.responders.Trialist and not NS.db.responders.Old, "the rest stays")
    NS.db.responders = {}
    for i = 1, R.KEEP_MAX + 20 do NS.db.responders["P" .. i] = { name = "P" .. i, status = "new", timestamp = now - i } end
    R:Tidy(now)
    local n = 0
    for _ in pairs(NS.db.responders) do n = n + 1 end
    H.ok(n == R.KEEP_MAX and NS.db.responders.P1 and not NS.db.responders["P" .. (R.KEEP_MAX + 1)],
         "never more than " .. R.KEEP_MAX .. ", the oldest going first")
    NS.db.responders = {}

    H.section("review: the auto-reply says the class we need, and launch day")
    local ar = NS.db.autoReply
    local keep = { ar.enabled, ar.mode, ar.busy, ar.skipGuildies }
    ar.enabled, ar.mode, ar.skipGuildies = true, "any", false
    NS.db.needs.shaman.resto = 2
    before = #H.sent
    R:OnWhisper("hi! resto shaman looking for a raiding guild", "Shammy")
    H.ok(#H.sent == before + 1 and H.sent[#H.sent].msg:find("We need 2 Resto Shaman right now.", 1, true),
         "a shaman asks: the reply says we need 2 Resto Shaman", H.sent[#H.sent] and H.sent[#H.sent].msg)
    ar.busy, ar.mode = true, "keywords"
    before = #H.sent
    R:OnWhisper("hey", "Rushhour")
    H.ok(#H.sent == before + 1 and H.sent[#H.sent].msg:find("swamped", 1, true), "launch-day mode: everyone, keywords or not")
    ar.enabled, ar.mode, ar.busy, ar.skipGuildies = keep[1], keep[2], keep[3], keep[4]
    NS.db.needs.shaman.resto = 0
    R:ClearWithStatus(nil)
    NS.db.previewMode = wasPreview
end)()

--------------------------------------------------------------------
-- 21 Oct 2026: the guild's desk, the party scout, the cards, what works
--------------------------------------------------------------------

;(function()
    local T, R, Sc, C, St, M = NS.Team, NS.Responders, NS.Scout, NS.Cards, NS.Stats, NS.Message
    local now = os.time()
    local wasPreview = NS.db.previewMode
    NS.db.previewMode = false
    local function onWire(cmd)
        -- on the wire, or in the shared outbox (one message a second for every BiS addon: it waits its turn)
        local all = {}
        for _, w in ipairs(H.wire) do all[#all + 1] = w end
        for _, w in ipairs(_G.LibBiSComm.outbox or {}) do all[#all + 1] = w end
        for i = #all, 1, -1 do
            if all[i].msg:find("NEB", 1, true) and all[i].msg:find(cmd, 1, true) and all[i].chan ~= "RAID" then return all[i].msg end
        end
        return nil
    end
    local function asRank(rank)
        H.guild = { { name = "Kumlust-Dreamscythe", rank = rank }, { name = "Officerton-Dreamscythe", rank = 1 },
                    { name = "Grunt-Dreamscythe", rank = 4 } }
        R.rosterDirty = true
    end

    H.section("the guild's desk: who is an officer")
    asRank(4)
    H.eq(T.Rank("Officerton"), 1, "a rank read off the roster (the realm dropped)")
    H.ok(not T.IsOfficer(), "rank 4 is not an officer")
    H.ok(T.IsOfficer("Officerton"), "rank 1 is (BiS Guild's rule: 0..officerRank)")
    H.ok(not T.IsOfficer("Stranger"), "nobody outside the roster is")

    H.section("the guild's desk: a member keeps only who is a prospect")
    NS.db.team = {}
    H.wire = {}
    T.Changed({ name = "Lfgplz", status = "contacted", class = "PRIEST", level = 60, note = "wants raids", timestamp = now })
    local row = T.List().Lfgplz
    H.ok(row and row.status == "contacted" and row.by == "Kumlust", "the row is mine at once: who and how far")
    H.ok(row and row.note == nil and row.class == nil, "a member keeps no note and no class (Arn: summary for officers)")
    H.ok(onWire("REC"), "and the guild hears it (NEB REC on the wire)")
    local ok, by, status = T.Prospect("Lfgplz-Dreamscythe")
    H.ok(ok == true and by == "Kumlust" and status == "contacted", "Prospect answers yes, who, how far", tostring(by))

    H.section("the guild's desk: an officer keeps the summary")
    asRank(1)
    T.Took("Grunt", "Healzor", "trial", "PRIEST", "60", "Grunt", tostring(now), "good logs")
    row = T.List().Healzor
    H.ok(row and row.class == "PRIEST" and row.level == 60 and row.note == "good logs" and row.by == "Grunt",
         "class, level and the note, and who sent it")
    T.Took("Grunt", "Healzor", "new", "", "", "Grunt", tostring(now - 100), "")
    H.eq(T.List().Healzor.status, "trial", "an older word about them changes nothing")
    T.Took("Grunt", "Healzor", "accepted", "PRIEST", "60", "Grunt", tostring(now + 1), "")
    H.eq((T.Prospect("Healzor")), false, "joined is not a prospect any more")
    T.List().Stale = { name = "Stale", status = "contacted", by = "Grunt", at = now - 31 * 86400 }
    H.eq((T.Prospect("Stale")), false, "a month untouched is not one either")
    H.eq(T.Tidy(now), 1, "and the tidy takes it off the list")

    H.section("the guild's desk: officers set what the guild needs")
    H.eq(T.Pack(T.Unpack("shaman.resto=2,druid.feral=1")), "druid.feral=1,shaman.resto=2", "the needs line goes there and back, in class order")
    local up = T.Unpack("shaman.resto=40,nope.nope=3,warrior.bogus=1")
    H.ok(up.shaman.resto == 9 and up.nope == nil and up.warrior.bogus == nil, "capped at 9; unknown classes and specs dropped")
    asRank(4)
    local got, why = T.SetNeeds()
    H.ok(got == nil and why == "officers only", "a member cannot set them", why)
    asRank(1)
    local keep = NS.db.needs
    H.wire = {}
    NS.db.needsAt = nil
    H.ok(T.SetNeeds(nil, true), "an officer can")
    H.ok(NS.db.needsAt ~= nil and NS.db.needsBy == "Kumlust", "stamped, and by whom")
    H.ok(onWire("NEEDS"), "and the guild hears them (NEB NEEDS)")
    local stamp = NS.db.needsAt
    H.ok(not T.Adopt("Grunt", stamp + 10, "warrior.prot=3"), "needs from a member are ignored")
    H.ok(not T.Adopt("Officerton", stamp - 10, "warrior.prot=3"), "older needs from an officer too")
    H.ok(T.Adopt("Officerton", stamp + 10, "warrior.prot=3") and NS.db.needs.warrior.prot == 3 and NS.db.needs.shaman.resto == 0,
         "newer needs from an officer replace ours whole")
    H.eq(NS.db.needsBy, "Officerton", "and say who set them")
    NS.db.needs, NS.db.needsAt, NS.db.needsBy = keep, nil, nil
    asRank(4)

    H.section("the party scout: who gets a card")
    for _, c in ipairs(NS.CLASSES) do for _, s in ipairs(c.specs) do NS.db.needs[c.key][s.key] = 0 end end
    NS.db.needs.shaman.resto = 2
    NS.db.scoutSeen, NS.db.team = {}, {}
    H.inParty = true
    H.raid = { { name = "Kumlust", class = "MAGE", guild = "The Heathens" },
               { name = "Shammy", class = "SHAMAN" },
               { name = "Guildy", class = "SHAMAN", guild = "Other Guild" },
               { name = "Ourguy", class = "SHAMAN", guild = "The Heathens", ours = true },
               { name = "Stabby", class = "ROGUE" } }
    local look = Sc.Look("party1")
    H.ok(look and look.name == "Shammy" and look.guild == nil and look.want == "2 Resto Shaman",
         "a needed class without a guild: we need 2 Resto Shaman", look and look.want)
    look = Sc.Look("party2")
    H.ok(look and look.guild == "Other Guild", "one with a guild: named")
    local nobody, because = Sc.Look("party3")
    H.ok(nobody == nil and because == "ours already", "a guildmate: no card", because)
    nobody, because = Sc.Look("party4")
    H.ok(nobody == nil and because == "a class we do not need", "a class we do not need: none", because)
    nobody, because = Sc.Look("party5")
    H.ok(nobody == nil and because == "nobody", "the client has no party5", because)
    H.raid[2].role = "DAMAGER"
    nobody, because = Sc.Look("party1")
    H.ok(nobody == nil, "the group finder made them dps, and we need a resto: no card", because)
    H.raid[2].role = "HEALER"
    H.ok(Sc.Look("party1"), "made them a healer: the card")
    H.raid[2].role = nil

    H.section("the party scout: big without a guild, small with one")
    while #C.up > 0 do C.Hide(C.up[1]) end
    local sounds = #H.sounds
    H.eq(Sc.Check(), 2, "two cards: the guildless shaman and the guilded one")
    H.ok(#C.up == 2 and C.up[1].size == C.BIG and C.up[2].size == C.SMALL, "the guildless one big, the guilded one small")
    H.ok(C.up[1].title._text:find("SHAMMY - A SHAMAN WITHOUT A GUILD", 1, true), "the big card names them and why", C.up[1].title._text)
    H.eq(#H.sounds, sounds + 1, "and only the big one makes a sound")
    H.ok(H.realWidth(C.up[1].title) <= C.BIG.w - 30, "its title fits the card", H.realWidth(C.up[1].title))
    H.ok(C.up[2].title._text:find("<Other Guild>", 1, true), "the small one says whose they are", C.up[2].title._text)
    H.eq(Sc.Check(), 0, "the same group again: no cards (once a week each)")
    NS.db.scoutSeen.Shammy = now - 8 * 86400
    H.eq(Sc.Check(), 1, "a week on, Shammy's card comes back")
    NS.db.scout = false
    NS.db.scoutSeen = {}
    H.eq(Sc.Check(), 0, "/bisn scout off: none")
    NS.db.scout = true

    H.section("the party scout: somebody the guild is already talking to")
    while #C.up > 0 do C.Hide(C.up[1]) end
    NS.db.scoutSeen = {}
    T.List().Shammy = { name = "Shammy", status = "contacted", by = "Officerton", at = now - 2 * 86400 }
    Sc.Check()
    H.ok(C.up[1].sub._text:find("Officerton talked to them 2 days ago - nudge them to join", 1, true),
         "the card says who and when: nudge them", C.up[1].sub._text)

    H.section("the party scout: the buttons")
    local before = #H.sent
    NS.db.responders = {}
    C.up[1].buttons[1]:Click()
    H.ok(#H.sent == before + 1 and H.sent[#H.sent].target == "Shammy" and H.sent[#H.sent].msg:find("want to raid with us", 1, true),
         "Ask them whispers them", H.sent[#H.sent] and H.sent[#H.sent].msg)
    H.ok(H.sent[#H.sent].msg:find("2 Resto Shaman", 1, true) and not H.sent[#H.sent].msg:find("{", 1, true), "with what we need, tokens filled")
    local e = NS.db.responders.Shammy
    H.ok(e and e.status == "contacted" and e.source == "party", "and puts them on the desk as contacted, met in a group")
    H.ok(T.List().Shammy.by == "Kumlust", "and the guild hears I am talking to them now")
    H.eq(#C.up, 1, "the card it was on goes")
    C.up[1].buttons[2]:Click()
    H.ok(NS.db.responders.Guildy and NS.db.responders.Guildy.status == "new" and NS.db.responders.Guildy.guild == "Other Guild",
         "To desk: on the desk, nothing sent")

    H.section("the party scout: a raid forming looks once, after it settles")
    NS.db.scoutSeen = {}
    while #C.up > 0 do C.Hide(C.up[1]) end
    H.timers = {}
    for _ = 1, 5 do Sc.frame:Fire("OnEvent", "GROUP_ROSTER_UPDATE") end
    H.eq(#H.timers, 1, "five changes, one wait")
    H.RunTimers()
    H.ok(#C.up == 0 and #H.timers == 1, "still changing: it waits again")
    H.clock = H.clock + Sc.SETTLE + 1
    H.RunTimers()
    H.eq(#C.up, 2, "settled: one look, the cards")
    H.inParty = false
    H.raid = { { name = "Kumlust" } }
    H.timers = {}

    H.section("the cards: a stack, a drain, a hold")
    while #C.up > 0 do C.Hide(C.up[1]) end
    H.eq(C.ticker:GetScript("OnUpdate"), nil, "no card: nothing ticks")
    for i = 1, C.MAX + 2 do C.Show({ title = "card " .. i }) end
    H.eq(#C.up, C.MAX, "never more than " .. C.MAX .. " up")
    H.eq(C.up[1].title._text, "card 3", "the oldest went for the new ones")
    H.ok(C.ticker:GetScript("OnUpdate") ~= nil, "cards up: it ticks")
    C.up[1].held = true
    C.Tick(C.SECS + 1)
    H.ok(#C.up == 1 and C.up[1].title._text == "card 3", "a card under the mouse holds; the others drained away")
    C.up[1].held = nil
    C.Tick(C.SECS + 1)
    H.eq(#C.up, 0, "let go, it drains too")
    H.eq(C.ticker:GetScript("OnUpdate"), nil, "and the ticker stops")
    for i = 1, C.MAX do C.Show({ title = "card " .. i, big = i == 1, buttons = { { "A", function() end } } }) end
    local Cost = dofile("../_bisdev/dev/cost.lua")
    local n, cby = Cost.Count(function() for _ = 1, 60 do C.Tick(0.016) end end)
    H.eq(n, 0, "a second of three cards asks the client nothing (it only moves its own bars)", Cost.Top(cby, 4))
    H.say(("   cost: 60 frames of %d cards = %d calls (%s)"):format(C.MAX, n, Cost.Top(cby, 4)))
    while #C.up > 0 do C.Hide(C.up[1]) end

    H.section("the cards: working bars")
    R.whoBusy = false
    R:LookupPlayer("Nebeon")
    H.ok(#C.up == 1 and C.up[1].working and C.up[1].title._text == "LOOKING UP NEBEON", "a /who lookup shows its working bar")
    C.Tick(3)
    H.ok(C.up[1] and C.up[1].bar._w and C.up[1].bar._w > 1, "the bar fills while it looks")
    R:FinishLookup()
    H.eq(#C.up, 0, "done: the bar goes")
    local wasLock = C_ChatInfo.InChatMessagingLockdown
    C_ChatInfo.InChatMessagingLockdown = function() return true end
    M.queue = {}
    M:SendWhisper("Waiter", "hi")
    M:SendWhisper("Waiter2", "hi")
    H.ok(#C.up == 1 and C.up[1].title._text == "2 WHISPERS WAITING", "held whispers: one card that counts them", C.up[1] and C.up[1].title._text)
    C_ChatInfo.InChatMessagingLockdown = wasLock
    M:Flush()
    H.eq(#C.up, 0, "sent: the card goes")
    H.timers = {}

    H.section("what works: posts, whispers, the reminder")
    NS.db.stats = { posts = {} }
    M.lastSend, M.lastAny = {}, nil
    M:Send("CHANNEL", "Trade")
    local p = NS.db.stats.posts[1]
    H.ok(p and p.where == "Trade" and p.tpl == M:ActiveTemplate().name, "a post is kept: where and which template", p and p.where)
    St.Whispered("Newbie", p.at + 60)
    H.eq(p.whispers, 1, "a whisper a minute later is that post's")
    St.Whispered("Late", p.at + St.WINDOW + 60)
    H.eq(p.whispers, 1, "one after the window is nobody's")
    table.insert(NS.db.stats.posts, { at = p.at - 3600, where = "General", tpl = "Short", whispers = 0 })
    local lines = St.Lines("where")
    H.ok(lines[1] == "Trade  1 / 1" and lines[2] == "General  0 / 1", "best channel first: whispers / posts", lines[1])
    NS.db.remind = 15
    H.ok(#H.timers >= 1 and H.timers[#H.timers].delay == 15 * 60, "the reminder waits 15 min")
    local remind = H.timers[#H.timers].fn
    H.resting = false
    remind()
    H.eq(#C.up, 0, "out of town: no reminder")
    H.resting = true
    remind()
    H.ok(#C.up == 1 and C.up[1].key == "remind" and C.up[1].line._text:find("Trade", 1, true), "in town: TIME TO POST AGAIN, for Trade")
    M.lastSend, M.lastAny = {}, nil
    before = #H.sent
    C.up[1].buttons[1]:Click()
    H.ok(#H.sent == before + 1 and H.sent[#H.sent].chatType == "CHANNEL" and H.sent[#H.sent].target == 2, "its Post button posts to Trade again")
    while #C.up > 0 do C.Hide(C.up[1]) end
    St.Remind("CHANNEL", 2)
    local first = H.timers[#H.timers].fn
    St.Remind("CHANNEL", 2)
    first()
    H.eq(#C.up, 0, "posted again since: the first reminder stays quiet (the same second too)")
    H.timers[#H.timers].fn()
    H.eq(#C.up, 1, "the newest one comes")
    while #C.up > 0 do C.Hide(C.up[1]) end
    H.timers = {}

    H.section("{nextraid}: the raid pasted into BiS Guild")
    H.eq(M:NextRaid(), "", "no BiS Guild: empty (and the ad tidies round it)")
    local start = os.time() + 2 * 86400
    _G.BiSGuildAPI = { RaidNight = function() return { title = "Kara", start = start, time = "20:00", date = "23-10-2026" } end }
    H.eq(M:NextRaid(), os.date("%a", start) .. " 20:00", "two days off: the day and the time")
    H.eq(M:Render("Next raid {nextraid}!"), "Next raid " .. os.date("%a", start) .. " 20:00!", "and the token renders it")
    start = os.time() - 86400
    H.eq(M:NextRaid(), "", "yesterday's raid is not an invitation")
    _G.BiSGuildAPI = { RaidNight = function() return nil, "no raid pasted" end }
    H.eq(M:NextRaid(), "", "nothing pasted: empty")
    _G.BiSGuildAPI = { RaidNight = function() error("boom") end }
    H.eq(M:NextRaid(), "", "a broken BiS Guild never breaks the ad")
    _G.BiSGuildAPI = nil

    NS.db.previewMode = wasPreview
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 4 } }
    R.rosterDirty = true
end)()

-- FENCED INTO THE GUILD (Arn, 21 Oct 2026): the save is the account's; an alt in another guild must never
-- see, use or share the main's guild's book.
;(function()
    local F, T, R, Sc = NS.Fence, NS.Team, NS.Responders, NS.Scout
    local now = os.time()
    local MAIN, ALT = "The Heathens-Dreamscythe", "Alt Guild-Dreamscythe"

    H.section("the fence: the book is the guild's")
    H.eq(NS.db.guildKey, MAIN, "after login the live book is the guild this character is in")
    H.ok(F.Ready(), "and the fence is open")
    NS.db.needs.shaman.resto = 2
    NS.db.discord = "discord.gg/heathens"
    NS.db.responders = { Mainrecruit = { name = "Mainrecruit", status = "contacted", timestamp = now, messages = {} } }
    NS.db.team = { Mainprospect = { name = "Mainprospect", status = "contacted", by = "Kumlust", at = now } }
    local templates = NS.db.templates

    H.section("the fence: an alt in another guild")
    H.myGuild = "Alt Guild"
    F.frame:Fire("OnEvent", "PLAYER_GUILD_UPDATE")
    H.eq(NS.db.guildKey, ALT, "the alt's guild is live now")
    H.ok(NS.db.needs.shaman.resto == 0 and NS.db.discord == "", "with its own needs and Discord - fresh, not the main's")
    H.ok(next(NS.db.responders) == nil and next(NS.db.team) == nil, "an empty desk and an empty guild list")
    H.eq((T.Prospect("Mainprospect")), false, "the main's prospect is nobody here")
    H.ok(not NS.Message:Build():find("heathens", 1, true), "the ad carries no Heathens Discord", NS.Message:Build())
    H.eq(NS.db.templates, templates, "the templates are the account's: the same ones")
    H.eq(NS.db.guilds[MAIN].discord, "discord.gg/heathens", "the main's book is parked, whole")
    H.ok(NS.db.guilds[MAIN].responders.Mainrecruit, "desk and all")
    -- an alt-guild officer asks for everyone's desk: the main's recruits are not in the answer
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 4 }, { name = "Altofficer-Dreamscythe", rank = 0 } }
    R.rosterDirty = true
    _G.LibBiSComm.outbox = {}
    H.wire = {}
    T.OnAsk("Altofficer", "R")
    local leaked = false
    for _, w in ipairs(_G.LibBiSComm.outbox) do if w.msg:find("Mainrecruit", 1, true) then leaked = true end end
    for _, w in ipairs(H.wire) do if w.msg:find("Mainrecruit", 1, true) then leaked = true end end
    H.ok(not leaked, "an alt-guild officer's ASK gets nothing of the main's desk")
    H.inParty = true
    H.raid = { { name = "Kumlust" }, { name = "Shammy", class = "SHAMAN" } }
    NS.db.scoutSeen = {}
    H.eq(Sc.Check(), 0, "the scout uses the alt guild's needs (none): no card for the main's resto shaman")
    H.inParty, H.raid = false, { { name = "Kumlust" } }
    NS.db.discord = "discord.gg/altguild"

    H.section("the fence: back on the main")
    H.myGuild = "The Heathens"
    F.frame:Fire("OnEvent", "PLAYER_GUILD_UPDATE")
    H.ok(NS.db.guildKey == MAIN and NS.db.discord == "discord.gg/heathens" and NS.db.needs.shaman.resto == 2,
         "the main's book comes back as it was")
    H.ok(NS.db.responders.Mainrecruit and NS.db.team.Mainprospect, "desk and guild list too")
    H.eq(NS.db.guilds[ALT].discord, "discord.gg/altguild", "and the alt's is parked")
    H.eq(NS.db.guilds[MAIN], nil, "a live book is never also parked")

    H.section("the fence: shut until the game says which guild")
    F.ready = false
    H.guildLate = true
    H.ok(not F.Settle(), "in a guild, but GetGuildInfo answers nil yet: not settled")
    H.eq(T.Changed({ name = "Early", status = "new" }), false, "nothing is shared")
    H.eq(T.Took("Grunt", "Early", "new", "", "", "Grunt", tostring(now), ""), nil, "nothing is taken")
    H.ok(not T.Adopt("Officerton", now + 99, "warrior.prot=3"), "no needs are adopted")
    H.eq(Sc.Check(), 0, "no scout cards")
    H.guildLate = nil
    F.frame:Fire("OnEvent", "GUILD_ROSTER_UPDATE")
    H.ok(F.Ready() and NS.db.guildKey == MAIN, "the roster comes: the fence opens on the right book")
    local swaps = F.swapped
    H.myGuild = "Elsewhere"
    F.frame:Fire("OnEvent", "GUILD_ROSTER_UPDATE")
    H.eq(F.swapped, swaps, "once settled, the roster's chatter is not looked at (only PLAYER_GUILD_UPDATE)")
    H.myGuild = nil
    F.frame:Fire("OnEvent", "PLAYER_GUILD_UPDATE")
    H.eq(NS.db.guildKey, "-", "left the guild: a book of its own, not the old guild's")
    H.myGuild, H.myGuildRealm = "The Heathens", "Otherrealm"
    F.frame:Fire("OnEvent", "PLAYER_GUILD_UPDATE")
    H.eq(NS.db.guildKey, "The Heathens-Otherrealm", "the same name on another realm is another guild")
    H.myGuildRealm = nil
    F.frame:Fire("OnEvent", "PLAYER_GUILD_UPDATE")
    H.eq(NS.db.guildKey, MAIN, "and home again")
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 4 } }
    R.rosterDirty = true
    NS.db.needs.shaman.resto = 0
end)()

;(function()
    local UI, T = NS.UI, NS.Team
    local now = os.time()
    H.section("the Team page")
    NS.db.team = { Newest = { name = "Newest", status = "contacted", by = "Grunt", at = now - 60, note = "secret note" },
                   Older = { name = "Older", status = "trial", by = "Kumlust", at = now - 7200 } }
    UI:Open("Team")
    H.ok(UI.teamRows[1].name._text:find("Newest", 1, true) and UI.teamRows[2].name._text:find("Older", 1, true), "newest first")
    H.ok(UI.teamRows[1].by._text:find("by Grunt", 1, true), "who is talking to them", UI.teamRows[1].by._text)
    H.ok(not UI.teamRows[1].by._text:find("secret", 1, true), "a member's page shows no note")
    H.eq(UI.teamSend.enabled, false, "and a member's Send to the guild is greyed")
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 1 } }
    NS.Responders.rosterDirty = true
    UI:Refresh()
    H.ok(UI.teamRows[1].by._text:find("secret note", 1, true), "an officer's shows it")
    H.eq(UI.teamSend.enabled, true, "and an officer can send")
    H.fitsIn(UI.frame, "the Team page, full")
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 4 } }
    NS.Responders.rosterDirty = true
    NS.db.team = {}

    -- ARN'S GREYED BUTTON (21 Oct 2026): on Forever UnitName is "Arn", the roster says "Arn Surname" - the GM
    -- was nobody, so Send to the guild never lit. Whole names everywhere now.
    H.section("whole names: an officer with a surname")
    H.raid = { { name = "Kumlust Wildhammer" } }
    H.guild = { { name = "Kumlust Wildhammer-Dreamscythe", rank = 0 } }
    NS.Responders.rosterDirty = true
    H.eq(UnitName("player"), "Kumlust", "(the stand-in, as Forever: UnitName is the first name)")
    H.eq(T.Me(), "Kumlust Wildhammer", "I am my whole name")
    H.ok(T.IsOfficer(), "and the guild master with a surname is an officer")
    UI:Open("Team")
    H.eq(UI.teamSend.enabled, true, "Send to the guild lights")
    H.eq(T.Rank("Kumlust"), 0, "a first name alone finds the one roster name it begins")
    H.guild[2] = { name = "Kumlust Otherone-Dreamscythe", rank = 4 }
    NS.Responders.rosterDirty = true
    H.eq(T.Rank("Kumlust"), nil, "two of them: not guessed")
    -- the scout looks people up by their whole name too
    NS.db.needs.shaman.resto, NS.db.scout, NS.db.scoutSeen = 2, true, {}
    H.inParty = true
    H.raid = { { name = "Kumlust Wildhammer" }, { name = "Chain Healz", class = "SHAMAN" } }
    local look = NS.Scout.Look("party1")
    H.eq(look and look.name, "Chain Healz", "the scout's card names them whole (to whisper and invite them)")
    H.inParty, H.raid = false, { { name = "Kumlust" } }
    NS.db.needs.shaman.resto = 0
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 4 } }
    NS.Responders.rosterDirty = true
    NS.Responders.me = nil

    H.section("the Stats page")
    NS.db.stats = { posts = { { at = now, where = "GuildRecruitment", tpl = "Standard", whispers = 3 },
                              { at = now - 600, where = "LookingForGroup", tpl = "Roles only", whispers = 0 } } }
    UI:ShowTab("Stats")
    H.ok(UI.statsTotal._text:find("2 posts brought 3 whispers", 1, true), "the total", UI.statsTotal._text)
    H.eq(UI.statsCols[1].lines[1]._text, "GuildRecruitment  3 / 1", "the best channel on top")
    H.fitsIn(UI.frame, "the Stats page, the longest channel names")
    UI:Set("remind", 30)
    H.eq(NS.db.remind, 30, "the reminder's setting round-trips")
    NS.db.remind = 15
    NS.db.stats = { posts = {} }
    UI:ShowTab("Desk")
    UI:Hide()

    H.section("the minimap button: the family's shared one")
    local MB = NS.Minimap
    local b = MB.button
    H.ok(b and b:GetName() == "BiSMinimapNebbinator", "built on Libs/BiSTheme/Minimap.lua", b and b:GetName())
    H.eq(b.icon._texture or b.icon._tex, MB.ICON, "wearing the star")
    b:Click("LeftButton")
    H.ok(UI.frame:IsShown(), "left click opens the window")
    b:Click("LeftButton")
    H.ok(not UI.frame:IsShown(), "and closes it")
    b:Click("RightButton")
    H.ok(b.menuFrame and b.menuFrame:IsShown(), "right click opens the menu")
    b:CloseMenu()
    local rows, scout = MB.Menu(), nil
    for _, r in ipairs(rows) do if r.text == "party scout" then scout = r end end
    H.ok(scout and scout.checked == true, "the menu's party scout says it is on")
    scout.func()
    H.eq(NS.db.scout, false, "and turns it off - the same function as /bisn scout")
    SlashCmdList["NEBBINATOR"]("scout")
    H.eq(NS.db.scout, true, "/bisn scout turns it back on")
    NS.db.responders = { Waiting = { name = "Waiting", status = "new", timestamp = now, messages = {} } }
    MB:Update()
    H.ok(b.opts.tooltip[1]:find("1 new responder", 1, true), "the tooltip counts who waits", b.opts.tooltip[1])
    NS.db.responders = {}
    MB:Update()
    H.eq(b.opts.tooltip[1], "nobody new waiting", "and says when nobody does")

    H.section("NebbinatorAPI version 2: the guild's")
    local A = _G.NebbinatorAPI
    NS.db.team = { Pros = { name = "Pros", status = "contacted", by = "Grunt", at = now - 50 },
                   Joined = { name = "Joined", status = "accepted", by = "Grunt", at = now - 10 } }
    local team = A.Team()
    H.ok(#team == 2 and team[1].name == "Joined", "(api) Team: the list, newest first")
    team[1].status = "edited"
    H.eq(NS.db.team.Joined.status, "accepted", "(api) ...a copy")
    local yes, by, status, at = A.IsProspect("Pros-Dreamscythe")
    H.ok(yes == true and by == "Grunt" and status == "contacted" and at == now - 50, "(api) IsProspect: who, how far, when")
    H.eq(A.IsProspect("Joined"), false, "(api) a guildmate now is not a prospect")
    local _, why = A.IsProspect(nil)
    H.eq(why, "no name", "(api) IsProspect without a name says so")
    NS.db.needs.shaman.resto, NS.db.needsBy, NS.db.needsAt = 2, "Officerton", now
    local needs = A.Needs()
    H.ok(needs.text == "2 Resto Shaman" and needs.by == "Officerton" and needs.list[1].classFile == "SHAMAN"
         and needs.list[1].role == "HEALER" and needs.list[1].count == 2, "(api) Needs: the line, who set it, the list", needs.text)
    NS.db.needs.shaman.resto, NS.db.needsBy, NS.db.needsAt = 0, nil, nil
    H.eq(A.IsOfficer(), false, "(api) IsOfficer: a member is not")
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 0 } }
    NS.Responders.rosterDirty = true
    H.eq(A.IsOfficer(), true, "(api) the guild master is")
    H.guild = { { name = "Kumlust-Dreamscythe", rank = 4 } }
    NS.Responders.rosterDirty = true
    NS.db.stats = { posts = { { at = now, where = "Trade", tpl = "Short", whispers = 2 } } }
    local st = A.Stats()
    H.ok(st.posts == 1 and st.whispers == 2 and st.where[1].key == "Trade" and st.ad[1].key == "Short", "(api) Stats: what works")
    NS.db.stats = { posts = {} }
    local heardTeam
    A.RegisterCallback("suite", "Nebbinator_TeamChanged", function(_, name) heardTeam = name end)
    NS.Team.Took("Grunt", "Newbie", "new", "", "", "Grunt", tostring(now), "")
    H.eq(heardTeam, "Newbie", "(api) TeamChanged fires with the name")
    A.UnregisterCallback("suite", "Nebbinator_TeamChanged")
    H.ok(A.Open("Team") and UI:ShownTab() == "Team", "(api) Open(\"Team\")")
    UI:Hide()
    NS.db.team = {}
end)()

H.report()
