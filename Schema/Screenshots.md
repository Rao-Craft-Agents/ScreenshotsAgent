# craft-agent/1 · screenshots

Captures an app's screens on a headless iOS simulator — every destination, on mock data, in light and dark, on an iPhone and an iPad — as PNGs, a labelled contact sheet and a README table.

screenshots's copy of Craft's agent standard (`craft-agent/1`, Craft's `Schema/Agent.md`), written by
`craft agents schema screenshots` from its record. Everything above **Changes** is written again each time; Changes is
screenshots's own log.

| File | What it holds |
| --- | --- |
| [`screenshots.input.schema.json`](screenshots.input.schema.json) | What it takes, as JSON Schema |
| [`screenshots.answer.schema.json`](screenshots.answer.schema.json) | What it answers: `granite-answer/1` with its own kinds |

## What it takes

| Field | Required | What it is |
| --- | --- | --- |
| `scheme` | no | the scheme that builds the iOS app; the project's `<App>-iOS` when left out |
| `devices` | no | where to capture: simulator names like `iPhone 18 Pro`, or `iPhone` and `iPad` for the newest installed, and `Mac` for the Mac app (its window shows on this Mac while it is captured); the newest iPhone and iPad when left out |
| `appearances` | no | light, dark, or both; both when left out |
| `destinations` | no | the pages to open, as the app's AppDestination cases (`feed`, `settings`); every case when left out |
| `arguments` | no | launch arguments every launch adds after `-mock YES -destination <case>`, such as `["-signedIn", "YES"]` |
| `settle` | no | the most seconds to wait for a screen to stop changing before it is kept; 15 when left out |
| `into` | no | the folder for the images, relative to the project; Resources/Screenshots when left out |

`directory` is filled by Craft with the project folder. The person's request and the host's model are offered
beside the call, never in it.

## What it makes

| Kind | What | Into | Never |
| --- | --- | --- | --- |
| `screen` | a picture of one of the app's screens on a simulator or the Mac, light or dark | `Resources/Screenshots/*` | code |
| `sheet` | every screen captured on one labelled image, and the README that lists them | `Resources/Screenshots/sheet.png`, `Resources/Screenshots/README.md` |  |

## What it answers

A `granite-answer/1` answer (Granite's `Schema/GraniteAgent.md` §4.2): `paths`, `made` against `expected` by kind and
name, `problems` for what it could only do in part, `payloads` for files that keep a standard of their own, and its
own keys beside them. Craft measures each call by what it made of what it expected.

## How it refuses

With an `AgentRefusal`: a kind and reasons, each with its fix. `input` and `call` are the call's to correct; `build`,
`device`, `reach`, `model` and `host` what stood in the way; `answer` and `parse` its own bug.

## Changes

Each change made to make this agent more precise, dated, with the regime run that measured it and what it
made of what it was asked before and after (`TESTING.md`). Newest first.

### 2026-11-04 · answer `granite-answer/1`: captures against the plan

screenshots answers one `screen` per device, appearance and destination it captured, against one per planned, and the `sheet`. A destination it could not reach is a `skipped` problem. Its `appearances` and `destinations` now say what was captured, not what was planned. (22186ba)

Measured: not yet. Answers before this were pre-standard, so there is no precision to compare; the next regime chain on Margin is the first measure.
