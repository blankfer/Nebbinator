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

--- The addon's own section, then the ones that group its settings. Labels are
--- plain words a raider understands and stay under ~24 characters: the kit's
--- budget is W - 12 - 110 and BiSTheme.Fit is the net, not the plan.
function UI:OptionSections()
    return {
        { title = "nebbinator", options = {
            { kind = "toggle", label = "minimap button",
              help = "The gold star on the minimap: left click the window, right click a menu.",
              get = function() return not NS.db.minimap.hide end,
              set = function() NS.ToggleMinimap() end },
            { kind = "toggle", label = "BiS channel (/biscomm)",
              help = "The shared channel every BiS addon talks on. Off here is off for all of them.",
              get = function() local l = _G.LibBiSComm return l and l:Enabled() end,
              set = function(_, on) local l = _G.LibBiSComm if l then l:SetEnabled(on and true or false) end end },
            { kind = "button", label = "reset window position", button = "reset",
              help = "Puts the window back in the middle of the screen.",
              action = function() NS.ResetWindow() end },
        } },

        { title = "posting", options = {
            { kind = "toggle", label = "preview - never sends",
              help = "Try everything without posting or whispering anybody. /bisn preview",
              get = function() return NS.db.previewMode and true or false end,
              set = function() NS.TogglePreview() end },
            { kind = "step", label = "cooldown per channel", min = 5, max = 120, step = 5,
              help = "How long a channel's button waits after a post, so nobody spams Trade by accident.",
              get = function() return NS.db.sendCooldown or 10 end,
              set = function(_, v) NS.SetCooldown(v) end,
              show = function() return (NS.db.sendCooldown or 10) .. " s" end },
            { kind = "step", label = "remind me to post", min = 0, max = 30, step = 5,
              help = "In a city, a card offers the same ad again this long after your last post.",
              get = function() return tonumber(NS.db.remind) or 0 end,
              set = function(_, v) NS.SetRemind(v) end,
              show = function() local m = tonumber(NS.db.remind) or 0 return m == 0 and "never" or (m .. " min") end },
        } },

        { title = "answering", options = {
            { kind = "toggle", label = "auto-reply",
              help = "Answers a whisper with your reply text (Replies tab) - once per player, at most 6 a minute.",
              get = function() return NS.db.autoReply.enabled and true or false end,
              set = function() NS.ToggleAutoReply() end },
            { kind = "toggle", label = "say the class we need",
              help = "When they name a class the guild needs, the reply says so: \"We need 2 Resto Shaman right now.\"",
              get = function() return NS.db.autoReply.classAware ~= false end,
              set = function() NS.ToggleClassAware() end },
            { kind = "toggle", label = "launch day: answer all",
              help = "Swamped? Everyone who whispers gets the busy reply, keywords or not.",
              get = function() return NS.db.autoReply.busy and true or false end,
              set = function() NS.ToggleBusy() end },
            { kind = "toggle", label = "alert sound",
              help = "A sound when somebody whispers you about the guild.",
              get = function() return NS.db.autoReply.playSound and true or false end,
              set = function() NS.ToggleSound() end },
            { kind = "toggle", label = "only the first one",
              help = "The sound for a new person only, not every whisper after.",
              get = function() return NS.db.autoReply.soundOnlyNew and true or false end,
              set = function() NS.ToggleSoundOnlyNew() end },
            -- a stepper, not a grid: it plays each one as you land on it, so you
            -- can walk the whole list without leaving the row
            { kind = "step", label = "which sound", min = 1, max = #NS.SOUNDS, step = 1,
              help = "Each one plays as you step onto it.",
              get = function() return NS.Util.SoundIndex(NS.db.autoReply.sound or "bell") end,
              set = function(_, v) NS.SetSoundIndex(v) end,
              show = function()
                  local s = NS.Util.SoundByKey(NS.db.autoReply.sound or "bell")
                  return s.short or s.name
              end },
        } },

        { title = "finding people", options = {
            { kind = "toggle", label = "watch for \"LF guild\"",
              help = "Somebody in a channel asking for a guild lands on your desk.",
              get = function() return NS.db.leadFinder and true or false end,
              set = function() NS.ToggleLeadFinder() end },
            { kind = "toggle", label = "party scout",
              help = "Grouped with a class the guild needs who is not in it? A card says ask them. /bisn scout",
              get = function() return NS.db.scout and true or false end,
              set = function() NS.ToggleScout() end },
        } },

        { title = "the guild", options = {
            { kind = "step", label = "officers: ranks 0 to", min = 0, max = 9, step = 1,
              help = "Who may send the guild's needs: rank 0 is the guild master. The same number as BiS Guild.",
              get = function() return tonumber(NS.db.officerRank) or 1 end,
              set = function(_, v) NS.SetOfficerRank(v) end,
              show = function() return tostring(tonumber(NS.db.officerRank) or 1) end },
        } },
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

--- Called from UI:Refresh so the window agrees with a slash command that ran
--- while it was open.
function UI:RefreshOptions()
    if self.opt and self.opt:IsShown() then self.opt:Paint() end
end
