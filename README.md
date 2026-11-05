# poke-ecology

Hoenn, alive. Not a slot machine of random encounters — a living
region where every route has residents and every rare thing you meet
is rare for a reason. This mod rebuilds the wild population of
Emerald from the ground up: evolution lines stake out territories,
caves brood with rock and steel, the sea teems, and the further you
travel from Littleroot, the stronger the bloodlines you disturb.
Walk into the grass and you're stepping into somebody's home.

Vanilla tables are never rewritten — the engine still rolls what it
always rolled. Ecology just decides, with eerie consistency, *who*
lives in each patch of grass, at each hour, in each weather.

## How the wild feels now

- **Lines hold territory, not species.** Selection works on whole
  evolution families. Find Ralts in the early grass and you're in
  Gardevoir country — come back overleveled and the final stages
  walk the same ground. Eevee, Wurmple and Nincada branch like real
  bloodlines.
  
- **Power follows the journey.** Each area sits on a progression
  curve measured from the start of the game, and lines are admitted
  only if their strength fits the neighborhood. The first routes
  rustle with the weak and the young; the deep caves and far seas
  belong to monsters. Single-stage loners join late, like they
  should — you've earned the weird ones.
  
- **Residents and wanderers.** Common slots are stable locals: same
  seed, same faces, day after day. Uncommon and rare slots drift
  with the time bucket and the date — check the same grass at night,
  check it next week, and something new is passing through.
  
- **Weather bends the hunt without rebuilding it.** Rain, sun and
  sand reweight who's out and ban the entries that would never show
  their face in it — all at roll time, instantly.
  
- **Land, cave, sand, surf, and rod.** Caves brood apart from open
  grass, sand apart from both, dive apart from surf, and a better
  rod reaches into deeper water. Fish where the strong fish are.
  
- **Nine generations, your call.** GEN 1–9 toggles gate the pool by
  national-dex range. Cross-generation lines bend, never break: cut
  gen 2 and Onix still walks, it just never answers to Steelix.
  Toggling rebuilds the population on the next roll.
  
- **Legends stay legends.** The NO LEGENDARIES toggle (default on)
  keeps the gods out of the grass. Expansion-dex legendaries from
  content mods honor it too.

## The clock

UNREAL TIME CLOCK (default off) frees time from the engine: one game
hour per URTC HOUR real minutes, so a full day passes in 24 times
that setting — driven by the host wall clock, immune to game speed.
Dawn, day, dusk and night each pull different lines out of hiding.
Turn it on and Hoenn breathes on your schedule.

## It plays well with others

- **safari-plus** — overworld taps and battle rolls pass through
  cleanly in both orders; each mod only transforms real results and
  calls the next handler first.
  
- **Table editors** (emerald-wild-spawns, catch-em-all) — their
  tables still drive rates, cooldowns, fishing windows and sprites,
  and anything they add is admitted by the line pipeline. Turn
  ECOLOGY off for byte-vanilla rolls.
  
- **Compatibilities:**
- 
- **Untamed-Advanced** — its visible sprites spawn ecology species
  through the shared seam, while roamers, Feebas, outbreaks, chains
  and repel keep running inside Untamed.
  
- **Wilds of Hoenn** — its visible spawns roll through the same
  wrapped engine call, so they spawn ecology species with zero
  integration code. Bump battles start locked to the shown mon;
  classic step encounters flow through the shared roll. Roaming
  legendaries pass through untouched — swapping one would make it
  vanish on touch instead of fighting you.

- **Dex expansions** (national_dex_gen3) — new species are found by
  the id scan with no changes here (slots to 4096 plus 9000–11000,
  rescanned on save load). Fairy stays inert — gen 3 has no fairy
  type. If two content mods ever claim the same slot, the conflict
  is excluded rather than rendering the wrong mon, and
  `PE.diag.reportText()` prints a paste-ready breakdown naming the
  owner of the fix.

## Tuning (for the tinkerers)

`src/poke-ecology/tests/print_pops.lua` runs the whole logic layer
against a fixture dex with no engine. Buckets, curves, terrains,
slot templates, modifiers, overrides, the legendary id set and rules
are all data files — edit them, re-run the harness, read the
per-bucket populations. Single-stage lines join from ordinals
13/14/16 (common/uncommon/rare). That harness is the oracle: if a
population looks wrong in game, print it there first.
