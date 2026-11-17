# OSB fork of Moblin

This branch builds Moblin as **OSB**, one app for joining a streaming setup,
using a phone as a companion or remote control, and streaming. It is based on
[Moblin](https://github.com/eerimoq/moblin) by Erik Moqvist, under the MIT
licence in `LICENSE`. The licence and the upstream credits stay as they are.

The fork does not use the Moblin name, logo or mascot. Nothing upstream is
deleted. The upstream defaults stay in `Config/Base.xcconfig`, and
`Config/Fork.xcconfig` changes them at build time:

- `MOBLIN_DISPLAY_NAME = OSB`: the home screen, Watch and widget names, the
  permission prompts and the texts in every language. `utils/rename_app.py`
  rewrites the built app's string tables, so `Common/Localizable.xcstrings`
  stays as it is upstream.
- `MOBLIN_URL_SCHEME = osb`: settings links are `osb://?…`. The setup's join
  link (`osb-hub://join#…`) and the demo dashboard's link (`openstreambox://`)
  are separate schemes and keep working.
- `MOBLIN_EXCLUDED_FILES = MoblinBrand.xcassets`: the Moblin app icons, the
  mascot and the icon store's icons stay in the repository but are left out of
  the build. `OsbBrand.xcassets` in each target provides the OSB icons, which
  `Fork/Icons/render.sh` renders from the SVG sources there.
- `MOBLIN_HIDDEN_FEATURES`: Swift compilation conditions that hide features.
- `MOBLIN_FORK_FEATURES = OSB_BRAND`: the setup panel and the join sheet use the
  OpenStreamBox look (paper and forest ink, the latch-case mark) and call the
  whole thing a "setup". Without it they use the system's colours and a
  system symbol, and keep the word "rig" in Settings, the quick button, the
  panel, the join sheet and the name of the stream the hub sets up.

## What is hidden, and why

| Flag | Hidden | Why |
| --- | --- | --- |
| `MOBLIN_HIDE_STORE` | The mascot button in the control bar, the store in settings, the "buy icons" reminders | The store sells Moblin icons; the fork has no rights to them |
| `MOBLIN_HIDE_MASCOT` | The "Moblin in mouth" quick button and its remote control filter | It shows the mascot on stream |
| `MOBLIN_HIDE_MOBLIN_SERVICES` | Moblin Cloud, the go-live notification to the Moblin website, Help and support (Moblin's Discord and GitHub), the website, privacy policy and version history in About, the remote control assistant websites, the Mobcam wizard | They are Moblin's own services, community and tools, run by its developer, not by this fork |
| `MOBLIN_HIDE_CHAT_BOT` | The chat bot setting | Its commands start with `!moblin` |

Features the fork doesn't need for its first use sit behind Moblin's own
"Show all settings" switch, which is off by default.

## The setup screens

The OSB build says "setup" for the gear and the people that stream together (a
build without `OSB_BRAND` says "rig"). The setup panel, the join sheet and the
one status line over the camera are in `Moblin/View/Hub/`. Their colours,
shapes and sizes are in `HubLook.swift`, and the wording and the rules for
what each control shows are in `Moblin/Hub/HubProtocol.swift`, with tests in
`MoblinTests/Moblin/Hub/`.

- "Live" is only said for the hub's output to the platform. A phone reaching
  the hub is Connect and Connected, and changing what viewers see is Move
  stream to phone. While the output is live nothing reads "not live".
- A status is a shape, a word and a colour together.
- Only the primary action is filled: the one thing the screen wants next, at
  most one per screen. Allow comes first (the first one this phone may give,
  or Allow all after a takeover), then Connect while it is the next step, then
  Keep on an owner's ask. Nothing is filled while the output is live or after
  the stream ended. Move stream to phone, Share and Copy are outlined.
- HIDE is a heavy outline in the text colour with the crossed-out eye, never
  filled. It shows the action or the state, never both: once on, it reads
  "Privacy screen on" with the same eye, and Show the picture is its own
  outlined button beside it for whoever may show it. Someone who can't toggle
  it now (a helper while it is on, or anyone while the hub can't hear the
  phone) sees it disabled, with the reason under it. The app keeps no HIDE to
  send later, so it never offers one the hub can't hear.
- A control reads as done only when the hub's state shows it. Until then it
  says what was asked for ("Hide requested, not confirmed yet").
- Only what the hub reported is listed.

Debug builds can show every state without a hub, for screenshots and UI
checks: launch with `-HubShowcase <name>` (the names are in
`Moblin/View/Hub/HubShowcase.swift`), `-HubShowcaseScroll YES` to open the
panel at its end. On a Simulator, which a script can't tap, the panel's
actions also run from system notifications, for example
`xcrun simctl spawn booted notifyutil -p osb.hub.debug.connect`, and
`-HubDebugNoSend YES` makes Connect only ask the hub to check the feed, so a
test picture sent to the phone's slot can stand in for the camera a Simulator
doesn't have.

## The crew and "Who has access"

An owner device gets two more screens from the setup panel, in
`Moblin/View/Hub/HubCrewViews.swift` and `HubAccessViews.swift`. Their words
are in one file, `Moblin/Hub/HubWords.swift`, and the reading of the hub's
list and its wording in `Moblin/Hub/HubAccess.swift`.

- **Crew:** who is in, by person, one line each, in the same groups as the
  other OpenStreamBox apps: each owner with their devices, Co-owners, Helpers
  and Mods, each with its own way in. Add a helper (who it is for, when access
  ends, how long the link stays open, and "Let them run this stream"), add a
  mod, or add a co-owner by name. The link is shared with the system's share
  sheet or as a code to scan, and shown once. A waiting device is allowed on
  the panel or here; a new co-owner's device only after a second, explicit
  "Make co-owner", and another owner's own device only by that owner. An owner
  sets their own name here too.
- **A handed-over stream:** an owner hands one stream to a helper, by a link
  or on their row, and sees who runs it, until when and why, and what they let
  in, with Set an end time (1 hour to 7 days, or none) and Take back. Handed
  over before Go live, it asks how long the handover may wait for the stream
  to go live (30 minutes unless another time is picked); the phone it was
  handed to says by when to go live. A handover runs while the stream is
  live; when the hub asks the owner devices
  whether it goes on, the question shows on the panel, in Crew and in Who has
  access with Keep, Set an end time and Take back now, and as a quiet
  notification. Ignoring it is safe. The phone that was handed a stream says
  so, says what it may do and until when, adds helpers and mods for that
  stream only, and gives the stream back. After End stream it says by when to
  go live again to keep running it. The hub's newest state decides whether the
  handover is still on; past its end the phone drops those controls by its own
  clock, even if the hub's next state comes late, and its own role's controls
  stay.
- **Who has access:** every device, helper, mod and unused invite with its
  role, what it may do in a plain sentence, how it joined, who gave it and when
  it ends; Allow, Remove or End now with one confirm, Change when it ends, and
  what happened. It also shows who runs the stream, hands the stream over and
  takes it back, and clears the list of what happened. The owners' web links
  to the list are shown with End now.
- Both are read over the phone's own encrypted hub connection. Nothing opens a
  web page.
- Only an owner device, or the device that runs a handed-over stream, is
  offered any of it. Other devices see who helps, by name, and no buttons. The
  hub checks every request itself, and its refusals are said in words.
- While the privacy screen is on, the status says who asked for it when it
  wasn't this phone.

## When an owner takes the hub over

An owner can start the hub on a paired standby when the computer it ran on is
gone. The phone takes part without running a takeover itself
(`Moblin/Hub/HubSeen.swift`, `ModelHubSeen.swift`):

- An owner device keeps what it saw of who may do what: the hub's access
  counter, when it last heard from it, what the hub said about each standby
  and the devices removed in the last day (the newest 32), including a removal
  it sent and the hub hasn't confirmed yet. It keeps this beside the device
  key, on this device only, and says it in every reconnect, so a standby can
  tell that its copy is behind and make every device wait for Allow.
- It keeps the hub's own addresses and its standbys' from the hub's state and
  tries them after the address that last answered. A standby points it back to
  the hub; it doesn't follow that (following a moved hub is not built here).
  Only the address that last answered as the hub may say this phone is out.
- After a takeover that kept everyone in, the status keeps its line and adds
  "Your hub now runs on … This device is still in." for two minutes. A device
  the hub made wait says why: an owner started the hub somewhere else and has
  to allow it again.
- Who has access, after a takeover that may have missed something: how much
  may be missing, who was removed in the last hour (they stay out), and the
  devices that were in, by name, with Allow all.

The main button follows what the hub reports about this phone, so it reads
Disconnect whenever the status says the phone is connected.

More fixture names for `-HubShowcase` cover these screens (`owner`, `crew`,
`access` and others in `HubShowcase.swift`); `-HubShowcaseSection <id>` opens a
list at one section. `-HubDebugLinkFile YES` makes a debug build also write the
link it just made to `Documents/hub-debug-link.txt`, so a test run can play
the helper or the mod.

## Known leftovers

- "Moblink" stays: it is the name of the bonding protocol and of the relay
  apps the fork works with.
- The alert widget's gallery still lists three mascot animations by name, and
  the bundled colour LUT is still called "Moblin Meme"; both sit behind
  "Show all settings". The gallery's defaults are picked by position, so
  hiding entries needs a small upstream change first.
- Hidden features still mention the old name in a few fallback texts that are
  never shown while they are hidden.

The OSB name and the latch-case icon are placeholders. OpenStreamBox is a
working name, and its trademark check is still to come before a public release.

Reconnects check authenticated ownership and access evidence before accepting a
candidate or remembering its address. The phone pins the ownership root and
signed history, rejects older or conflicting history, and never lowers the
highest access counter it has observed. A newly scanned setup starts a separate
account; its counters are not compared with another setup's counters. Existing
local accounts without a setup marker bind to the currently saved setup once.

Removal names describe only what this phone has observed. A takeover's reported
removal count is shown even when its trail contains no individual names. Empty
or cleared history cannot establish that nobody was removed. Reconnects omit
removals older than one day, including after a restart without a new state.

The reconnect regression uses three loopback endpoints with the same Noise key:

```sh
tests/osb-hub/run-reconnect-regression.sh
```

The test compiles the production Noise responder and uses the pinned `ws` package.
The first endpoint offers an older epoch with a current counter; the second
offers an older counter; the third offers the pinned epoch and last counter seen. The test checks endpoint selection, saved evidence and the next
hello. It does not install the app or contact a deployed hub.
