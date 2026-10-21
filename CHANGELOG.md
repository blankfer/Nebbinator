# Nebbinator

## 4.0.2

- **You show up in FojjiCore's windows.** A party member running FojjiCore now sees your level and experience in its Experience window and your campfire in its Campfires window, instead of "No Addon" (the shared BiS lib, version 16 - quiet if you run FojjiCore's Dungeon Journal yourself, which says the same).

## 4.0.1

- **Carries the shared ride clock** (the BiS lib, version 15): ride a zeppelin or a boat with any BiS addon on and its timetable goes to your guild and group - for BiS Tools' ride card and Power Word: Shell's ZEPPELIN.EXE and HARBOR.EXE.

## 4.0.0

Rebuilt for WoW Forever. TBC is no longer supported.

**Recruiting as a guild**
- **The guild's list.** Every recruit somebody in the guild is talking to is shared with the guild. Officers see a summary: who, how far along, who is talking to them, and the note. Everyone else sees only who is a recruit and who is talking to them. Nobody sees what a recruit whispered.
- **Officers set what the guild needs.** Set them on Recruit, then press **Send to the guild** on the new Team page. Every Nebbinator in the guild takes the newest needs an officer sent, and the ad follows them.
- **The party scout.** Group with somebody whose class the guild needs and you get a card asking you to ask them to raid with you. It is big and plays a sound when they have no guild, and small and quiet when they already have one. If somebody in the guild is already talking to them, the card says who and when ("nudge them to join"). You get one card per person per week. `/bisn scout` turns it off.
- **Fenced into the guild.** Your save is shared by every character on the account, so each guild gets its own book: its needs, raid times, Discord, desk and recruit list. An alt in another guild never sees or shares your main's.
- **BiS Guild** shows the guild's recruits and needs in its terminal, and **BiS Tools** puts a gold crest under any recruit you pass.

**Forever fixes**
- **The alert sounds play.** Forever ignored the old sound files, so they now use the game's own sound kits.
- **A long ad posts one part per click.** Forever only lets a click post to a channel, so the second part of a long ad used to vanish. Now the button says "2/2" and the next click sends the rest.
- **Chat lockdown is respected.** Inside instances and boss fights, a post tells you to wait. Whispers are held and sent the moment the game allows it, with a card showing how many are waiting.
- **The logs link uses your own realm and region.**
- **Joined, declined and invited are noticed.** The desk sees "X has joined the guild" and marks them accepted. A whisper reply can be marked invited.
- **The desk forgets.** Rows untouched for a month go (anything after three months), and the desk never holds more than 300.
- **Auto-reply knows what you need.** "We need 2 Resto Shaman right now" when they say they play one. There is also a launch-day mode that answers everyone.

**One window**
- **The house shape, 1.43:1, with tabs:** Desk, Team, Stats, Recruit, Message, Replies, About. The desk no longer grows with every whisper; it scrolls.
- **Cards**, in the style of the SURVIVOR rally banner: the party scout, a working bar while `/who` looks someone up, and held whispers.
- **What works:** the Stats page shows which channel, which ad and which time of day brings whispers. A reminder card in town offers to post the same ad again (Never / 10 / 15 / 30 min).
- **`{nextraid}`** in an ad: the next raid from BiS Guild's pasted Raid-Helper event ("Wed 20:00").
- **The minimap button is the family's.** Left click opens the window. Right click opens a menu with the pages and the auto-reply, party scout and preview switches. The star brightens while somebody new is waiting.
- **NebbinatorAPI version 2:** other addons can read the guild's list, the needs, whether a player is a recruit, and what works.

## 3.6.1

- **BiS addons can talk to other players on Forever again.** The game wrongly says addon messages are restricted, and the shared BiS code believed it, so nothing this addon sends to other players went out. It does now - and your guild's BiS Guild map shows where you are (outside instances; `/biscomm share off` turns that off).
- **Names with surnames work.** The shared code now uses your whole "Name Surname": you no longer show up twice on your own guild map, and party members with surnames are recognised.

## 3.6.0

- **NebbinatorAPI** - other BiS addons can read your recruits, the current ad and the desk's status, and open the window. It's read-only: nothing else can post your ad or whisper anyone.
- The addon list shows **BiS>Nebbinator**, like its category.

## 3.5.0

- **Your guild can see you on BiS Tools' map.** Every BiS addon now shares your spot with guildmates while you move - every 15 seconds in a small guild, slower as it grows, never from inside an instance. On by default; `/biscomm share off` (or `on`) switches it for every BiS addon at once.
- The shared BiS channel no longer hooks the summon popup on Forever, where hooking Blizzard's code can break it until a restart.
- An icon in the addon list: the gold star from its minimap button.

## 3.4.0

- **Options window**: the BiS shape (1.43:1) with settings in even columns, a help strip at the bottom, and it no longer opens on top of another BiS window.

- **The command is `/bisn` now**, like the rest of the BiS family (`/bish`, `/bist`, `/bisg`). `/nb`, `/ns` and `/nebbinator` still work.

- **No errors from hidden chat on Forever.** A whisper, channel line or `/who` result the game hides during an instance lockdown is no longer read (it threw, the way Questie does). It is counted and skipped; a hidden whisper is still in your chat, and Nebbinator says so once.

- Shared messaging library updated (LibBiSComm minor 10): after a boss, when the game lifts its chat lockdown, BiS addons say hello again so group lists stay current; it respects a realm that blocks addon messages, picks the raid channel only when the game confirms you are in a raid, and ignores anyone flooding it.

- Queue name column 110 -> 150 px: a Forever name with its surname ("Kumlanceroo Wildhammer") no longer gets cut.
- Lighter: the send-button clocks only run while the window is open (they ran 4 times a second
  from login to logout), and the guild roster is read when an auto-reply needs it, not on every
  roster ping. Shared libs: LibBiSComm minor 9, BiS> prompt minor 5.

## 3.3.2 - 16 Sep 2026

- LibBiSComm minor 6: summon API moved to C_SummonInfo on 2.5.6 — the phantom-summon filter works again.

## 3.3.1 - 11 Sep 2026

- Shared console minor 4: the blinking cursor in the `BiS>` header is its own text now, so
  the words beside it no longer shift a hair every half second.

## 3.3.0 - 10 Sep 2026

The Settings tab is gone. Settings live in the window every BiS addon wears.

- **One options window, shared.** Arn, looking at BiSTools' Hub: *"this is
  beautiful ... I want all option windows to look like this."* So the generic
  half of that window moved into `BiSTheme/Options.lua` - self-guarded and
  embedded under `Libs\` exactly like `Console.lua`, carrying its own primitives
  so it borrows no widget kit from its host. Nebbinator is the second addon to
  wear it; the third is a table and a TOC line.
- **Four control kinds and no more**: toggle, 3-way seg, stepper, button. A
  setting that fits none of them is a slash command, not a fifth kind. The
  stepper clamps, so a setter that does not still cannot store junk.
- **Where the Settings tab's contents went.** Sounds, cooldown, auto-reply, the
  minimap button and the lead finder are rows in the options window. The logs
  address is the box on the desk, where you use it. Extra channels became
  `/nb channels <a, b>`. The alert sound became a stepper that plays each one as
  you land on it, which beats a grid of ten buttons.
- **`o` in the header** opens it, so does `/nb config`, and the box lights while
  it is out.
- **Every option calls the function the slash command owns.** None of them
  writes a saved variable itself, and the tests drive both paths at the same key
  and watch them agree - including the side effects, because a hand-written key
  is right and a missing `Minimap:Update` is not.
- **Both test suites read the TOC now.** `dev/theme.lua` kept its own copy of the
  file list, drifted, and was still loading `UI/Pages/Responders.lua` a day after
  the TOC dropped it - a suite testing an addon the client does not run.
- 458 checks, plus 59 for the shared kit on its own.

## 3.2.1 - 10 Sep 2026

Four things the first desk got wrong, all of them things Arn saw and the tests
did not.

- **The window walked down the screen.** Every relayout - pinning a channel,
  rolling the book, a whisper landing - re-anchored the frame to `top - height`
  instead of `top`, so it fell by its own height each time. The harness answered
  `GetTop()` with a flat `600`, which is exactly why no test could see it; the
  harness now does the anchor arithmetic and six checks watch the top edge.
- **The filter row never drew.** Its container frame had one anchor and no
  width, so it measured 0 wide and its buttons rendered nowhere - the desk
  reserved the 22 px and showed a blank band under the send buttons. The buttons
  hang off the desk directly now, like everything else on it.
- **The minimap button was blank.** `Interface\Icons\INV_Scroll_11` is not in
  this client. It is a star off the raid-target sheet now, which is core UI art
  and cannot go missing. The "somebody waiting" ring was also a solid square
  drawn *over* the icon; it is a pad *behind* it, and the star brightens.
- **The logs box showed the tail of the address.** `SetText` leaves the cursor
  at the end, so a long URL read `cter/us/dreamscythe/[name]`. Cursor home.

## 3.2.0 - 10 Sep 2026

The desk, and the book behind it.

- **The window is the queue now.** Nebbinator opens as a 620 px desk: the
  prompt header, one 16 px line per person waiting, the one you are serving
  opened up underneath, and the send buttons along the foot. Nothing else.
  It grows one row per whisper and shrinks one row per accept or decline, so
  the window is exactly as tall as the work in it. Past ten waiting it stops
  growing and the list scrolls instead.
- **The rest rolls up.** Recruit / Message / Replies / Settings / About moved
  behind a header button. Open it and the window widens to 820 and the tab
  rail appears beside the desk; close it and it is a desk again. The state is
  remembered (`bookOpen`), and `/nb book` toggles it from chat.
- **An empty desk is the smallest desk.** No list area at all - the hint lives
  on the count line. The first whisper used to *shrink* the window, which is
  the opposite of the point.
- **Send buttons pin.** Right-click one to take it off the desk; the `v` arrow
  brings the hidden ones back. The elapsed clock moved to the button's right
  edge and the label to its left, with the width reserving room for both -
  on a long channel name the clock used to print straight through the label.
- `UI\Pages\Responders.lua` is gone; `UI\Desk.lua` replaces it.
- 367 checks, four of them mutation-verified.

## 3.1.0 - 9 Sep 2026

The house style, and the shared channel.

- **The header is a prompt.** `BiS> Nebbinator_`, cursor blinking, standing
  slots rotating every 3 s and events jumping in over them. The 64 px bar with a
  logo, a version, a PREVIEW pill and a new-responder badge is now a 16 px bar
  with the prompt and one 12x12 close box; the pill and the badge were state, so
  they became slots. `BiSTheme/Console.lua` ships under `Libs/` so it works
  whether or not BiSTheme is installed.
- **Chat is for `/slash` answers only.** Everything the addon used to announce -
  a whisper landing, an ad going out, a cooldown, a lookup - now goes to the
  prompt instead. The only line left in chat is the settings-upgrade notice.
- **LibBiSComm embedded** (minor 3, byte-identical to `_bisdev`). Registered and
  booted from `Core/Init.lua`; `/bis off` is remembered in `NebbinatorDB.comm`
  and restored next login. No Nebbinator setting can mute it, and Nebbinator
  puts nothing of its own on the wire.
- **One version, in the TOC.** `NS.VERSION` reads `GetAddOnMetadata`. It had
  been a literal saying `2.0.1` since the v3 rebuild while the TOC said `3.0.0`.
- `dev/suite.lua` is `dev/tests.lua`, the name every other BiS addon uses.
  313 checks, five of them mutation-verified.

## 3.0.0 - 27 Aug 2026

One window, six tabs, on the BiS palette. Responders / Recruit / Message /
Replies / Settings / About, replacing the two Blizzard-backdrop windows.

## 2.0.0 - 26 Aug 2026

Rewrite: deterministic message order, real channel lookup, 255-character
splitting, send cooldowns, quick replies, auto-reply, `/who` from a click only.

## 1.0.0

The original.
