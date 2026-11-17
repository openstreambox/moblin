# OSB fork of Moblin

This branch builds Moblin as **OSB**, one app for setting up a streaming rig,
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
- `MOBLIN_URL_SCHEME = osb`: settings links are `osb://?…`. The rig's join
  link (`osb-hub://join#…`) and the demo dashboard's link (`openstreambox://`)
  are separate schemes and keep working.
- `MOBLIN_EXCLUDED_FILES = MoblinBrand.xcassets`: the Moblin app icons, the
  mascot and the icon store's icons stay in the repository but are left out of
  the build. `OsbBrand.xcassets` in each target provides the OSB icons, which
  `Fork/Icons/render.sh` renders from the SVG sources there.
- `MOBLIN_HIDDEN_FEATURES`: Swift compilation conditions that hide features.

## What is hidden, and why

| Flag | Hidden | Why |
| --- | --- | --- |
| `MOBLIN_HIDE_STORE` | The mascot button in the control bar, the store in settings, the "buy icons" reminders | The store sells Moblin icons; the fork has no rights to them |
| `MOBLIN_HIDE_MASCOT` | The "Moblin in mouth" quick button and its remote control filter | It shows the mascot on stream |
| `MOBLIN_HIDE_MOBLIN_SERVICES` | Moblin Cloud, the go-live notification to the Moblin website, Help and support (Moblin's Discord and GitHub), the website, privacy policy and version history in About, the remote control assistant websites, the Mobcam wizard | They are Moblin's own services, community and tools, run by its developer, not by this fork |
| `MOBLIN_HIDE_CHAT_BOT` | The chat bot setting | Its commands start with `!moblin` |

Features the fork doesn't need for its first use sit behind Moblin's own
"Show all settings" switch, which is off by default.

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
