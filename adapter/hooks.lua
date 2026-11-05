return function(mod)
  local PE = mod.exports.pokeEcology
  local H = {}
  local installed = false
  local seedCache = nil
  local drawCount = 0
  local popCache = {}
  local POP_CACHE_MAX = 6
  local function popGet(ck)
    for i, e in ipairs(popCache) do
      if e.key == ck and type(e.slots) == "table" then
        if i > 1 then
          table.remove(popCache, i)
          table.insert(popCache, 1, e)
        end
        return e
      end
    end
    return nil
  end
  local function popPut(entry)
    table.insert(popCache, 1, entry)
    while #popCache > POP_CACHE_MAX do table.remove(popCache) end
  end
  local logged = false
  local function on()
    local v = true
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        v = mod.options:get("ecology")
      end
    end)
    if v == nil then return true end
    return v ~= false
  end
  local function rules()
    return mod.exports.peRules
  end
  local function seed()
    if seedCache == nil then seedCache = PE.context.seed() end
    return seedCache
  end
  local function rnd01()
    local Rng = nil
    pcall(function() Rng = require("src.core.game3.rng") end)
    if type(Rng) == "table" then
      if type(Rng.Random32) == "function" then
        local r = 0
        pcall(function() r = Rng.Random32() end)
        return (math.floor(tonumber(r) or 0) % 4294967296) / 4294967296
      end
      if type(Rng.Random) == "function" then
        local r = 0
        pcall(function() r = Rng.Random() end)
        return (math.floor(tonumber(r) or 0) % 65536) / 65536
      end
    end
    drawCount = drawCount + 1
    return (PE.rng.hash(seed() .. "#" .. tostring(drawCount)) % 1000000) / 1000000
  end
  local function vanillaBand(mapId)
    local lo, hi = nil, nil
    pcall(function()
      local E = require("src.core.game3.encounters")
      if type(E) ~= "table" or type(E.tableFor) ~= "function" then return end
      local t = E.tableFor(mapId)
      if type(t) ~= "table" then return end
      for _, k in ipairs({ "land", "grass", "water", "fishing", "rocks" }) do
        local a = t[k]
        if type(a) == "table" and type(a.slots) == "table" then
          for _, s in ipairs(a.slots) do
            if type(s) == "table" then
              local l = math.floor(tonumber(s.minLevel or s.level or s[2]) or 0)
              local h = math.floor(tonumber(s.maxLevel or s.level or s[2]) or 0)
              if l > 0 and h > 0 then
                if lo == nil or l < lo then lo = l end
                if hi == nil or h > hi then hi = h end
              end
            end
          end
        end
      end
    end)
    return lo, hi
  end
  local function resolveArea(mapId)
    local areas = mod.exports.peAreas
    local key = tostring(mapId or "")
    if type(areas) == "table" and type(areas[key]) == "table" then
      local a = areas[key]
      return { ord = math.floor(tonumber(a.ord) or 1), tags = a.tags }, key
    end
    local lo, hi = vanillaBand(mapId)
    local ord = 1
    if lo ~= nil and hi ~= nil then
      local mid = math.floor((lo + hi) / 2)
      local curves = mod.exports.peCurves
      local best = 1
      local bestD = nil
      if type(curves) == "table" then
        for _, r in ipairs(curves) do
          if type(r) == "table" then
            local d = math.abs(mid - math.floor(((tonumber(r.lo) or 0) + (tonumber(r.hi) or 0)) / 2))
            if bestD == nil or d < bestD then bestD = d best = math.floor(tonumber(r.o) or 1) end
          end
        end
      end
      ord = best
    end
    return { ord = ord, tags = {} }, key
  end
  local function templateFor(terrainName, rod)
    local slots = mod.exports.peSlots
    if type(slots) ~= "table" then return nil end
    if terrainName == "fishing" then
      local r = math.floor(tonumber(rod) or 0)
      if r == 2 then return slots.fishing_super end
      if r == 1 then return slots.fishing_good end
      return slots.fishing_old
    end
    if terrainName == "water" then return slots.water end
    if terrainName == "rock_smash" or terrainName == "rocks" then return slots.rocks end
    if terrainName == "cave" or terrainName == "sand" or terrainName == "dive"
        or terrainName == "land" then
      return slots.land
    end
    return slots.land
  end
  local function landAs(area, terrainName)
    if terrainName == "land" then
      if type(area) == "table" then
        if type(area.land_as) == "string" and area.land_as ~= "" then
          return area.land_as
        end
        if type(area.tags) == "table" then
          for _, tag in ipairs(area.tags) do
            if tag == "cave" then return "cave" end
          end
          for _, tag in ipairs(area.tags) do
            if tag == "sand" or tag == "arid" then return "sand" end
          end
          for _, tag in ipairs(area.tags) do
            if tag == "deep" then return "dive" end
          end
        end
      end
      return "land"
    end
    if terrainName == "water" then
      if type(area) == "table" and type(area.tags) == "table" then
        for _, tag in ipairs(area.tags) do
          if tag == "deep" then return "dive" end
        end
      end
    end
    return terrainName
  end
  local ROD_BAND = { [0] = { 0, 0 }, [1] = { 2, 30 }, [2] = { 4, 60 } }
  local function buildPop(mapId, terrainName, rod, bucket, day)
    local area = resolveArea(mapId)
    local effName = landAs(area, terrainName)
    local terrains = mod.exports.peTerrains
    local tdef = type(terrains) == "table" and terrains[effName] or nil
    if type(tdef) ~= "table" then tdef = terrains and terrains.land or {} end
    if effName == "fishing" then
      local bonus = ROD_BAND[math.floor(tonumber(rod) or 0)] or ROD_BAND[0]
      tdef = { requires = tdef.requires, plans = tdef.plans,
        land_ban = tdef.land_ban,
        level_off = (tonumber(tdef.level_off) or 0) + bonus[1],
        bst_off = (tonumber(tdef.bst_off) or 0) + bonus[2] }
    end
    local band = PE.bands.band(mod.exports.peCurves, area.ord, tdef)
    local template = templateFor(terrainName, rod)
    if template == nil then return nil end
    local lines = PE.source.lines()
    local key = { map = tostring(mapId or ""), terrain = effName,
      bucket = bucket, day = day, seed = seed() }
    local ctx = { terrain = effName, bucket = bucket, areaTags = area.tags }
    local pop = PE.population.build(key, lines, area, effName, tdef,
      template, band, rules(), mod.exports.peModifiers, ctx, nil)
    if type(pop) ~= "table" or type(pop.slots) ~= "table" then return nil end
    if #pop.slots > 0 then return pop end
    local fb = nil
    pcall(function()
      local areas = mod.exports.peAreas
      if type(areas) ~= "table" then return end
      local bestKey, bestOrd = nil, nil
      for k, a in pairs(areas) do
        if type(a) == "table" and k ~= mapId then
          local o = math.floor(tonumber(a.ord) or 0)
          if o < area.ord and (bestOrd == nil or o > bestOrd) then
            bestOrd = o
            bestKey = k
          end
        end
      end
      if bestKey ~= nil then
        local fa = resolveArea(bestKey)
        local feff = landAs(fa, terrainName)
        local ftdef = type(terrains) == "table" and terrains[feff] or nil
        if type(ftdef) ~= "table" then ftdef = terrains and terrains.land or {} end
        local fband = PE.bands.band(mod.exports.peCurves, fa.ord, ftdef)
        local fctx = { terrain = feff, bucket = bucket, areaTags = fa.tags }
        local fpop = PE.population.build(
          { map = bestKey, terrain = feff, bucket = bucket, day = day, seed = seed() },
          lines, fa, feff, ftdef, template, fband,
          rules(), mod.exports.peModifiers, fctx, nil)
        if type(fpop) == "table" and type(fpop.slots) == "table" and #fpop.slots > 0 then
          fb = fpop.slots
        end
      end
    end)
    if type(fb) ~= "table" then return pop end
    pop = PE.population.build(key, lines, area, effName, tdef,
      template, band, rules(), mod.exports.peModifiers, ctx, fb)
    if type(pop) ~= "table" or type(pop.slots) ~= "table" then return nil end
    return pop
  end
  local function genMask()
    local parts = {}
    local ok = false
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        for g = 1, 9 do
          local v = mod.options:get("gen" .. g)
          parts[#parts + 1] = (v == nil or v ~= false) and "1" or "0"
        end
        ok = true
      end
    end)
    if not ok or #parts ~= 9 then return "111111111" end
    return table.concat(parts)
  end
  local function dexSig()
    local sig = nil
    pcall(function()
      if type(PE.source) == "table" and type(PE.source.sig) == "function" then
        sig = PE.source.sig()
      end
    end)
    return tostring(sig or "nosig")
  end
  local function cacheKey(mapId, terrainName, rod, bucket, day, noLeg, gens)
    return tostring(mapId) .. "|" .. tostring(terrainName) .. "|" .. tostring(rod or 0)
      .. "|" .. tostring(bucket) .. "|" .. tostring(day or 0) .. "|" .. seed()
      .. "|" .. (noLeg and "noleg" or "leg") .. "|" .. tostring(gens or "111111111")
      .. "|" .. dexSig()
  end
  local function getPop(mapId, terrainName, rod)
    local hour, day = PE.context.clock()
    local bucket = PE.context.bucket(hour)
    local noLeg = true
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        noLeg = mod.options:get("no_legendaries")
      end
    end)
    if noLeg == nil then noLeg = true end
    local gens = genMask()
    local ck = cacheKey(mapId, terrainName, rod, bucket, day, noLeg, gens)
    local hit = popGet(ck)
    if hit ~= nil then return hit end
    local pop = nil
    pcall(function() pop = buildPop(mapId, terrainName, rod, bucket, day) end)
    if pop == nil or type(pop.slots) ~= "table" or #pop.slots == 0 then return nil end
    local weights = {}
    local tpl = pop.template
    if type(tpl) == "table" and type(tpl.weights) == "table" then weights = tpl.weights end
    local entry = { key = ck, slots = pop.slots, weights = weights, template = tpl,
      bucket = bucket, terrain = terrainName, map = mapId }
    popPut(entry)
    return entry
  end
  function H.popSlots(mapId, terrainName, rod)
    local pop = nil
    pcall(function() pop = getPop(mapId, terrainName, rod) end)
    if pop == nil or type(pop.slots) ~= "table" or #pop.slots == 0 then return nil end
    return pop.slots
  end
  local function ctxFor(mapId, terrainName, bucket)
    local area = resolveArea(mapId)
    return { terrain = terrainName, bucket = bucket, areaTags = area.tags }
  end
  function H.substitute(enc, mapId, terrainName, rod)
    if enc == nil then return nil end
    if enc.roamer then return enc end
    if not on() then return enc end
    local res = enc
    pcall(function()
      local pop = getPop(mapId, terrainName, rod)
      if pop == nil then return end
      local hour = PE.context.clock()
      local bucket = PE.context.bucket(hour)
      local weather = PE.context.weather()
      local ov = PE.overlay.apply(pop.slots, weather, mod.exports.peModifiers,
        ctxFor(mapId, terrainName, bucket))
      local entry = PE.roll.pick(pop.slots, pop.weights, ov, rnd01)
      if type(entry) ~= "table" then return end
      local species = math.floor(tonumber(entry.species) or 0)
      local level = math.floor(tonumber(entry.level) or 0)
      local r = rnd01()
      if r < 0.25 then level = level - 1 elseif r > 0.75 then level = level + 1 end
      local floorLv = 1
      if type(entry.stage) == "table" then
        floorLv = math.max(1, math.floor(tonumber(entry.stage.threshold) or 1))
      end
      if level < floorLv then level = floorLv end
      local hiLv = math.floor(tonumber(entry.hi) or (entry.level + 1))
      if level > hiLv then level = hiLv end
      if species < 1 or level < 1 then return end
      if PE.context.repelBlocks(level) then
        res = nil
        return
      end
      enc.species = species
      enc.speciesId = species
      enc.level = level
      res = enc
    end)
    return res
  end
  local function terrainOfHook(ctx)
    if type(ctx) == "table" and type(ctx.terrain) == "string" then
      if ctx.terrain == "water" then return "water" end
      return "land"
    end
    return nil
  end
  local function install()
    pcall(function()
      if PE.urtc ~= nil and type(PE.urtc.ensure) == "function" then PE.urtc.ensure() end
    end)
    if installed then return true end
    local E = nil
    pcall(function() E = require("src.core.game3.encounters") end)
    if type(E) ~= "table" then return false end
    if type(E.rollSweetScent) ~= "function" then return false end
    if mod.hooks == nil or type(mod.hooks.wrap) ~= "function" then return false end
    if not pcall(function()
      mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
        local enc = next(encDef, ctx)
        if enc == nil then return nil end
        local t = terrainOfHook(ctx)
        if t == nil then return enc end
        local mapId = PE.context.mapId(ctx)
        return H.substitute(enc, mapId, t, nil)
      end)
    end) then return false end
    local function wrapDirect(name, terrainOf, rodOf)
      local native = E[name]
      if type(native) ~= "function" then return false end
      if E["__pe_" .. name] == true then return true end
      E["__pe_" .. name] = true
      E[name] = function(...)
        local args = { ... }
        local enc = native(...)
        if enc == nil then return nil end
        local mid = args[1]
        if mid == nil then mid = PE.context.mapId(nil) end
        return H.substitute(enc, mid, terrainOf(args), rodOf(args))
      end
      return true
    end
    local okS = wrapDirect("rollSweetScent",
      function(args)
        local t = type(args) == "table" and args[2] or nil
        if t == "water" then return "water" end
        return "land"
      end,
      function(args) return nil end)
    local okR = wrapDirect("rollRocks",
      function(args) return "rock_smash" end,
      function(args) return nil end)
    local okF = wrapDirect("rollFishing",
      function(args) return "fishing" end,
      function(args)
        local a = type(args) == "table" and args or {}
        return tonumber(a[2]) or 0
      end)
    if not (okS and okR and okF) then return false end
    installed = true
    return true
  end
  function H.ensure()
    return install()
  end
  local function bootLog()
    if logged then return end
    logged = true
    pcall(function()
      local n = PE.source.count()
      mod.log:info("poke-ecology: " .. tostring(n) .. " species indexed, "
        .. tostring(#PE.source.lines()) .. " lines built")
    end)
    pcall(function()
      if mod.find ~= nil then
        if mod.find("untamed_advanced") ~= nil then
          mod.log:info("poke-ecology: untamed_advanced present, nil results pass through")
        end
        if mod.find("safari-plus") ~= nil then
          mod.log:info("poke-ecology: safari-plus present, nil results pass through")
        end
      end
    end)
  end
  pcall(install)
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function()
      pcall(install)
      pcall(bootLog)
      pcall(function() PE.source.rescan() end)
    end)
    mod.events:on("map.entered", function()
      pcall(install)
    end)
    mod.events:on("save.loaded", function()
      seedCache = nil
    drawCount = 0
      pcall(function() PE.source.rescan() end)
    end)
    mod.events:on("battle.started", function()
      pcall(install)
    end)
  end
  PE.hooks = H
end
