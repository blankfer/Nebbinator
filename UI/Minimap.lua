-- Nebbinator :: UI/Minimap.lua
-- The minimap button, on the family's shared one (Libs\BiSTheme\Minimap.lua, since 21 Oct 2026 - it was
-- hand-built here, 112 lines of its own drag maths and ring): Blizzard's ring, the measured radius, the
-- dragging, the menu. Left click opens the window; right click the menu - the pages, and the switches
-- that matter mid-evening. The star is full bright while somebody new waits, quiet otherwise.

local ADDON, NS = ...

NS.Minimap = {}
local MB = NS.Minimap

MB.ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"      -- the star: core UI art, in every client

function MB.Menu()
    local db = NS.db
    local new = NS.Responders:CountNew()
    return {
        { title = "Nebbinator" },
        { text = "the desk", note = new > 0 and (new .. " new") or nil, func = function() NS.UI:Open("Desk") end },
        { text = "the guild's list", func = function() NS.UI:Open("Team") end },
        { text = "what works", func = function() NS.UI:Open("Stats") end },
        { text = "options", func = function() NS.UI:ToggleOptions() end },
        { sep = true },
        { text = "auto-reply", checked = db.autoReply.enabled, func = function() NS.ToggleAutoReply() end },
        { text = "party scout", checked = db.scout, func = function() NS.ToggleScout() end },
        { text = "preview (nothing sends)", checked = db.previewMode, func = function() NS.TogglePreview() end },
    }
end

function MB:Initialize()
    if self.button or not (BiSTheme and BiSTheme.Minimap) then return end
    local b = BiSTheme.Minimap("Nebbinator", {
        icon = self.ICON, label = "Nebbinator", db = NS.db.minimap, menu = self.Menu,
        tooltip = {},
    })
    if not b then return end
    self.button = b
    b:SetScript("OnClick", function(s, click)
        s:Unbury()
        if click == "RightButton" then s:ToggleMenu() return end
        s:CloseMenu()
        NS.UI:Toggle()
    end)
    -- the lib's tooltip says "left-click the menu"; here the left click is the window
    b:SetScript("OnEnter", function(s)
        if not GameTooltip then return end
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine("BiS> Nebbinator", NS.T.rgb("accent"))
        for _, line in ipairs(s.opts.tooltip or {}) do GameTooltip:AddLine(line, NS.T.rgb("muted")) end
        GameTooltip:AddLine("right-click  the menu", NS.T.rgb("muted"))
        GameTooltip:AddLine("drag  move me round the edge", NS.T.rgb("muted"))
        GameTooltip:Show()
    end)
    self:Update()
end

function MB:Update()
    local b = self.button
    if not b then return end
    local new = NS.Responders:CountNew()
    b.opts.tooltip = {
        new > 0 and (new .. " new responder" .. (new > 1 and "s" or "") .. " waiting") or "nobody new waiting",
        "left-click  the window",
    }
    if new > 0 then b.icon:SetVertexColor(1, 1, 1) else b.icon:SetVertexColor(0.78, 0.74, 0.88) end
    b:Refresh()
end
