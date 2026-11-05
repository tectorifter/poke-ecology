return {
  land = {
    requires = {},
    plans = { "terrestrial", "biped", "quadruped", "serpentine", "aerial" },
    land_ban = true,
    level_off = 0,
    bst_off = 0,
  },
  water = {
    requires = { "aquatic" },
    plans = { "fish", "serpentine", "swimmer", "biped", "quadruped", "aerial" },
    level_off = 0,
    bst_off = 0,
  },
  fishing = {
    requires = { "aquatic" },
    plans = { "fish", "serpentine" },
    level_off = -1,
    bst_off = -20,
  },
  rock_smash = {
    requires = { "rocky" },
    plans = { "terrestrial", "biped", "quadruped", "serpentine" },
    level_off = 2,
    bst_off = 40,
  },
  cave = {
    requires = { "cave" },
    plans = { "terrestrial", "biped", "quadruped", "serpentine", "aerial" },
    level_off = 1,
    bst_off = 20,
  },
  sand = {
    requires = { "arid" },
    plans = { "terrestrial", "biped", "quadruped", "serpentine" },
    level_off = 0,
    bst_off = 0,
  },
  dive = {
    requires = { "aquatic", "deep" },
    plans = { "fish", "serpentine", "swimmer" },
    level_off = 3,
    bst_off = 60,
  },
}
