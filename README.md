# Switchboard

A menu bar app for macOS that puts common system settings one click away and
tidies your screen before you share or record it.

- **Levers** — toggles for Dark Mode, Dock and menu bar auto-hide, desktop icons
  and widgets, Stage Manager, hidden files, Keep Awake, mute, Wi-Fi, screenshot
  options and more, plus one-shot actions (hide other apps, sleep display,
  screen saver, empty trash). Searchable.
- **Presentation Mode** — one button applies the levers you choose (hide desktop
  icons, hide the Dock, keep awake, …) and puts back exactly what it changed
  when you end the session, even if the app quit in between.
- **Automatic start** (optional, off by default) — starts and ends Presentation
  Mode when a watched process is running, e.g. Zoom's screen-share helper.

## Requirements

macOS 14 or later and the Swift toolchain (Xcode or the Command Line Tools).
Builds natively for Apple silicon.

## Build and run

```sh
swift run                 # quick run from the terminal
./Scripts/bundle.sh       # builds dist/Switchboard.app
open dist/Switchboard.app
```

Use the bundled app for everyday use: "Launch at login" only works from the
`.app`.

## Permissions and setup

- **Automation** — the first time you use Dark Mode, Dock/menu bar hiding or
  Empty Trash, macOS asks to let Switchboard control System Events / Finder.
- **Do Not Disturb** — macOS has no public API for Focus. Create two shortcuts
  in the Shortcuts app, each with a single "Set Focus" action, named exactly
  `Switchboard DND On` and `Switchboard DND Off`. Until they exist the lever
  does nothing.
- Levers that change Finder, Dock or screenshot preferences restart that
  process briefly so the change takes effect.

## Adding a lever

Add an entry to `LeverCatalog.all` in `Sources/Switchboard/Lever.swift`. Most
are a single `defaultsToggle(domain, key, fallback:)` line. Give it a
`presentationValue` to make it available to Presentation Mode.
