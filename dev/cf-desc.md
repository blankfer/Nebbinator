# Nebbinator — CurseForge page text (4.0.0)

Paste everything below the line into the project description
(CurseForge → BiS>Nebbinator, project 1683356 → Edit → Description), in the Markdown editor.

Written 21 Oct 2026 for 4.0.0, the Forever rebuild. The page it replaces still described 3.0 on TBC.
In the house voice (`_bisdev/docs/voice.md`): the opener talks; lists and tables stay flat.

---

# BiS> Nebbinator

**Guild recruiting for WoW Forever, done by the whole guild. Post the ad, work everyone who whispers back, and know who the guild is already talking to.**

Launch night. Trade chat scrolls faster than anyone can read, forty people want a guild, and three of your officers are whispering the same healer. Nebbinator gives the guild one desk.

## Your desk

`/bisn` opens one window with tabs down the left: **Desk, Team, Stats, Recruit, Message, Replies, About**.

- **Post your ad** from the send bar: one button per channel, each with its own cooldown. A long ad goes out one part per click, because Forever only lets a click post to a channel.
- **Everyone who whispers lands on the desk**, class already known. Click one to serve them: whisper, send your Discord, invite, look them up, open their logs, or send one of four quick replies.
- **Auto-reply** answers for you, once per person. When they name a class you need, it says so: "We need 2 Resto Shaman right now." On launch day, one switch answers everyone.
- **It keeps up.** Someone joins the guild and they're marked accepted. Old rows clear themselves after a month.
- **Inside an instance the game holds chat back.** Your whispers wait and go out the moment it lets them, with a card counting them.

## Recruiting as a guild

- **The guild's list.** Every recruit anyone in the guild is talking to is shared with the guild. Officers see who, how far along, who is talking to them, and the note. Everyone else sees only who is a recruit and who is on it. Nobody ever sees what a recruit whispered.
- **Officers set what the guild needs.** Set the classes and specs on Recruit, press **Send to the guild** on Team, and every Nebbinator in the guild takes them. Everyone's ad follows.
- **The party scout.** Group with someone of a class you need who isn't in the guild, and a card says ask them. Big, with a sound, when they have no guild; small and quiet when they have one. If someone in the guild is already talking to them, the card says who, and when: nudge them to join.
- **Your alts stay apart.** Every guild has its own needs, desk and list. An alt in another guild never sees your main's.

## What works

The **Stats** page keeps every post and the whispers it brought, three ways: which channel, which ad, which time of day. Fifteen minutes after your last post, in a city, a card offers to post it again.

## Works with

- **BiS Guild** shows the guild's recruits and needs in its terminal (the RECRUITS tab), and gives your ad `{nextraid}` from its pasted Raid-Helper event.
- **BiS Tools** puts a gold crest under anyone your guild is recruiting, so you can put in a good word as you pass.

Neither is needed. Nebbinator works alone.

## Commands

| | |
|---|---|
| `/bisn` | open the window |
| `/bisn desk` | open it on the desk |
| `/bisn config` | the options |
| `/bisn preview` | try everything without posting or whispering anybody |
| `/bisn reply` | auto-reply on or off |
| `/bisn scout` | the party scout on or off |
| `/bisn discord <link>` | set your Discord link |
| `/bisn minimap` | show or hide the minimap button |

## Tokens for your ad

`{guild}` `{needs}` `{needs:short}` `{times}` `{times:full}` `{discord}` `{content}` `{tanks}` `{healers}` `{dps}` `{total}` `{pre}` `{post}` `{player}` `{level}` `{realm}` `{faction}` `{nextraid}`

## Good to know

- **Nothing ever posts on a timer.** An ad goes out when you click its button, and never otherwise.
- **The minimap button**, a gold star, brightens while someone new is waiting. Left click opens the window, right click a menu.
- Part of the BiS family. It talks to the other BiS addons over one shared channel; `/biscomm off` silences it.
- Made for WoW Forever.
