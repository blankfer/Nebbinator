-- Nebbinator :: UI/Minimap.lua
-- The minimap button, on the family's shared one (Libs\BiSTheme\Minimap.lua, since 21 Oct 2026 - it was
-- hand-built here, 112 lines of its own drag maths and ring): Blizzard's ring, the measured radius, the
-- dragging. The star is full bright while somebody new waits, quiet otherwise.
--
-- ONE STANDARD (Forever 1.0, Arn, 7 Nov 2026: "sometimes left click does one thing, sometimes right click does
-- another ... we gotta get everything on the same page"): LEFT = the window, RIGHT = the options - the BiS>
-- Nebbinator page in the game's options when there is one, else the options window itself. The old right-click
-- menu is gone: its pages are the window's tabs, its three switches (auto-reply, party scout, preview) are rows
-- in the options. The lib draws the tooltip: "left-click  the window", "right-click  options", "drag  move".

local ADDON, NS = ...

NS.Minimap = {}
local MB = NS.Minimap

MB.ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"      -- the star: core UI art, in every client

function MB:Initialize()
    if self.button or not (BiSTheme and BiSTheme.Minimap) then return end
    local b = BiSTheme.Minimap("Nebbinator", {
        icon = self.ICON, label = "Nebbinator", db = NS.db.minimap, tooltip = {},
        onLeft = function() NS.UI:Toggle() end, leftLabel = "the window",
        onRight = function() NS.UI:ToggleOptions() end,
    })
    if not b then return end
    self.button = b
    self:Update()
end

function MB:Update()
    local b = self.button
    if not b then return end
    local new = NS.Responders:CountNew()
    b.opts.tooltip = {
        new > 0 and (new .. " new responder" .. (new > 1 and "s" or "") .. " waiting") or "nobody new waiting",
    }
    if new > 0 then b.icon:SetVertexColor(1, 1, 1) else b.icon:SetVertexColor(0.78, 0.74, 0.88) end
    b:Refresh()
end
