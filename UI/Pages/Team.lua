-- Nebbinator :: UI/Pages/Team.lua
-- THE GUILD'S PAGE (21 Oct 2026): what the guild needs and who set it - an officer's button sends this
-- client's needs to every Nebbinator in the guild (Core/Team.lua) - and the guild's list of prospects.
-- An officer's rows carry class, level and the note; everyone else's only who, how far and who is talking
-- to them (Arn's pick: "summary only", never what a recruit whispered).

local ADDON, NS = ...
local K  = NS.Kit
local UI = NS.UI

UI.TEAM_ROWS = 18

function UI:BuildTeam(page)
    local y = -2
    y = self:Caption(page, y, "what the guild needs")
    self.teamNeeds = K.fs(page, "", 11, "ink")
    self.teamNeeds:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    self.teamNeeds:SetWidth(UI.colW(page) - 4)
    y = y - 16
    self.teamNeedsBy = K.fs(page, "", 10, "dim")
    self.teamNeedsBy:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
    y = y - 20
    local b
    y, b = self:Btn(page, y, "sendNeeds", "Send to the guild",
        "Every Nebbinator in the guild takes these needs (set them on Recruit). Officers only.",
        function()
            local ok, why = NS.Team.SetNeeds()
            if not ok then NS.Say(why, "warn") end
        end, "good", 150)
    self.teamSend = b

    y = self:Caption(page, y - 6, "the guild's list")
    self.teamRows = {}
    for i = 1, self.TEAM_ROWS do
        local r = {}
        r.name = K.fs(page, "", 10, "ink")
        r.name:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
        r.name:SetWidth(150)
        r.status = K.fs(page, "", 10, "ink2")
        r.status:SetPoint("TOPLEFT", page, "TOPLEFT", 156, y)
        r.by = K.fs(page, "", 10, "muted")
        r.by:SetPoint("TOPLEFT", page, "TOPLEFT", 236, y)
        r.by:SetWidth(UI.colW(page) - 240)
        self.teamRows[i] = r
        y = y - 15
    end
    -- the empty list's line: the whole width (the first row's name column is 150 px and wrapped it in three)
    self.teamEmpty = K.fs(page, "", 10, "dim")
    self.teamEmpty:SetPoint("TOPLEFT", self.teamRows[1].name, "TOPLEFT", 0, 0)
    self.teamEmpty:SetWidth(UI.colW(page) - 4)
    self.teamMore = K.fs(page, "", 10, "dim")
    self.teamMore:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y - 2)
    return page
end

function UI:OnTeamChanged()
    if self.RefreshTeam then self:RefreshTeam() end
end

function UI:RefreshTeam()
    if not self.teamRows then return end
    local T = NS.Team
    local needs = NS.Message:NeedsText(false)
    self.teamNeeds:SetText(needs ~= "" and needs or NS.T.text("dim", "nothing - set what you need on Recruit"))
    if NS.db.needsBy then
        self.teamNeedsBy:SetText(("set by %s, %s"):format(NS.db.needsBy, NS.Util.TimeAgo(NS.db.needsAt)))
    else
        self.teamNeedsBy:SetText("set on this client - nobody has sent the guild any yet")
    end
    local officer = T.IsOfficer()
    self.teamSend:SetEnabledFlat(officer and NS.Fence.Ready())
    self.teamSend:SetTip("Send to the guild", officer and "Every Nebbinator in the guild takes these needs."
        or ("Officers only - guild ranks 0 to %d."):format(tonumber(NS.db.officerRank) or 1))

    local list = {}
    for _, row in pairs(T.List()) do list[#list + 1] = row end
    table.sort(list, function(a, b) return (a.at or 0) > (b.at or 0) end)
    for i, r in ipairs(self.teamRows) do
        local row = list[i]
        if row then
            r.name:SetText("|cFF" .. NS.Util.ClassHex(row.class) .. row.name .. "|r"
                .. (row.level and NS.T.text("dim", " " .. row.level) or ""))
            r.status:SetText(row.status or "new")
            local bits = { "by " .. (row.by or "?"), NS.Util.TimeAgo(row.at) }
            if officer and row.note and row.note ~= "" then bits[#bits + 1] = '"' .. row.note .. '"' end
            r.by:SetText(table.concat(bits, "   "))
        else
            r.name:SetText("")
            r.status:SetText("")
            r.by:SetText("")
        end
    end
    self.teamEmpty:SetText(#list == 0 and "nobody yet - every recruit somebody in the guild talks to shows up here" or "")
    self.teamMore:SetText(#list > #self.teamRows and ("and " .. (#list - #self.teamRows) .. " more") or "")
end
