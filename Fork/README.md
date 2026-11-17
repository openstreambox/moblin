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
- The decision waiting on a screen is its only filled button. HIDE is a heavy
  outline in the text colour.
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
