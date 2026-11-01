# ScreenshotsAgent

An app's screens captured for design review and README media, shipped as a
[Granite](https://github.com/riteshpakala/Granite) agent package. A call builds the iOS app by its scheme, launches it
on a headless simulator once a destination, waits for each screen to settle, and keeps it, in light and dark, on an
iPhone and an iPad, with the status bar at 9:41; then it writes the PNGs, a labelled contact sheet and a README table
of them. Nothing opens on the person's screen.

It is one of the [Rao Craft Agents](https://github.com/Rao-Craft-Agents): independent packages that, tagged in prompts
along the life of a project, build an app of [Loom](https://github.com/riteshpakala/Loom)'s quality. `screenshots`
shows what the others made: the pages `granite` laid out, in the look `design` and `loom` gave them, on the data
`mocks` serves, ready for `docs` to embed.

## How an app finds it

ScreenshotsAgent is a `GraniteAgentPackage`, and it carries a record in its binary:

```swift
@used @section("__DATA_CONST,__granite")
let screenshotsRecord: GraniteRoster.Record = { GraniteRoster.record(ScreenshotsAgent.self) }
```

In [Craft](https://github.com/riteshpakala/Craft), install it from the Agent Store or with
`craft agents add https://github.com/Rao-Craft-Agents/ScreenshotsAgent.git`, then say `$screenshots` in a request:

```
$screenshots every page of the recipe app, light and dark, for the README
```

The model writes the call; it shows on Craft's agent map as `screenshots-1`. It answers images (and the README when its
table changed), so a repeated capture costs the turn no build.

## What a call takes and answers

| Field | | |
|---|---|---|
| `scheme` | optional | the scheme that builds the iOS app; `<App>-iOS` when left out |
| `devices` | optional | simulator names (`iPhone 18 Pro`), `iPhone` or `iPad` for the newest installed, `Mac` for the Mac app; the newest iPhone and iPad when left out |
| `appearances` | optional | `light`, `dark`; both when left out |
| `destinations` | optional | the app's `AppDestination` cases to open; every case when left out |
| `arguments` | optional | launch arguments added after `-mock YES -destination <case>`: `["-signedIn", "YES"]` |
| `settle` | optional | the most seconds to wait for a screen to stop changing; 15 when left out |
| `into` | optional | the folder, relative to the project; `Resources/Screenshots` when left out |
| `directory` | the host's | the folder the host works in; a host fills it and does not show it to a model, and a call whose JSON leaves it out works in the folder the host offers (`AgentHost.directory`) |

The answer is a `ScreenshotsResult`: every file written (`path` is the contact sheet, `paths` every image, the sheet and
the README when its table changed, absolute), the devices, appearances and destinations captured, how many screens, and
a sentence for anything it did differently from what was asked. A host builds a project after a call that changed
anything but media, so a capture that leaves the README as it was costs the turn no build.

```
{"devices": ["iPhone 18 Pro"], "appearances": ["dark"], "destinations": ["feed", "settings"]}
```

writes `Resources/Screenshots/iPhone-18-Pro/dark/feed.png`, `…/dark/settings.png`, `Resources/Screenshots/sheet.png`
and `Resources/Screenshots/README.md`.

## How the screens are made

| Step | What |
|---|---|
| Read | the project (`.xcworkspace` or `.xcodeproj`) and its shared schemes; the destinations, the cases of `enum AppDestination`, and whether the app reads `-destination` (`AppDestination.launchArgument`, which `granite` navigation writes) and `-mock` (`MockMode`, which `mocks` writes); the simulators from `simctl list`. A scheme, device or destination that does not exist is refused with every reason at once, and nothing runs |
| Boot | each simulator that is not running is booted headless (`simctl boot`; Simulator.app is never opened), while the app builds; the capture waits for its home screen, since `bootstatus` is done while the boot logo still shows |
| Build | `xcodebuild -scheme <App>-iOS` for the simulator, signed ad hoc, into derived data kept for the project under the temporary folder, so a second capture builds only what changed |
| Capture | the status bar set to 9:41 on Tuesday, January 9 (the bars and battery first, the time on its own after: given together, an iPad keeps today's weekday), full bars, a full battery; the app installed; per appearance (`simctl ui appearance`), per destination, launched afresh with `-mock YES -destination <case>`; `simctl io screenshot` until two looks in a row match, a blank look (a launch screen, a boot logo) never counting, up to `settle` seconds; a screen whose app quit is dropped with a note |
| Leave | the app ended, the appearance put back, the status bar cleared (unless it had overrides of its own), the simulator shut down only if the call booted it; on failure and cancel too |
| Mac | when `devices` names `Mac` and this process may already record the screen (`CGPreflightScreenCaptureAccess()`, which never prompts): the Mac scheme built, a copy of the app signed ad hoc without its entitlements (out of its sandbox, so the home the capture gives it is where it keeps its data, never the person's container), launched with its appearance forced for it alone, its window read with `screencapture -l` and quit. Its window shows while it is captured, behind the person's work and drawn as an inactive window, since the capture never takes the focus. Otherwise a note says why it was skipped |
| Write | `<into>/<device>/<appearance>/<destination>.png`, then `<into>/sheet.png` (a row a device and appearance, labelled) and `<into>/README.md` (the sheet, then a table a device) of every screen in the folder, this call's and those an earlier one left, in a stable order: capturing one page again refreshes it and keeps the rest, and a README with nothing new is left alone. Staged, then moved into the project together |

No model is asked: the same project and call capture the same screens.

## Testing

```
swift test                         # the record, the schema, the project and destinations read, the simulators picked,
                                   # the settle, the sheet and README, whole calls against an in-memory simctl
SCREENSHOTS_BUILD=1 swift test     # an app made by the installed granite and network runners, captured for real on
                                   # a simulator the test creates and deletes, the screens read back with Vision
```

MIT licensed.
