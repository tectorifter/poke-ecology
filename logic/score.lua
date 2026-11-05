return function(mod)
  local PE = mod.exports.pokeEcology
  local S = {}
  local function lineRarityWeight(rules, rarity)
    local w = 1.0
    if type(rules) == "table" and type(rules.rarity_weight) == "table" then
      w = tonumber(rules.rarity_weight[rarity]) or w
    end
    return w
  end
  function S.habitatFit(line, terrain)
    if type(line) ~= "table" then return 0 end
    local total = 0
    local passing = 0
    for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
      for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
        total = total + 1
        if PE.admit.stageOk(st, terrain) then passing = passing + 1 end
      end
    end
    if total < 1 then return 0 end
    return passing / total
  end
  function S.bstProximity(line, band)
    local power = tonumber(line and line.power) or 0
    local bst = band and tonumber(band.bst) or 200
    if bst < 1 then bst = 1 end
    local d = math.abs(power - bst) / bst
    return 1 / (1 + d * d * 4)
  end
  function S.timeAffinity(line, bucket)
    local noct = 0
    local total = 0
    for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
      for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
        total = total + 1
        if st.activity == "nocturnal" then noct = noct + 1 end
      end
    end
    local rules = mod.exports.peRules
    local mismatch = 0.35
    if type(rules) == "table" then mismatch = tonumber(rules.time_mismatch) or mismatch end
    if total < 1 then return 1 end
    local nightish = bucket == "night" or bucket == "dawn"
    if noct == total then
      if nightish then return 1 end
      return mismatch
    end
    if noct == 0 then
      if nightish then return mismatch end
      return 1
    end
    return 0.6 + 0.4 * (noct / total)
  end
  function S.staticMult(line, ctx, modifiers, skipBucket)
    local mult = 1.0
    local banned = false
    if type(modifiers) ~= "table" then return mult, banned end
    local rows = {}
    for _, m in ipairs(modifiers) do
      if type(m) == "table" and type(m.when) == "table" then
        local w = m.when
        local isStatic = w.terrain ~= nil or w.biome ~= nil or w.area_tag ~= nil or w.bucket ~= nil
          or w.except_terrain ~= nil or w.except_biome ~= nil or w.except_area_tag ~= nil
        local weatherOnly = w.weather ~= nil and w.terrain == nil
          and w.bucket == nil and w.biome == nil and w.area_tag == nil
        if isStatic and not weatherOnly then rows[#rows + 1] = m end
      end
    end
    table.sort(rows, function(a, b)
      return (tonumber(a.priority) or 0) < (tonumber(b.priority) or 0)
    end)
    for _, m in ipairs(rows) do
      local skip = skipBucket and type(m.when) == "table" and m.when.bucket ~= nil
      if not skip then
        local strength = PE.overlay.rowMatches(m, line, nil, ctx)
        if strength then
          if type(m.effect) == "table" then
            if m.effect.ban == true then
              banned = true
            elseif tonumber(m.effect.mult) then
              mult = mult * tonumber(m.effect.mult) ^ strength
            end
          end
        end
      end
    end
    return mult, banned
  end
  function S.score(line, band, bucket, ordinal, terrain, rules, modifiers, ctx, neutral)
    local fit = S.habitatFit(line, terrain)
    if fit <= 0 then return 0 end
    local w = fit
    w = w * S.bstProximity(line, band)
    w = w * PE.admit.stageWeight(line, ordinal, rules)
    w = w * lineRarityWeight(rules, line.rarity)
    local mult, banned
    if neutral then
      mult, banned = S.staticMult(line, ctx, modifiers, true)
    else
      w = w * S.timeAffinity(line, bucket)
      mult, banned = S.staticMult(line, ctx, modifiers, false)
    end
    if banned then return 0 end
    w = w * mult
    return w
  end
  PE.score = S
end
