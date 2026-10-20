-- Nebbinator :: UI/Pages/Stats.lua
-- WHAT WORKS (21 Oct 2026): every post and the whispers it brought (Core/Stats.lua), three ways - by
-- channel, by template, by time of day - best first. And the reminder's setting.

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

UI.STATS_LINES = 8
UI.STATS_COLS = { { key = "where", title = "where" }, { key = "tpl", title = "which ad" }, { key = "part", title = "when" } }

function UI:BuildStats(page)
    local y = -2
    y = self:Caption(page, y, "what works")
    self.statsTotal = K.fs(page, "", 11, "ink")
    self.statsTotal:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    y = y - 22
    local colW = math.floor((UI.colW(page) - 2 * 16) / 3)
    self.statsCols = {}
    for c, col in ipairs(self.STATS_COLS) do
        local x = 2 + (c - 1) * (colW + 16)
        local head = K.fs(page, string.upper(col.title) .. "  whispers / posts", 10, "dim")
        head:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
        local lines = {}
        for i = 1, self.STATS_LINES do
            local l = K.fs(page, "", 10, i == 1 and "good" or "ink2")
            l:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - 16 - (i - 1) * 15)
            l:SetWidth(colW)
            lines[i] = l
        end
        self.statsCols[c] = { key = col.key, lines = lines, w = colW }
    end
    y = y - 16 - self.STATS_LINES * 15 - 14
    y = self:Note(page, y, "A whisper from somebody new within 15 minutes of a post counts for that post.")

    y = self:Caption(page, y - 8, "the reminder")
    y = self:Seg(page, y, "remind", "Remind me to post again", { { 0, "Never" }, { 10, "10 min" }, { 15, "15 min" }, { 30, "30 min" } },
        function() return tonumber(NS.db.remind) or 0 end,
        function(v) NS.db.remind = v end)
    y = self:Note(page, y, "In a city or an inn only. The card's Post button sends the same ad again - a click, which the game needs for a channel.")
    return page
end

function UI:RefreshStats()
    if not self.statsCols then return end
    local St = NS.Stats
    local sum = St.Summary()
    self.statsTotal:SetText(sum.posts == 0 and NS.T.text("dim", "no posts yet - post the ad and this fills in")
        or ("%d post%s brought %d whisper%s"):format(sum.posts, sum.posts == 1 and "" or "s",
            sum.whispers, sum.whispers == 1 and "" or "s"))
    for _, col in ipairs(self.statsCols) do
        local lines = St.Lines(col.key)
        for i, l in ipairs(col.lines) do l:SetText(lines[i] or "") end
    end
end
