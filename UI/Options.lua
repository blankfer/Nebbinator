-- Nebbinator :: UI/Options.lua
--
-- The options window, built on BiSTheme's shared kit. Arn, 10 Sep 2026, looking
-- at BiSTools' Hub: "this is beautiful ... I want all option windows to look
-- like this." Nebbinator is the second addon to wear it, which is why the
-- generic half lives in Libs\BiSTheme\Options.lua and this file is only a list.
--
-- The Settings TAB is gone. One place for settings across every BiS addon beats
-- a different place per addon, and a tab inside a working desk was the odd one
-- out. What did not fit the four control kinds went where it belongs instead:
--
--   logs address     -> the box on the desk, where you actually use it
--   extra channels   -> /bisn channels <a, b> (a free-text field is not a control)
--   alert sound      -> a stepper that walks NS.SOUNDS and plays what it lands on
--
-- EVERY `set` HERE CALLS THE FUNCTION THE SLASH COMMAND ALREADY OWNS. None of
-- them writes a saved variable itself. Two paths that write the same key
-- separately drift; two paths through one function cannot.

local ADDON, NS = ...
local UI = NS.UI

--- EVERY SETTING ONCE, by name (8 Nov 2026, the BiS> dashboard). The options window's sections and the BiS> page's
--- dashboard both hand out THESE tables, so the two can never disagree about what a row does. Labels are plain
--- words a raider understands and stay under ~24 characters: the window's budget is W - 12 - 110 and
--- BiSTheme.Fit is the net, not the plan.
function UI:OptionTables()
    if self.optTables then return self.optTables end
    local o = {}
    self.optTables = o
    o.minimap = { kind = "toggle", label = "minimap button",
              help = "The gold star on the minimap: left click the window, right click these options.",
              get = function() return not NS.db.minimap.hide end,
              set = function() NS.ToggleMinimap() end }
    o.channel = { kind = "toggle", label = "BiS channel (/biscomm)",
              help = "The shared channel every BiS addon talks on. Off here is off for all of them.",
              get = function() local l = _G.LibBiSComm return l and l:Enabled() end,
              set = function(_, on) local l = _G.LibBiSComm if l then l:SetEnabled(on and true or false) end end }
    o.resetWindow = { kind = "button", label = "reset window position", button = "reset",
              help = "Puts the window back in the middle of the screen.",
              action = function() NS.ResetWindow() end }
    o.preview = { kind = "toggle", label = "preview - never sends",
              help = "Try everything without posting or whispering anybody. /bisn preview",
              get = function() return NS.db.previewMode and true or false end,
              set = function() NS.TogglePreview() end }
    o.cooldown = { kind = "step", label = "cooldown per channel", min = 5, max = 120, step = 5,
              help = "How long a channel's button waits after a post, so nobody spams Trade by accident.",
              get = function() return NS.db.sendCooldown or 10 end,
              set = function(_, v) NS.SetCooldown(v) end,
              show = function() return (NS.db.sendCooldown or 10) .. " s" end }
    o.remind = { kind = "step", label = "remind me to post", min = 0, max = 30, step = 5,
              help = "In a city, a card offers the same ad again this long after your last post.",
              get = function() return tonumber(NS.db.remind) or 0 end,
              set = function(_, v) NS.SetRemind(v) end,
              show = function() local m = tonumber(NS.db.remind) or 0 return m == 0 and "never" or (m .. " min") end }
    o.autoReply = { kind = "toggle", label = "auto-reply",
              help = "Answers a whisper with your reply text (Replies tab) - once per player, at most 6 a minute.",
              get = function() return NS.db.autoReply.enabled and true or false end,
              set = function() NS.ToggleAutoReply() end }
    o.classAware = { kind = "toggle", label = "say the class we need",
              help = "When they name a class the guild needs, the reply says so: \"We need 2 Resto Shaman right now.\"",
              get = function() return NS.db.autoReply.classAware ~= false end,
              set = function() NS.ToggleClassAware() end }
    o.busy = { kind = "toggle", label = "launch day: answer all",
              help = "Swamped? Everyone who whispers gets the busy reply, keywords or not.",
              get = function() return NS.db.autoReply.busy and true or false end,
              set = function() NS.ToggleBusy() end }
    o.sound = { kind = "toggle", label = "alert sound",
              help = "A sound when somebody whispers you about the guild.",
              get = function() return NS.db.autoReply.playSound and true or false end,
              set = function() NS.ToggleSound() end }
    o.soundOnlyNew = { kind = "toggle", label = "only the first one",
              help = "The sound for a new person only, not every whisper after.",
              get = function() return NS.db.autoReply.soundOnlyNew and true or false end,
              set = function() NS.ToggleSoundOnlyNew() end }
    -- a stepper, not a grid: it plays each one as you land on it, so you
    -- can walk the whole list without leaving the row
    o.whichSound = { kind = "step", label = "which sound", min = 1, max = #NS.SOUNDS, step = 1,
              help = "Each one plays as you step onto it.",
              get = function() return NS.Util.SoundIndex(NS.db.autoReply.sound or "bell") end,
              set = function(_, v) NS.SetSoundIndex(v) end,
              show = function()
                  local s = NS.Util.SoundByKey(NS.db.autoReply.sound or "bell")
                  return s.short or s.name
              end }
    o.leadFinder = { kind = "toggle", label = "watch for \"LF guild\"",
              help = "Somebody in a channel asking for a guild lands on your desk.",
              get = function() return NS.db.leadFinder and true or false end,
              set = function() NS.ToggleLeadFinder() end }
    o.scout = { kind = "toggle", label = "party scout",
              help = "Grouped with a class the guild needs who is not in it? A card says ask them. /bisn scout",
              get = function() return NS.db.scout and true or false end,
              set = function() NS.ToggleScout() end }
    o.officerRank = { kind = "step", label = "officers: ranks 0 to", min = 0, max = 9, step = 1,
              help = "Who may send the guild's needs: rank 0 is the guild master. The same number as BiS Guild.",
              get = function() return tonumber(NS.db.officerRank) or 1 end,
              set = function(_, v) NS.SetOfficerRank(v) end,
              show = function() return tostring(tonumber(NS.db.officerRank) or 1) end }
    return o
end

--- The options window's sections: the addon's own, then the ones that group its settings.
function UI:OptionSections()
    local o = self:OptionTables()
    return {
        { title = "nebbinator",     options = { o.minimap, o.channel, o.resetWindow } },
        { title = "posting",        options = { o.preview, o.cooldown, o.remind } },
        { title = "answering",      options = { o.autoReply, o.classAware, o.busy, o.sound, o.soundOnlyNew, o.whichSound } },
        { title = "finding people", options = { o.leadFinder, o.scout } },
        { title = "the guild",      options = { o.officerRank } },
    }
end

function UI:BuildOptions()
    if self.opt then return self.opt end
    local f = BiSTheme.Options("NebbinatorOptions", BiSTheme.OPTIONS.W, "Options")
    self.opt = f
    f:Recenter(60)
    -- the desk shows preview and auto-reply in its own prompt slots
    f.onChange = function() UI:Refresh() end
    for _, section in ipairs(self:OptionSections()) do
        f:Section(section.title)
        for _, opt in ipairs(section.options) do f:Row(opt, NS.db) end
    end
    f:Fit()
    return f
end

function UI:ToggleOptions(want)
    self:BuildOptions():Toggle(want)
    if self.optBtn then self.optBtn:SetMarked(self.opt:IsShown()) end
end

--- What is on, in a few words - the BiS> front page shows it beside the version.
function UI:SettingsStatus()
    local db = NS.db
    if not db then return "" end
    local new = NS.Responders:CountNew()
    local function onoff(v) return v and "on" or "off" end
    return ("%s - bell %s - scout %s - auto-reply %s"):format(
        new > 0 and (new .. " new waiting") or "nobody new waiting",
        onoff(db.autoReply.playSound), onoff(db.scout), onoff(db.autoReply.enabled))
end

--- A section's ON/OFF through the function its slash command already calls. Those functions FLIP, the dashboard
--- asks for a state: flip only when it is not what was asked for.
local function switch(get, flip)
    return {
        get = get,
        set = function(on) if (get() and true or false) ~= (on and true or false) then flip() end end,
    }
end

--- THE BiS> PAGE'S DASHBOARD (Libs\BiSTheme\Settings.lua minor 3, the family rule - Arn, 8 Nov 2026: "it looks way
--- way better do it for the other ones"). The sections down the left, each holding the SAME option tables as the
--- options window (UI:OptionTables), so a flip here is a flip there.
function UI:DashboardModel()
    local o = self:OptionTables()
    local function tab(name) return function() UI:Open(name) end end
    return {
        list = "SECTIONS",
        onChange = function()
            -- the desk's prompt slots and the options window, if either is open
            UI:Refresh()
            if not UI.frame then UI:RefreshOptions() end
        end,
        entries = {
            { key = "desk", title = "the desk", db = NS.db,
              desc = "Every whisper from somebody outside the guild lands here as a row: who they are, what they "
                  .. "said, and a reply in one click.",
              options = { o.minimap, o.resetWindow },
              open = { label = "open the desk", func = tab("Desk") },
              usage = "/bisn desk  (/bisn alone opens and closes the window)" },
            { key = "posting", title = "posting", db = NS.db,
              desc = "Your guild ad and the buttons that post it. Preview tries it all without sending a word.",
              options = { o.preview, o.cooldown, o.remind },
              open = { label = "open the ad", func = tab("Recruit") },
              usage = "/bisn preview  (test)" },
            { key = "autoReply", title = "auto-reply", db = NS.db,
              desc = "Answers a whisper about the guild with your reply text, once per player, at most 6 a minute.",
              switch = switch(o.autoReply.get, function() NS.ToggleAutoReply() end),
              options = { o.classAware, o.busy },
              open = { label = "open the replies", func = tab("Replies") },
              usage = "/bisn reply  (rep)" },
            { key = "bell", title = "the bell", db = NS.db,
              desc = "A sound when somebody whispers you about the guild, so you can look away from the screen.",
              switch = switch(o.sound.get, function() NS.ToggleSound() end),
              options = { o.soundOnlyNew, o.whichSound } },
            { key = "scout", title = "party scout", db = NS.db,
              desc = "Grouped with a class the guild needs who is not in a guild? A card says ask them. Once a "
                  .. "week each.",
              switch = switch(o.scout.get, function() NS.ToggleScout() end),
              usage = "/bisn scout  (sct)" },
            { key = "leads", title = "lead finder", db = NS.db,
              desc = "Somebody in a channel asking for a guild (\"LF guild\") lands on your desk.",
              switch = switch(o.leadFinder.get, function() NS.ToggleLeadFinder() end) },
            { key = "guild", title = "the guild", db = NS.db,
              desc = "The guild's list and what it needs, shared by everyone in it with Nebbinator. Officers send "
                  .. "the needs.",
              options = { o.officerRank },
              open = { label = "open the guild's list", func = tab("Team") } },
            { key = "channel", title = "the channel", db = NS.db,
              desc = "The hidden channel every BiS addon talks on: the guild's list and needs travel on it. Off is "
                  .. "off for all of them.",
              switch = switch(o.channel.get, function()
                  local l = _G.LibBiSComm
                  if l then l:SetEnabled(not l:Enabled()) end
              end),
              usage = "/biscomm on  /  /biscomm off" },
        },
    }
end

--- FOREVER 1.0 (Arn, 7 Nov 2026: "they'll just see BiS> ... click into that add-on"): Nebbinator's page under the
--- one BiS> entry in the game's options. Since 8 Nov it is the kit's dashboard (UI:DashboardModel), drawn once and
--- painted on every show; the options window is never taken in. Asked once at login; without the game's panel
--- the shared kit answers nil. The minimap's right click opens the options window itself either way (a toggle).
function UI:RegisterSettingsPage()
    if not (BiSTheme and BiSTheme.SettingsPage and BiSTheme.Dashboard) then return nil end
    return BiSTheme.SettingsPage("Nebbinator", {
        title  = "Nebbinator",
        about  = "Guild recruitment: every whisper from somebody outside the guild lands on the desk, with the ad "
            .. "and the send bar beside it. The bell, the auto-reply, the party scout and the reminder wait for you here.",
        status = function() return UI:SettingsStatus() end,
        build  = function(body) UI.dash = BiSTheme.Dashboard(body, UI:DashboardModel()) end,
        refresh = function() if UI.dash then UI.dash:Paint() end end,
        open   = { label = "the desk", func = function() UI:Open("Desk") end },
        api    = { name = "NebbinatorAPI", about = "the desk, the ad, the guild's list and needs - read-only, plus Open" },
    })
end

--- Called from UI:Refresh so the window agrees with a slash command that ran
--- while it was open.
function UI:RefreshOptions()
    if self.opt and self.opt:IsShown() then self.opt:Paint() end
    -- and the BiS> page, while it is up
    local d = self.dash
    if d and d.body and d.body.IsVisible and d.body:IsVisible() then d:Paint() end
end
