return function(mod)
  local PE = mod.exports.pokeEcology
  local A = {}
  local function hasTag(stage, tag)
    if type(stage) ~= "table" or type(stage.tags) ~= "table" then return false end
    for _, t in ipairs(stage.tags) do if t == tag then return true end end
    return false
  end
  local function planAllowed(plans, plan)
    if type(plans) ~= "table" then return true end
    for _, p in ipairs(plans) do if p == plan then return true end end
    return false
  end
  function A.stageOk(stage, terrain)
    if type(stage) ~= "table" then return false end
    if type(terrain) ~= "table" then return true end
    local req = terrain.requires
    if type(req) == "table" then
      for _, tag in ipairs(req) do
        if not hasTag(stage, tag) then return false end
      end
    end
    if terrain.land_ban == true then
      local aquatic = hasTag(stage, "aquatic")
      if aquatic then
        local aerial = hasTag(stage, "aerial")
        local plan = stage.plan
        if not aerial and plan ~= "biped" and plan ~= "quadruped" then return false end
      end
    end
    if not planAllowed(terrain.plans, stage.plan) then return false end
    return true
  end
  local function natOf(id)
    id = math.floor(tonumber(id) or 0)
    local nat = nil
    pcall(function()
      if type(PE.source) == "table" and type(PE.source.dex) == "function" then
        local dex = PE.source.dex()
        if type(dex) == "table" then
          local d = dex[id]
          if type(d) == "table" then nat = math.floor(tonumber(d.nat) or 0) end
        end
      end
    end)
    if nat ~= nil and nat > 0 then return nat end
    return id
  end
  function A.legendary(line)
    if type(line) ~= "table" then return false end
    local skip = true
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        skip = mod.options:get("no_legendaries")
      end
    end)
    if skip == nil then skip = true end
    if not skip then return false end
    local leg = mod.exports.peLegendaries
    if type(leg) ~= "table" then leg = {} end
    local dexLeg = mod.exports.peDexLegendaries
    if type(dexLeg) ~= "table" then dexLeg = {} end
    if leg[natOf(line.root)] or dexLeg[math.floor(tonumber(line.root) or 0)] then return true end
    for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
      for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
        local sp = math.floor(tonumber(st.species) or 0)
        if leg[natOf(sp)] or dexLeg[sp] then return true end
      end
    end
    return false
  end
  function A.blocked(id)
    local set = mod.exports.peBlockedForms
    if type(set) ~= "table" then return false end
    return set[math.floor(tonumber(id) or 0)] == true
  end
  local GEN_HI = { 151, 251, 386, 493, 649, 721, 809, 905, 1025 }
  function A.genOfNat(nat)
    nat = math.floor(tonumber(nat) or 0)
    if nat < 1 then return 0 end
    for g, hi in ipairs(GEN_HI) do
      if nat <= hi then return g end
    end
    return 0
  end
  local function genOn(g)
    if g < 1 or g > 9 then return true end
    local v = nil
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        v = mod.options:get("gen" .. g)
      end
    end)
    if v == nil then return true end
    return v ~= false
  end
  function A.stageGenOk(species)
    local nat = nil
    pcall(function()
      local dex = nil
      if type(PE.source) == "table" and type(PE.source.dex) == "function" then
        dex = PE.source.dex()
      end
      if type(dex) == "table" then
        local d = dex[math.floor(tonumber(species) or 0)]
        if type(d) == "table" then nat = d.nat end
      end
    end)
    nat = math.floor(tonumber(nat) or 0)
    if nat <= 0 then return true end
    return genOn(A.genOfNat(nat))
  end
  function A.stageSpawnOk(stage, terrain)
    if not A.stageOk(stage, terrain) then return false end
    return A.stageGenOk(stage.species)
  end
  function A.admitted(line, ordinal, terrain, rules, relax)
    if type(line) ~= "table" then return false end
    if A.legendary(line) then return false end
    ordinal = math.floor(tonumber(ordinal) or 1)
    local band = nil
    if type(PE.bands) == "table" then
      local curves = mod.exports.peCurves
      band = PE.bands.band(curves, ordinal, terrain)
    end
    local hh = 0
    local bb = 0
    if type(relax) == "table" then
      hh = tonumber(relax.headroom) or 0
      bb = tonumber(relax.bst) or 0
    end
    if (tonumber(line.power) or 0) > (tonumber(band.cap) or 950) * (1 + hh + bb) then return false end
    if line.class == "single" then
      local minOrd = 1
      if type(rules) == "table" and type(rules.single_min_ordinal) == "table" then
        minOrd = math.floor(tonumber(rules.single_min_ordinal[line.rarity]) or 1)
      end
      if type(relax) == "table" and tonumber(relax.single) then
        minOrd = minOrd - math.floor(tonumber(relax.single))
      end
      if minOrd < 1 then minOrd = 1 end
      if ordinal < minOrd then return false end
    end
    local anyStage = false
    for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
      for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
        if A.stageSpawnOk(st, terrain) then anyStage = true break end
      end
      if anyStage then break end
    end
    if not anyStage then return false end
    return true
  end
  function A.stageWeight(line, ordinal, rules)
    if type(line) ~= "table" or line.class ~= "single" then return 1.0 end
    ordinal = math.floor(tonumber(ordinal) or 1)
    local ramp = type(rules) == "table" and rules.single_weight or nil
    local from = 1
    local to = 10
    local lo = 0.25
    local hi = 1.0
    if type(ramp) == "table" then
      from = math.floor(tonumber(ramp.from) or from)
      to = math.floor(tonumber(ramp.to) or to)
      lo = tonumber(ramp.lo) or lo
      hi = tonumber(ramp.hi) or hi
    end
    if to <= from then return hi end
    local f = (ordinal - from) / (to - from)
    if f < 0 then f = 0 end
    if f > 1 then f = 1 end
    return lo + (hi - lo) * f
  end
  PE.admit = A
end
