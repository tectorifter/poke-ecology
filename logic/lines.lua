return function(mod)
  local PE = mod.exports.pokeEcology
  local L = {}
  local TYPE_TAGS = {
    [2] = { "aerial" },
    [3] = { "marsh" },
    [4] = { "rocky", "cave", "arid" },
    [5] = { "rocky", "cave", "arid" },
    [6] = { "forest", "meadow" },
    [7] = { "haunted" },
    [10] = { "arid" },
    [11] = { "aquatic" },
    [12] = { "meadow", "forest" },
    [15] = { "arctic" },
    [17] = {},
  }
  local LEVEL_METHODS = { [4] = true, [8] = true, [9] = true, [10] = true,
    [11] = true, [12] = true, [13] = true }
  local function tagsFor(t1, t2)
    local seen = {}
    local out = {}
    for _, t in ipairs({ t1, t2 }) do
      local tt = TYPE_TAGS[math.floor(tonumber(t) or 0)]
      if type(tt) == "table" then
        for _, tag in ipairs(tt) do
          if not seen[tag] then seen[tag] = true out[#out + 1] = tag end
        end
      end
    end
    return out
  end
  local function okey(dex, id)
    id = math.floor(tonumber(id) or 0)
    if type(dex) == "table" then
      local d = dex[id]
      if type(d) == "table" then
        local nat = math.floor(tonumber(d.nat) or 0)
        if nat > 0 then return nat end
      end
    end
    return id
  end
  local function planFor(t1, t2)
    t1 = math.floor(tonumber(t1) or 0)
    t2 = math.floor(tonumber(t2) or 0)
    if t1 == 2 or t2 == 2 then return "aerial" end
    if t1 == 11 or t2 == 11 then
      local other = t1 == 11 and t2 or t1
      if other == 4 or other == 12 or other == 1 or other == 14 or other == 6 then
        return "biped"
      end
      return "fish"
    end
    return "terrestrial"
  end
  local function activityFor(t1, t2)
    t1 = math.floor(tonumber(t1) or 0)
    t2 = math.floor(tonumber(t2) or 0)
    if t1 == 7 or t2 == 7 or t1 == 17 or t2 == 17 then return "nocturnal" end
    return "diurnal"
  end
  local function rarityFor(rules, overrides, key, catch, power, uniformCatch)
    if type(overrides) == "table" and type(overrides.rarity) == "table" then
      local r = overrides.rarity[key]
      if r == "common" or r == "uncommon" or r == "rare" then return r end
    end
    if uniformCatch then
      local cut = type(rules) == "table" and rules.rarity_power or nil
      local rp = type(cut) == "table" and math.floor(tonumber(cut.rare) or 580) or 580
      local up = type(cut) == "table" and math.floor(tonumber(cut.uncommon) or 430) or 430
      power = math.floor(tonumber(power) or 0)
      if power >= rp then return "rare" end
      if power >= up then return "uncommon" end
      return "common"
    end
    local cut = type(rules) == "table" and rules.rarity_catch or nil
    local rc = type(cut) == "table" and math.floor(tonumber(cut.rare) or 10) or 10
    local uc = type(cut) == "table" and math.floor(tonumber(cut.uncommon) or 45) or 45
    local c = math.floor(tonumber(catch) or 255)
    if c <= rc then return "rare" end
    if c <= uc then return "uncommon" end
    return "common"
  end
  local function edgeThreshold(rules, method, param, stageIndex)
    method = math.floor(tonumber(method) or 0)
    param = math.floor(tonumber(param) or 0)
    if LEVEL_METHODS[method] then
      if param < 2 then param = 2 end
      return param
    end
    local nl = type(rules) == "table" and rules.nonlevel_threshold or nil
    local t = type(nl) == "table" and tonumber(nl[method]) or nil
    if t ~= nil and t >= 2 then return math.floor(t) end
    local step = 12
    if type(rules) == "table" then step = math.floor(tonumber(rules.default_step) or 12) end
    if step < 1 then step = 1 end
    return math.max(2, math.floor(tonumber(stageIndex) or 1) * step)
  end
  local function stageOf(dex, overrides, id, threshold)
    local d = dex[id]
    if type(d) ~= "table" then return nil end
    local bst = math.floor(tonumber(d.bst) or 0)
    if bst < 1 then return nil end
    local t1 = math.floor(tonumber(d.t1) or 0)
    local t2 = math.floor(tonumber(d.t2) or t1)
    local tags = tagsFor(t1, t2)
    if type(overrides) == "table" and type(overrides.addTag) == "table" then
      local extra = overrides.addTag[okey(dex, id)]
      if type(extra) == "table" then
        local seen = {}
        for _, tag in ipairs(tags) do seen[tag] = true end
        for _, tag in ipairs(extra) do
          if type(tag) == "string" and not seen[tag] then
            seen[tag] = true
            tags[#tags + 1] = tag
          end
        end
      end
    end
    local plan = planFor(t1, t2)
    if type(overrides) == "table" and type(overrides.plan) == "table"
        and type(overrides.plan[okey(dex, id)]) == "string" then
      plan = overrides.plan[okey(dex, id)]
    end
    local activity = activityFor(t1, t2)
    if type(overrides) == "table" and type(overrides.activity) == "table"
        and type(overrides.activity[okey(dex, id)]) == "string" then
      activity = overrides.activity[okey(dex, id)]
    end
    return {
      species = id,
      threshold = math.floor(tonumber(threshold) or 1),
      bst = bst,
      t1 = t1,
      t2 = t2,
      tags = tags,
      plan = plan,
      activity = activity,
    }
  end
  function L.build(dex, rules, overrides)
    local lines = {}
    if type(dex) ~= "table" then return lines end
    local targeted = {}
    local ids = {}
    local catchCounts = {}
    local catchTotal = 0
    for id, d in pairs(dex) do
      id = math.floor(tonumber(id) or 0)
      if id > 0 and type(d) == "table" and (tonumber(d.bst) or 0) > 0 then
        ids[#ids + 1] = id
        local c = math.floor(tonumber(d.catch) or 255)
        catchCounts[c] = (catchCounts[c] or 0) + 1
        catchTotal = catchTotal + 1
        local evos = type(d.evos) == "table" and d.evos or {}
        for _, e in ipairs(evos) do
          local tgt = math.floor(tonumber(type(e) == "table" and (e.target or e[3])) or 0)
          if tgt > 0 and type(dex[tgt]) == "table" then targeted[tgt] = true end
        end
      end
    end
    local uniformCatch = false
    for _, n in pairs(catchCounts) do
      if catchTotal > 0 and n / catchTotal >= 0.9 then uniformCatch = true break end
    end
    local excluded = {}
    if type(rules) == "table" and type(rules.excluded_wild_methods) == "table" then
      for _, m in ipairs(rules.excluded_wild_methods) do
        excluded[math.floor(tonumber(m) or 0)] = true
      end
    end
    table.sort(ids)
    for _, root in ipairs(ids) do
      if not targeted[root] then
        local branches = {}
        local function walk(node, path, depth)
          if depth > 8 or #branches >= 64 then return end
          for _, n in ipairs(path) do if n == node then return end end
          path[#path + 1] = node
          local d = dex[node]
          local evos = type(d) == "table" and type(d.evos) == "table" and d.evos or {}
          local kids = {}
          for _, e in ipairs(evos) do
            if type(e) == "table" then
              local method = math.floor(tonumber(e.method or e[1]) or 0)
              local tgt = math.floor(tonumber(e.target or e[3]) or 0)
              if tgt > 0 and type(dex[tgt]) == "table" and not excluded[method] then
                kids[#kids + 1] = { target = tgt,
                  method = method,
                  param = tonumber(e.param or e[2]) or 0 }
              end
            end
          end
          if #kids == 0 then
            local stages = {}
            local ok = true
            local prevTh = 0
            for i, sid in ipairs(path) do
              local th = 1
              if i > 1 then
                local prev = dex[path[i - 1]]
                local pevos = type(prev) == "table" and type(prev.evos) == "table" and prev.evos or {}
                for _, e in ipairs(pevos) do
                  if type(e) == "table" and math.floor(tonumber(e.target or e[3]) or 0) == sid then
                    th = edgeThreshold(rules, e.method or e[1], e.param or e[2], i)
                    break
                  end
                end
              end
              if th <= prevTh then th = prevTh + 1 end
              prevTh = th
              local st = stageOf(dex, overrides, sid, th)
              if st == nil then ok = false break end
              stages[#stages + 1] = st
            end
            if ok and #stages > 0 then branches[#branches + 1] = { stages = stages } end
          else
            for _, k in ipairs(kids) do walk(k.target, path, depth + 1) end
          end
          path[#path] = nil
        end
        walk(root, {}, 0)
        if #branches > 0 then
          local power = 0
          local tagSet = {}
          local tagList = {}
          for _, b in ipairs(branches) do
            local fin = b.stages[#b.stages]
            if fin.bst > power then power = fin.bst end
            for _, st in ipairs(b.stages) do
              for _, tag in ipairs(st.tags) do
                if not tagSet[tag] then tagSet[tag] = true tagList[#tagList + 1] = tag end
              end
            end
          end
          local first = branches[1].stages[1]
          local d0 = dex[root]
          lines[#lines + 1] = {
            root = root,
            class = (#branches == 1 and #branches[1].stages == 1) and "single" or "multi",
            power = power,
            rarity = rarityFor(rules, overrides, okey(dex, root),
              type(d0) == "table" and d0.catch or nil, power, uniformCatch),
            firstSpecies = first.species,
            branches = branches,
            tags = tagList,
          }
        end
      end
    end
    return lines
  end
  PE.lines = L
end
