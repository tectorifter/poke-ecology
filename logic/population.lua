return function(mod)
  local PE = mod.exports.pokeEcology
  local P = {}
  local function drawWithoutReplacement(rnd, cands, weights, n)
    local pool = {}
    local wpool = {}
    for i = 1, #cands do pool[i] = cands[i] wpool[i] = weights[i] end
    local out = {}
    for _ = 1, n do
      if #pool == 0 then break end
      local idx = PE.rng.pickWeighted(rnd, wpool)
      out[#out + 1] = pool[idx]
      table.remove(pool, idx)
      table.remove(wpool, idx)
    end
    return out
  end
  local function lineHasTag(line, tag)
    if type(line) ~= "table" then return false end
    for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
      for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
        if type(st.tags) == "table" then
          for _, t in ipairs(st.tags) do if t == tag then return true end end
        end
      end
    end
    return false
  end
  local function transientOnly(line)
    if type(line) ~= "table" then return false end
    local nat = nil
    pcall(function()
      if type(PE.source) == "table" and type(PE.source.dex) == "function" then
        local dex = PE.source.dex()
        if type(dex) == "table" then
          local d = dex[math.floor(tonumber(line.root) or 0)]
          if type(d) == "table" then nat = math.floor(tonumber(d.nat) or 0) end
        end
      end
    end)
    if nat == nil or nat <= 0 then nat = math.floor(tonumber(line.root) or 0) end
    local set = nil
    pcall(function()
      local ov = mod.exports.peOverrides
      if type(ov) == "table" then set = ov.transientOnly end
    end)
    return type(set) == "table" and set[nat] == true
  end
  local function ceilMultFor(line)
    local m = 1.0
    pcall(function()
      local ov = mod.exports.peOverrides
      local dx = PE.source.dex()
      if type(ov) ~= "table" or type(ov.ceil) ~= "table" then return end
      if type(dx) ~= "table" then return end
      local d = dx[math.floor(tonumber(line.root) or 0)]
      if type(d) ~= "table" then return end
      local nat = math.floor(tonumber(d.nat) or 0)
      if nat > 0 and tonumber(ov.ceil[nat]) then
        m = math.max(m, tonumber(ov.ceil[nat]))
      end
    end)
    return m
  end
  local function relaxSteps(rules)
    local steps = { {} }
    local hs = type(rules) == "table" and rules.relax_headroom_steps or nil
    local ss = type(rules) == "table" and rules.relax_single_steps or nil
    local bs = type(rules) == "table" and rules.relax_bst_steps or nil
    local n = 0
    if type(hs) == "table" and #hs > n then n = #hs end
    if type(ss) == "table" and #ss > n then n = #ss end
    if type(bs) == "table" and #bs > n then n = #bs end
    local h, s, b = 0, 0, 0
    for i = 1, n do
      if type(hs) == "table" and hs[i] ~= nil then h = h + (tonumber(hs[i]) or 0) end
      if type(ss) == "table" and ss[i] ~= nil then s = s + (tonumber(ss[i]) or 0) end
      if type(bs) == "table" and bs[i] ~= nil then b = b + (tonumber(bs[i]) or 0) end
      steps[#steps + 1] = { headroom = h, single = s, bst = b }
    end
    return steps
  end
  function P.build(key, lines, area, terrainName, terrain, template, band, rules, modifiers, ctx, fallback)
    local out = { slots = {}, template = template }
    if type(lines) ~= "table" or type(band) ~= "table" then return out end
    if type(template) ~= "table" or type(template.roles) ~= "table" then return out end
    local nSlots = #template.roles
    if nSlots < 1 then return out end
    local ordinal = area and math.floor(tonumber(area.ord) or 1) or 1
    local bucket = key and key.bucket or "morning"
    local saveSeed = key and tostring(key.seed or "0") or "0"
    local mapId = key and tostring(key.map or "") or ""
    local day = nil
    if type(rules) == "table" and rules.reseed_per_day == true then
      day = key and key.day or 0
    end
    local tkey = mapId .. "|" .. tostring(terrainName)
    local rseed = PE.rng.hash(saveSeed .. "|" .. tkey)
    local tseedStr = saveSeed .. "|" .. tkey .. "|" .. tostring(bucket)
    if day ~= nil then tseedStr = tseedStr .. "|" .. tostring(day) end
    local tseed = PE.rng.hash(tseedStr)
    local cands = {}
    local weights = {}
    local neutralW = {}
    local usedRelax = nil
    for _, step in ipairs(relaxSteps(rules)) do
      local cc = {}
      local ww = {}
      local nn = {}
      for _, line in ipairs(lines) do
        if PE.admit.admitted(line, ordinal, terrain, rules, step) then
          local scN = PE.score.score(line, band, bucket, ordinal, terrain, rules, modifiers, ctx, true)
          if scN > 0 then
            cc[#cc + 1] = line
            ww[#ww + 1] = PE.score.score(line, band, bucket, ordinal, terrain, rules, modifiers, ctx)
            nn[#nn + 1] = scN
          end
        end
      end
      if #cc > #cands then
        cands = cc
        weights = ww
        neutralW = nn
        usedRelax = step
      end
      if #cands >= nSlots then break end
    end
    local needRes = 0
    local needTra = 0
    for _, role in ipairs(template.roles) do
      if role == "common" then needRes = needRes + 1 else needTra = needTra + 1 end
    end
    local rrnd = PE.rng.stream(rseed)
    local trnd = PE.rng.stream(tseed)
    local resCands = {}
    local resW = {}
    for i, line in ipairs(cands) do
      if not lineHasTag(line, "nocturnal_only") and not transientOnly(line) then
        resCands[#resCands + 1] = line
        resW[#resW + 1] = neutralW[i]
      end
    end
    local nsum = 0
    for _, w in ipairs(resW) do nsum = nsum + (tonumber(w) or 0) end
    if nsum <= 0 then
      resCands = {}
      resW = {}
      for i, line in ipairs(cands) do
        if not lineHasTag(line, "nocturnal_only") and not transientOnly(line) then
          resCands[#resCands + 1] = line
          resW[#resW + 1] = weights[i]
        end
      end
    end
    local resLines = drawWithoutReplacement(rrnd, resCands, resW, math.min(needRes, #resCands))
    local rest = {}
    local restW = {}
    for i, line in ipairs(cands) do
      local taken = false
      for _, d in ipairs(resLines) do if d == line then taken = true break end end
      if not taken then rest[#rest + 1] = line restW[#restW + 1] = weights[i] end
    end
    local traLines = drawWithoutReplacement(trnd, rest, restW, math.min(needTra, #rest))
    table.sort(resLines, function(a, b)
      return (tonumber(a.power) or 0) < (tonumber(b.power) or 0)
    end)
    table.sort(traLines, function(a, b)
      return (tonumber(a.power) or 0) < (tonumber(b.power) or 0)
    end)
    local maxRedraws = 8
    if type(rules) == "table" then maxRedraws = math.floor(tonumber(rules.max_redraws) or 8) end
    local rolePos = { common = 0.25, uncommon = 0.6, rare = 0.9 }
    if type(rules) == "table" and type(rules.role_pos) == "table" then
      for k, v in pairs(rules.role_pos) do
        if type(v) == "number" then rolePos[k] = v end
      end
    end
    local jitterAmt = 0.1
    if type(rules) == "table" then jitterAmt = tonumber(rules.jitter) or jitterAmt end
    local ceilBase = band.bst
    if type(rules) == "table" then ceilBase = band.bst * (tonumber(rules.stage_ceiling) or 1.0) end
    local entries = {}
    local function makeEntry(line, rnd, role)
      local bcount = #(type(line.branches) == "table" and line.branches or {})
      if bcount < 1 then return nil end
      local bi = 1 + math.floor(rnd() * bcount)
      if bi > bcount then bi = bcount end
      local branch = line.branches[bi]
      local jit = (rnd() * 2 - 1) * jitterAmt
      local level = PE.stage.resolveLevel(band, rolePos[role] or 0.5, jit, line.power, rules)
      local st = PE.stage.resolveStage(line, branch, level, ceilBase * ceilMultFor(line), terrain)
      if st == nil then return nil end
      local floorLv = math.floor(tonumber(st.threshold) or 1)
      if level < floorLv then level = floorLv end
      return { species = st.species, level = level, line = line, hi = band.hi,
        stage = st, role = role, power = tonumber(line.power) or 0 }
    end
    local ri, ti = 1, 1
    for _, role in ipairs(template.roles) do
      local line = nil
      local rnd = trnd
      if role == "common" then
        line = resLines[ri]
        if line ~= nil then ri = ri + 1 end
        rnd = rrnd
      else
        line = traLines[ti]
        if line ~= nil then ti = ti + 1 end
      end
      if line ~= nil then
        local e = nil
        for _ = 1, maxRedraws + 1 do
          e = makeEntry(line, rnd, role)
          if e ~= nil then break end
        end
        if e ~= nil then entries[#entries + 1] = e end
      end
    end
    local commons = {}
    local others = {}
    for _, e in ipairs(entries) do
      if e.role == "common" then commons[#commons + 1] = e else others[#others + 1] = e end
    end
    local fi = 1
    for _, role in ipairs(template.roles) do
      local e = nil
      if role == "common" then
        e = commons[1]
        if e ~= nil then table.remove(commons, 1) end
      else
        e = others[1]
        if e ~= nil then table.remove(others, 1) end
      end
      if e == nil and type(fallback) == "table" and #fallback > 0 then
        e = fallback[fi]
        fi = fi + 1
        if fi > #fallback then fi = 1 end
      end
      if e ~= nil then
        out.slots[#out.slots + 1] = { species = e.species, level = e.level,
          line = e.line, stage = e.stage, role = role, power = e.power }
      end
    end
    out.relax = usedRelax
    return out
  end
  PE.population = P
end
