-- Nebbinator - Core/Scout.lua
-- THE PARTY SCOUT (Arn, 21 Oct 2026): "when we are in a party with a class that we need and it's not in the
-- guild it lets us know we need this class you should ask if they want to raid with us" - then "when we are
-- partied with a class we need and they don't have a guild even more prominent, if they are in a guild less
-- prominent", and the crest: somebody the guild is already talking to gets "nudge them to join".
--
-- On every group change (settled for a moment first: a raid forming fires dozens), each groupmate who is
-- not in our guild and plays a class the guild needs gets a card (UI/Cards.lua): BIG with a sound when they
-- have no guild, small and quiet when they have one. Once per person per S.AGAIN days. Their class is plain
-- to an addon; their ROLE only when the game assigned one (the group finder), which narrows the specs.
-- Everyone in the guild gets the cards (Arn's pick); `/bisn scout` turns them off.

local ADDON, NS = ...
local U = NS.Util

local S = {}
NS.Scout = S

S.AGAIN = 7 * 86400        -- a card about the same person at most once a week
S.SETTLE = 2               -- seconds a group must sit still before it is looked at
S.ROLE = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DPS" }

local function plain(v) if U.Hidden(v) then return nil end return v end

--- What we need of this class, narrowed to the role the game gave them (if any): "2 Resto Shaman".
function S.Want(class, role)
    local counts = NS.db.needs[class.key]
    if not counts then return nil end
    local parts = {}
    for _, spec in ipairs(class.specs) do
        local n = tonumber(counts[spec.key]) or 0
        if n > 0 and (not role or spec.role == role) then
            parts[#parts + 1] = (#class.specs == 1) and (n .. " " .. class.name) or (n .. " " .. spec.name .. " " .. class.name)
        end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

local function ClassOf(file)
    for _, c in ipairs(NS.CLASSES) do if c.file == file then return c end end
    return nil
end

--- One groupmate: the card's words, or nil and why not (the suite asks this directly).
function S.Look(unit)
    if not (UnitExists and UnitExists(unit)) or (UnitIsUnit and UnitIsUnit(unit, "player")) then return nil, "nobody" end
    if UnitIsPlayer and not UnitIsPlayer(unit) then return nil, "not a player" end
    local name = plain(UnitName(unit))
    if type(name) ~= "string" or name == "" then return nil, "no name" end
    name = U.StripRealm(name)
    if (UnitIsInMyGuild and plain(UnitIsInMyGuild(unit))) or NS.Responders:IsGuildMember(name) then return nil, "ours already" end
    local seen = NS.db.scoutSeen[name]
    if seen and time() - seen < S.AGAIN then return nil, "asked this week" end
    local file = UnitClass and plain(select(2, UnitClass(unit)))
    local class = file and ClassOf(file)
    if not class then return nil, "no class" end
    local role = UnitGroupRolesAssigned and S.ROLE[plain(UnitGroupRolesAssigned(unit)) or ""]
    local want = S.Want(class, role)
    if not want then return nil, "a class we do not need" end
    local guild = GetGuildInfo and plain(GetGuildInfo(unit))
    local prospect, by = false, nil
    if NS.Team then prospect, by = NS.Team.Prospect(name) end
    return { name = name, class = class, want = want, guild = (type(guild) == "string" and guild ~= "") and guild or nil,
             prospect = prospect, by = by, level = plain(UnitLevel and UnitLevel(unit)) }
end

--- The group, looked at once it has settled. Answers how many cards it raised.
function S.Check()
    S.armed = nil
    if not NS.db.scout then return 0 end
    local raid = IsInRaid and IsInRaid()
    local n = (GetNumGroupMembers and plain(GetNumGroupMembers())) or 0
    local cards = 0
    for i = 1, n do
        local look = S.Look((raid and "raid" or "party") .. i)
        if look then
            NS.db.scoutSeen[look.name] = time()
            cards = cards + 1
            if NS.Cards and NS.Cards.Scout then NS.Cards.Scout(look) end
        end
    end
    return cards
end

--- The whisper the card's button sends: friendly, short, with the Discord.
function S.Ask(look)
    local text = ("Hey %s! We're <{guild}> and we need %s - want to raid with us? {discord}"):format(look.name, look.want)
    NS.Message:SendWhisper(look.name, (NS.Message:Render(text)))
    S.ToDesk(look, "contacted")
    NS.Say(look.name .. " asked", "good")
end

--- Onto the desk, as somebody we met in a group.
function S.ToDesk(look, status)
    local d = NS.db.responders
    local e = d[look.name]
    if not e then
        e = { name = look.name, status = status or "new", class = look.class.file, level = look.level,
              guild = look.guild or "No guild", note = "met in a group", source = "party",
              timestamp = time(), messages = {} }
        d[look.name] = e
    elseif status and e.status == "new" then
        e.status = status
    end
    if NS.Responders.Share then NS.Responders.Share(e) end
    NS.UI:OnDataChanged()
    return e
end

local f = CreateFrame("Frame")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:SetScript("OnEvent", function()
    -- settle first: one look a moment after the last change, not one per change
    S.changedAt = GetTime()
    if S.armed then return end
    S.armed = true
    local function wait()
        if GetTime() - (S.changedAt or 0) < S.SETTLE then C_Timer.After(S.SETTLE, wait) return end
        S.Check()
    end
    C_Timer.After(S.SETTLE, wait)
end)
S.frame = f
