return function(mod)
  local PE = mod.exports.pokeEcology
  local O = {}
  local function typeMatch(stage, tname)
    if type(stage) ~= "table" then return false end
    local Types = nil
    pcall(function()
      local G = mod.exports.peTypeIds
      Types = G
    end)
    if type(Types) ~= "table" then return false end
    local id = Types[string.upper(tostring(tname or ""))]
    if id == nil then id = O.engineTypeId(tname) end
    if id == nil then return false end
    return stage.t1 == id or stage.t2 == id
  end
  local engineTypeCache = nil
  function O.engineTypeId(tname)
    if engineTypeCache == nil then
      engineTypeCache = {}
      local get = PE.engineTypeLoader or require
      local ok, Schemas = pcall(get, "src.mods.Schemas")
      local T = nil
      if ok and type(Schemas) == "table" then
        local gv = Schemas.gen3View
        if type(gv) == "table" and type(gv.TYPES) == "table" then
          T = gv.TYPES
        elseif type(Schemas.TYPES) == "table" then
          T = Schemas.TYPES
        end
      end
      if type(T) == "table" then
        for id, nm in pairs(T) do
          if type(nm) == "string" then
            local key = string.upper(nm)
            if engineTypeCache[key] == nil then
              local nid = math.floor(tonumber(id) or -1)
              if nid >= 0 then engineTypeCache[key] = nid end
            end
          end
        end
      end
    end
    return engineTypeCache[string.upper(tostring(tname or ""))]
  end
  function O.resetEngineTypeCache()
    engineTypeCache = nil
  end
  local function targetMatches(line, stage, target)
    if type(target) ~= "table" then return 1 end
    local matchStrength = 1
    if target.except_tag ~= nil then
      local stages = {}
      if stage ~= nil then stages = { stage } end
      if #stages == 0 and type(line) == "table" then
        for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
          for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
            stages[#stages + 1] = st
          end
        end
      end
      for _, st in ipairs(stages) do
        if type(st.tags) == "table" then
          for _, tag in ipairs(st.tags) do
            if tag == target.except_tag then return false end
          end
        end
      end
    end
    if target.tag ~= nil then
      local hit = false
      local stages = {}
      if stage ~= nil then stages = { stage } end
      if #stages == 0 and type(line) == "table" then
        for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
          for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
            stages[#stages + 1] = st
          end
        end
      end
      for _, st in ipairs(stages) do
        if type(st.tags) == "table" then
          for _, tag in ipairs(st.tags) do
            if tag == target.tag then hit = true break end
          end
        end
        if hit then break end
      end
      if not hit then return false end
    end
    if target.body_plan ~= nil then
      local plans = {}
      if stage ~= nil then plans = { stage.plan } end
      if #plans == 0 and type(line) == "table" then
        for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
          for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
            plans[#plans + 1] = st.plan
          end
        end
      end
      local hit = false
      for _, p in ipairs(plans) do if p == target.body_plan then hit = true break end end
      if not hit then return false end
    end
    if target.type ~= nil then
      local stages = {}
      if stage ~= nil then stages = { stage } end
      if #stages == 0 and type(line) == "table" then
        for _, b in ipairs(type(line.branches) == "table" and line.branches or {}) do
          for _, st in ipairs(type(b.stages) == "table" and b.stages or {}) do
            stages[#stages + 1] = st
          end
        end
      end
      local strength = nil
      for _, st in ipairs(stages) do
        if typeMatch(st, target.type) then
          if st.t1 == st.t2 then strength = 1 break end
          strength = 0.5
        end
      end
      if strength == nil then return false end
      if strength < matchStrength then matchStrength = strength end
    end
    if target.line_class ~= nil then
      if type(line) ~= "table" or line.class ~= target.line_class then return false end
    end
    return matchStrength
  end
  function O.rowMatches(row, line, stage, ctx)
    if type(row) ~= "table" or type(row.when) ~= "table" then return false end
    local w = row.when
    ctx = type(ctx) == "table" and ctx or {}
    if w.terrain ~= nil and ctx.terrain ~= w.terrain then return false end
    if w.except_terrain ~= nil and ctx.terrain == w.except_terrain then return false end
    if w.bucket ~= nil and ctx.bucket ~= w.bucket then return false end
    if w.weather ~= nil and ctx.weather ~= w.weather then return false end
    if w.biome ~= nil or w.area_tag ~= nil then
      local wants = {}
      for _, key in ipairs({ "biome", "area_tag" }) do
        local v = w[key]
        if type(v) == "table" then
          for _, s in ipairs(v) do wants[#wants + 1] = s end
        elseif v ~= nil then
          wants[#wants + 1] = v
        end
      end
      local hit = false
      if type(ctx.areaTags) == "table" then
        for _, tag in ipairs(ctx.areaTags) do
          for _, want in ipairs(wants) do
            if tag == want then hit = true break end
          end
          if hit then break end
        end
      end
      if not hit then return false end
    end
    if w.except_biome ~= nil or w.except_area_tag ~= nil then
      local bans = {}
      for _, key in ipairs({ "except_biome", "except_area_tag" }) do
        local v = w[key]
        if type(v) == "table" then
          for _, s in ipairs(v) do bans[#bans + 1] = s end
        elseif v ~= nil then
          bans[#bans + 1] = v
        end
      end
      if type(ctx.areaTags) == "table" then
        for _, tag in ipairs(ctx.areaTags) do
          for _, ban in ipairs(bans) do
            if tag == ban then return false end
          end
        end
      end
    end
    return targetMatches(line, stage, row.target)
  end
  function O.apply(slots, weather, modifiers, ctx)
    local mults = {}
    local banned = {}
    for i = 1, #slots do mults[i] = 1.0 end
    if type(modifiers) ~= "table" then return { mults = mults, banned = banned } end
    local rows = {}
    for _, m in ipairs(modifiers) do
      if type(m) == "table" and type(m.when) == "table" and m.when.weather ~= nil then
        rows[#rows + 1] = m
      end
    end
    table.sort(rows, function(a, b)
      return (tonumber(a.priority) or 0) < (tonumber(b.priority) or 0)
    end)
    local wctx = { terrain = ctx and ctx.terrain, bucket = ctx and ctx.bucket,
      weather = weather, areaTags = ctx and ctx.areaTags }
    for _, m in ipairs(rows) do
      for i, e in ipairs(slots) do
        local strength = (not banned[i]) and O.rowMatches(m, e.line, e.stage, wctx)
        if strength then
          if type(m.effect) == "table" then
            if m.effect.ban == true then
              banned[i] = true
            elseif tonumber(m.effect.mult) then
              mults[i] = mults[i] * tonumber(m.effect.mult) ^ strength
            end
          end
        end
      end
    end
    return { mults = mults, banned = banned }
  end
  PE.overlay = O
end
