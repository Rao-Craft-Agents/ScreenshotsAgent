import GraniteAgents

/// The screenshots agent's place in Granite's roster: an app that links this package finds the `screenshots` agent by
/// this record, with nothing listed by hand.
@used @section("__DATA_CONST,__granite")
let screenshotsRecord: GraniteRoster.Record = { GraniteRoster.record(ScreenshotsAgent.self) }
