# Testing ScreenshotsAgent

How `screenshots` is tested: its own suite, its gated capture of a real app, and prompts run through
[Craft](https://github.com/riteshpakala/Craft) on a Mac with Craft's own local model, each logged below verbatim with
what came out. A prompt is run as a person would type it, in a project folder, with `$` naming the agent; nothing is
edited between the prompt and the screenshots. A test that needs a server uses mock backend responses, never a live
service.

## The suite

```
swift test                                                # the record, the schema, the project and destinations read,
                                                          # the simulators picked, the settle, the sheet and README,
                                                          # whole calls against an in-memory simctl and xcodebuild
SCREENSHOTS_BUILD=1 swift test --filter ScreenshotsBuildTests   # an app captured for real (gated, minutes)
```

The in-memory calls hold the rules that matter on a person's Mac: only a simulator the call booted is shut down; a
booted one is used as it is; the appearance is put back and the status bar cleared unless it had overrides of its own;
a failed build or a cancelled call still leaves every device as it was found and writes nothing; a refusal names every
problem and runs nothing; a repeated capture answers images alone.

## The gated capture

`ScreenshotsBuildTests` makes an app through the installed runners, as Craft calls them (`granite` project, `network`
client package `RecipeKit`, a `Recipes` service that loads from `RecipeClient.preview`, a list, a search and a
settings page, `granite` navigation with three destinations), creates a simulator of its own
(`Screenshots Test iPhone`, deleted after), and calls `screenshots` through `AnyAgentPackage.perform` with that device.
It reads every image back with Vision: the status bar says 9:41, each destination shows its own page title (not the
launch screen), the list shows the preview client's recipe, dark images are dark; the contact sheet is labelled; the
simulator the call booted is shut down again; a second, narrower call answers its one image, the sheet and the README.

Run on this Mac (MacBook Pro M4 Max, macOS 27, Xcode 27.1, iOS 27.0 runtime), 2026-11-01:

```
swift test                                                       44 tests, 1 skipped (the gated one), 0 failures, 1.4 s
SCREENSHOTS_BUILD=1 swift test --filter ScreenshotsBuildTests   1 test, 0 failures, 105 s (the call itself 60 s, its build 17 s)
```

## Verified by hand

Every image was opened and looked at, not only read back by the test: each destination shows its own page with its
tab or sidebar row selected, never the launch screen; dark is dark; the status bar reads 9:41 with full bars and a full
battery, no charging bolt.

The iPad and the Mac were captured from a scratch package that calls the agent through `AnyAgentPackage.perform` (a
simulator of its own, `Screenshots Test iPad`, deleted after): `{"devices": ["<its UDID>", "Mac"]}` on the fixture app
wrote 12 screens and a sheet with an iPad and a Mac row an appearance in 76 s. What those runs found, each fixed and
pinned in the code:

- `bootstatus` says a device is done while it still shows the Apple logo, and two looks at the logo match: the session
  waits for the home screen, and a frame of one colour but a mark in the middle (a logo, a launch screen) never settles.
- `--time` given in one override with the bars and the battery keeps today's weekday on an iPad ("Sun Jan 9"); given on
  its own after them, the iPad reads "Tue Jan 9".
- `screencapture` will not write a file whose name starts with a dot, and exits 0 all the same.
- `Process.waitUntilExit()` hung once for good on a `screencapture` that had exited: exits are heard through
  `terminationHandler` now, and a command past its timeout is killed.
- A light `AppleInterfaceStyle` leaves a dark Mac's app dark: light is `-NSRequiresAquaSystemAppearance YES`.
- A sandboxed Mac app ignores `CFFIXED_USER_HOME` and writes to its container: the capture runs a copy signed ad hoc
  without entitlements, so it keeps its data in the capture's own home.

## Prompts run on this Mac

None yet: prompts are run through Craft, with the agent installed from this repository, and logged here as they are.

## Conformance on Hearth

Level 1 of the regime: the call a model should write, sent straight to the installed runner over its wire
(granite-agent/1) with no model, on a copy of Hearth as the journey left it (services, mock data and loom's views
made), then checked by building, testing and screenshotting the app. A pass here means the agent can produce the
result deterministically; whether Craft's model writes this call is tested by the prompts above.
