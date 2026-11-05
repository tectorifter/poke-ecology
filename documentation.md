# poke-ecology — documentation

## Layers

Data (tables only, no code): rules, options, time_buckets, terrains,
slot_templates, curves, areas, modifiers, overrides, types. Areas map
ids carry progression ordinals and biome tags; terrain availability
comes live from the engine's own encounter tables.

Logic (pure, no engine calls): rng, lines, bands, admit, score,
population, stage, overlay, roll. Every function is deterministic on
its inputs and runs in the standalone harness.

System (adapter, the only part that knows gen1recomp): source reads
the dex, context reads map/weather/clock/rod/seed, hooks intercepts
rolls and writes species and level back into the engine's wild mon.

## Derived at load

Line graph, power (`final_bst` of the strongest branch), stage
thresholds (level params real, everything else nonlevel table or
`stage_index x default_step`), class, habitat tags (types plus
overrides), body plan (flying first, water-plus-land duals walk while pure
water swims, else terrestrial, overrides win), activity (ghost/dark
nocturnal including Hoothoot, overrides win),
rarity (catch-rate cutoffs, overrides win), plus an optional per-line
`ceil` multiplier on the evolution-stage ceiling (the Staryu line's,
so Starmie can resolve on shore grass). `neutralType` forces a line's
stages typeless for ecology (no type tags, diurnal, terrestrial, no
type rows fire); `singleMin` overrides one line's single-stage
ordinal gate; `transientOnly` keeps a line out of the resident pool.

## Admission and weights

Line gate on final power, single-stage ordinal gate by rarity,
habitat gate on any passing stage. Candidates come from the
bucket-neutral score, and residents additionally exclude
`nocturnal_only` and `transientOnly` lines, so the resident pool is identical in every
bucket while bucket bans only reshape transients. Weights multiply habitat fit, BST
proximity, single-stage ramp, rarity, time affinity and static
modifier rows. Night and dawn buckets boost dark, ghost, poison
and bug lines on meadow/forest land (poison 3.0x outweighs its grass
penalty at night); forest areas boost grass, bug, ghost and fairy
lines — the forest_fairy row resolves its type id against the
engine's own schema table at roll time, so on vanilla Emerald it
is inert and on engines/content mods that define Fairy it fires
automatically, with no data changes; urban areas
boost electric lines and the New Mauville plant tag stacks a
stronger electric boost on top; cave terrain mildly boosts
electric lines (Magnemite and Voltorb lines carry cave tags so the
row can fire); morning and afternoon buckets boost electric lines
on meadow/forest land (~4x, tuned so electric shows about every
other roll by day without dominating). Static rows also penalize rock, steel, ground,
poison, fire and ice lines on meadow/forest land (0.25-0.3x), so
they stay rare on grass while volcanic maps boost fire and arctic
maps boost ice; lines tagged `grass_roamer` in overrides (cats,
dogs, and poison/fire/ground species that naturally roam grass)
are exempt from the penalty. Water lines take 0.2x on meadow/
forest land (grass duals like Lotad, which carry the meadow tag,
are exempt) and 0.15x in caves (rock/ground duals, which carry
the rocky tag, are exempt as natural cave dwellers); fairy lines
take 0.4x on meadow/forest land and 0.08x in caves (rock/ground
fairy duals exempt), so both stay off grass and all but out of
caves. Fire lines take 0.25x on land outside volcanic and arid
areas and outside meadow/forest (which the grass row already
covers — the two never stack), keeping them in caves, volcanic
ground and desert. Dragon lines take 2.0x in caves but 0.3x on
meadow/forest land, fighting lines 1.8x in caves and 0.3x on
grass; the power curve does the age work — the absolute line cap
excludes heavy lines early, BST proximity suppresses them mid-game, and
power sorting keeps them out of common slots, so youth chance
stays very low and likelihood climbs with map level (a 600-power
dragon line scores ~0.4 at ordinal 5, ~2.0 at ordinal 20 in
caves). Bagon, Dratini, Machop and Makuhita lines carry cave tags
so the cave rows can reach them, matching their canonical caves.
A row's `area_tag` accepts one tag or a list,
`target.except_tag` skips matching lines, `target.nat` matches
national numbers on any stage (one row covers a whole line and its
forms), `when.bucket` accepts one bucket or a list, and `when` also
accepts `except_terrain`, `except_biome` and `except_area_tag`
(skip if any area tag overlaps) — a `when` with only `except_*`
keys is a build-time static filter, so it confines lines in
resident and transient scoring alike. A type target matching only one side of
a dual-typed stage weighs softly: the row's multiplier is
square-rooted (1.6x becomes ~1.26x, 0.25x becomes 0.5x); pure
matches count fully. The
relaxation ladder scales up the absolute line cap and relaxes
single-stage gates in order; the last resort is the nearest earlier
area's population for the same terrain. Habitat hard bans are never
relaxed.

Porygon (137/233/474) and Rotom (479 plus forms) are confined to
the `mauville` areas (Route 110, Route 117, New Mauville inside and
out) by `except_area_tag` ban rows, run typeless via `neutralType`
so no normal/electric/ghost row ever fires for them, and Rotom
additionally runs `singleMin` 1 plus `transientOnly`: grass-rare by
day, grass-boosted at night, and an uncommon-weight transient in
New Mauville in every bucket.

## Overworld

Mega-evolved and Gigantamax species are recorded at rescan (name
token, mega-method evolution edge, or dex-provider flag) and dropped
from Untamed-Advanced `wildArea` pops, so overworld sprites are never
those forms; the remaining entries fill the template slots —
cycled evenly when unweighted, proportionally allocated across
weather shares by largest remainder — and an
all-blocked pop falls back to native slots. Engine slots are also
cross-checked against live national ids: a slot whose live national
disagrees with the dex provider (two content mods registering the
same slot, e.g. a mega-form mod colliding with gen 9 slots) is
excluded at rescan, and the wrap re-checks every entry at spawn time,
so a mismatched slot can never render another mon's sprite — the pop
falls back to agreeing species or native slots. Slots with no live
national are excluded the same way. The signature covers nationals,
names, stats, types and evolutions, so any registry change rebuilds;
without a `national` API everything behaves as before. Wilds of
Hoenn needs no adapter: its visible spawns roll through the same
wrapped `rollSweetScent` engine call, so they spawn ecology species
directly, and its bump battles start species-locked from the shown
entity. Roaming legendaries pass through `substitute` untouched on
every path.

The same layers feed a modder-ready diagnostic: `PE.diag.slotReport`
reads engine name/national, provider record, rescan snapshot and
Untamed sheet for one slot and returns a verdict (`AGREE`,
`PROVIDER_CONFLICT`, `ENGINE_FLIP`, `NO_LIVE_NATIONAL`,
`UNLISTED_NO_NATIONAL`, `NAME_MISMATCH`, `ATLAS_GAP`,
`ATLAS_SUBSTITUTE`, `MEGA_BLOCKED`, and the no-data verdicts) plus
a FIX line naming which modder must change what.
`PE.diag.reportText()` renders the flagged slots as one paste-ready
block, and `PE.diag.logReport()` writes it to the game log;
conflicted rescans already log one line per slot plus the pointer.

Species-numbering translation lives underneath the sheet lookup:
Untamed 1.0.2's atlas is keyed by new-expansion SPECIES ids while
the engine reports national dex numbers, so with
national_dex_gen3 present the adapter wraps `Gfx.sheetFor` and maps
dex 906-1025 to the pixel-verified SPECIES id first (all 120
confirmed byte-identical against upstream art, Tarountula 917 ->
1301). The wrap only installs while the provider is present and
the atlas anchors match the new numbering; diag reads through the
same wrap, so its sheet verdicts reflect what actually renders.

## Cache key and rebuilds

`(map_id, terrain, bucket, [day], save_seed)`. Rebuilds happen at roll
time on key mismatch only. There is no timer.

## Unreal time clock

With UNREAL TIME CLOCK on, the adapter wraps the engine RTC's
`getInfo`, the single choke point every clock reader derives
from (`calcLocalTime`, minute counts, berry/tree updates,
time-of-day evolutions, day/night periods, ecology buckets, and
any other mod's time reads). The wrap keeps the host reading as
its base and adds elapsed game time from the host wall clock at
60 game-seconds per real-second divided by URTC HOUR, so a full
24-hour cycle takes 24x the setting; engine GAME SPEED only
scales per-frame logic deltas, never the wall clock, so the rate
is immune to it. The toggle and hour length are read live, so
both apply without restarts; changing the hour length (or first
enable) re-anchors the clock at the current game time and the
anchor persists in the save. With the toggle off the wrap calls
straight through to the host clock.

## Roll

Slot templates carry vanilla weights and roles. Common slots fill
with the lowest-power entries, rare slots with the highest. The final
pick weights template weights by the weather overlay (bans win) and
uses engine RNG. The substituted level rolls ±1, clamped to the
stage threshold and the band top. Repel is re-checked after substitution.

## Open points

Fishing and rock smash go through direct engine-call wraps because
those paths have no mod hook. If the game clock (RTC) is disabled the
adapter pins hour 8 (morning bucket) and derives the day count from
wall-clock time, so per-day reseeding keeps rotating. Body plans for fish versus
serpentine and the land exceptions are the only hand-authored species
data; everything else is derived. Species enumeration scans ids
1-4096 and 9000-11000 on first use, save load and game ready, plus
a short forward probe per roll, so content mods that add species
are picked up without restarts.
