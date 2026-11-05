# ScreenshotsAgent

See every screen of your iOS app, on an iPhone and an iPad, in light and dark, without a simulator opening on your
screen. `screenshots` builds the app, opens each of its pages in turn and keeps a picture of each once it has stopped
changing, with the status bar at 9:41. You get the PNGs, a labelled contact sheet and a README table of them, ready
for a design review or your project's README.

## What you can ask

```
$screenshots every page of the recipe app, light and dark, for the README
$screenshots the feed and settings in dark mode on an iPhone 18 Pro
$screenshots the recipe app on an iPad and the Mac
$screenshots just the settings page again
```

Craft writes the call and shows it on its agent map. It answers pictures (and the README when its table changed), so
capturing again costs the turn no build.

## What you get

- **A picture of each screen.** A PNG for each device, appearance and page, in
  `Resources/Screenshots/<device>/<appearance>/<page>.png`, or the folder you name.
- **Light and dark, phone and tablet.** The newest iPhone and iPad installed unless you name simulators, and the Mac
  app when you ask for it.
- **A clean status bar.** 9:41 on Tuesday, January 9, with full bars and a full battery.
- **A contact sheet.** `sheet.png`, a labelled row for each device and appearance, to review every screen at once.
- **A README table.** `Resources/Screenshots/README.md`, the sheet and then a table for each device. Capturing one page
  again refreshes it and keeps the rest, and a README with nothing new is left alone.

## How it works

- It reads the project's schemes, the app's pages (the cases of its `AppDestination`) and the simulators installed
  before anything runs; a scheme, device or page that does not exist is refused with every reason at once.
- Each simulator is booted headless, so Simulator.app never opens, and the app is launched afresh on each page. A
  screen is kept once two looks in a row match, never a launch screen or a boot logo.
- Every simulator is left as it was found: the app ended, the appearance put back, the status bar cleared unless it
  had overrides of its own, and a simulator shut down only if the call booted it, on failure and cancel too.
- No model is asked: the same project and call capture the same screens.

## Works well with

`screenshots` shows what the other Rao Craft Agents made: the pages `granite` laid out, in the look `design` and
`loom` gave them, on the data `mocks` serves, ready for `docs` to embed. It opens each page by the destination
`granite` navigation writes, and launches on mock data when `mocks` has added it; without them it captures the screen
the app opens on, or the data its services load, and says so.

## Get it

In Craft, install Screenshots from the Agent Store, or run
`craft agents add https://github.com/Rao-Craft-Agents/ScreenshotsAgent.git`, then say `$screenshots` in a request.

## Requirements

- A Mac on macOS 14 or later, with Xcode and an iOS simulator installed.
- An iOS app in an Xcode project or workspace, with a shared scheme that builds it (`<App>-iOS` unless you name
  another).
- For the Mac app: a scheme that builds it, and permission to record the screen already given on this Mac. It never
  asks; without it the Mac is skipped with a note. The Mac app's window shows, behind your work, while it is captured.
- MIT licensed.

## For developers

What a call takes and answers, and how each screen is made, are in the [reference](Docs/Reference.md). The agent
standard it follows is [Schema/Screenshots.md](Schema/Screenshots.md), and how it is tested is
[TESTING.md](TESTING.md).
