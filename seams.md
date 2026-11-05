# poke-ecology seams

Every engine function the mod wraps, and every hook/event/option/save
key it touches. Guard flags are idempotence keys: a second boot (or a
late module load) re-runs the installer but never double-wraps.
Unless noted, the wrapper calls through to native when the mod is OFF,
the result is nil, or the arguments aren't ours. Vanilla tables are
never rewritten: substitutions patch the returned encounter (or the
single table field) and leave the source rows alone.

Boot (`main.lua`): options define, data tables, logic, then source →
urtc → context → hooks → natmap → untamed → diag, each step
pcall-isolated (`boot` logs the label and continues).

## Encounter substitution (`adapter/hooks.lua`)

- `encounter.roll` hook: calls `next()` first; nil passes through;
  non-nil land/water encounters (terrain from `ctx.terrain`) go
  through `H.substitute` with the map from `PE.context.mapId(ctx)`.
  Roamers (`enc.roamer`) pass through untouched on every path. OFF
  returns the hooked result as-is.
- `src.core.game3.encounters.rollSweetScent` / `rollRocks` /
  `rollFishing` (guarded `E.__pe_rollSweetScent` etc.): native runs
  first; nil passes through; else `H.substitute` with the call's own
  map/terrain/rod. This is the seam Wilds of Hoenn's visible spawns
  roll through (its patch looks the function up per call on the same
  module table, so either load order works), plus the engine's own
  Sweet Scent item flow. Install retried on `game.ready`,
  `map.entered`, `save.loaded`, `battle.started`.
- `H.substitute`: builds the cached pop for (map, terrain, rod,
  bucket, day, seed, no-legendaries, gen mask, dex sig), reweights
  by live weather, picks one entry, writes species/speciesId/level
  (±1 jitter clamped to the stage floor and entry ceiling).
  Personality, IVs and moves ride along untouched. Repel
  (`PE.context.repelBlocks`) returns nil instead — callers treat it
  as no encounter. Roamers and nil pass through; OFF passes through.

## Untamed overworld (`adapter/untamed.lua`)

- `wildArea` on the Untamed engine (`mod.find("untamed_advanced")`
  `.exports.engine`, guarded `E.__pe_wildArea`): nil native result
  passes through; OFF passes through; else the ecology land/water
  pop for the live map (`E.mapId()`, fallback `PE.context.mapId`)
  is shaped to the template role count: blocked forms, live-
  national mismatches (`PE.source.natOk`) and gen-9 lines while the
  numbering translation is inactive (`PE.natmap.dropInactive`) are
  dropped first, weather reweights, largest-remainder seats emit
  `{species, level}` cycled to fill; empty shapes fall back to the
  native slots. No Untamed table is touched. Retried on
  `game.ready` / `map.entered` / `battle.started`.

## Species-numbering translation (`adapter/natmap.lua`)

- `Gfx.sheetFor` on the Untamed engine (guarded
  `E.__pe_sheetFor`): translates the incoming national through
  `N.toSpecies` (dex 906-1025 → pixel-verified
  `data/dex_to_species.lua` id) only while `N.active()`
  (national_dex_gen3 present AND atlas anchors
  `species[1301]==1265` + `species[917]==1013` match); everything
  else passes through untouched, female/shiny args included.
  `N.resetActive` on `game.ready` / `map.entered` (link retried
  there and on `battle.started`); `checkAnchors` warns once when
  the provider is present but anchors mismatch — and in that state
  gen-9 overworld lines are suppressed (`dropInactive`) rather than
  rendered wrong.

## Clock (`adapter/urtc.lua`)

- `src.core.game3.rtc.getInfo` (guarded `Rtc.__peUrtcWrapped`,
  original kept in `Rtc.__peUrtcOrig`): OFF or RTC-error status
  calls through; else the saved anchor (`peUrtc`: wall time +
  game-linear base + hour length) advances by wall-clock elapsed at
  60/URTC_HOUR game-sec per real-sec, re-anchoring on hour change
  or option flip. The host wall clock (`os.time`) drives it, so
  engine GAME SPEED never changes its rate. `U.ensure` installs
  once; the hooks installer calls it too.

## Diagnostic (`adapter/diag.lua`)

Read-only: engine name/national per slot, provider record, Untamed
art probe, rival-mod presence. Installs nothing, wraps nothing,
subscribes to nothing.

## Engine reads (no writes)

All `require` calls are pcall-guarded and fail open (nil module →
vanilla behavior).

- `src.core.game3.encounters`: `tableFor` (map level bands for
  areas with no data row), plus the three wrapped roll calls.
- `src.core.game3.pokemon`: `name` / `national` / `stats` /
  `types` / `speciesMeta` (catchRate) / `evolutions` — the dex scan
  (slots 1-4096 + 9000-11000) and the `natOk` spawn-time re-check.
- `src.core.game3.rng`: `Random32` preferred, else `Random`/65536
  scale (engine 0-65535 draws), else a seeded hash fallback.
- `src.core.game3.runtime` (`getSession`) and `src.core.game3.map`
  (`current`): session/map context, both optional.
- `src.core.game3.weather` (`get`): live weather id for roll-time
  reweighting; a missing module reads as `"none"`.
- `src.core.game3.rtc` (`enabled`, `calcLocalTime`): bucket clock
  with host-clock fallback and 08:00 default (`_linearOf` /
  `_fieldsOf`, `errorStatus` / `ERR` only inside the URTC wrap).
- `src.core.game3.field_semantics` (`getVar` repel steps): repel
  gate; a missing module reads as no repel.
- `src.mods.Schemas` (`gen3View.TYPES`, else `.TYPES`) for
  data-agnostic custom type ids (`PE.engineTypeLoader` override in
  tests); unknown names never match.

## Other mods (read-only contracts)

- `national_dex_gen3` (`mod.find`, guarded): `listSpecies` merges
  legendary/mythical slots and mega/gmax/form flags into the
  runtime block/legend sets; `idOfSlot` + `listForms` (apiVersion
  >= 2) power the form art keys. Absent, older, or erroring
  behaves exactly as before.
- `untamed_advanced`: engine table for the `wildArea` + `sheetFor`
  wraps above (`mapId`, `Data.ATLAS.species`, `Gfx.sheetFor`;
  patched nowhere except the two guarded wraps). Absent → both
  adapters sleep.
- `safari-plus`, `1025dex`: presence only (boot log, rival-mod
  report). No behavior changes.
- Outgoing surface other mods use: `PE.hooks.popSlots` /
  `H.substitute`, `PE.diag.slotReport` / `reportText` /
  `logReport`, `PE.natmap.toSpecies` / `active`,
  `PE.urtc.ensure` / `on` / `hourLen`,
  `PE.source.rescan` / `dex` / `lines` / `natOk` / `sig`,
  `PE.context.clock` / `bucket` / `weather` / `mapId` / `seed` /
  `repelBlocks`, plus `mod.exports.peLegendaries` /
  `peDexLegendaries` / `peBlockedForms` / `peSlotNat` /
  `peConflicts` (pokemon-trainer gym teams read the legend sets).

## Options, save, events

- Options (`data/options.lua`): `ecology` (default ON),
  `no_legendaries` (ON = exclude), `gen1`..`gen9` (ON), `urtc`
  (OFF), `urtc_hour` (choice 1-8 MIN, default 2). Every read is
  live with the ON-side default when the row is absent.
- Save keys: `peSeed` (population seed, generated once),
  `peUrtc` (clock anchor). Both persist across save/load; nothing
  else is stored.
- Events subscribed: `game.ready` (install + boot log + rescan +
  natmap reset/link), `map.entered` (install + natmap reset/link),
  `save.loaded` (seed-cache clear + rescan), `battle.started`
  (install + link retries). No `save.writing` handler — both save
  keys write through `mod.save:set` at decision time.
