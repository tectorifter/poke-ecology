return function(mod)
  local PE = mod.exports.pokeEcology
  local G = {}
  local ROUTES = { EM_ROUTE101 = 1, EM_ROUTE102 = 2, EM_ROUTE103 = 3, EM_ROUTE104 = 4 }
  local counters = { 0, 0, 0, 0 }
  local cachedRef = nil
  local cachedList = nil
  local function on()
    local v = true
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        v = mod.options:get("gen9_diag")
      end
    end)
    if v == nil then return true end
    return v ~= false
  end
  local function routeOf(mid)
    if type(mid) ~= "string" then
      if type(mid) == "number" then mid = tostring(mid) else return nil end
    end
    return ROUTES[string.upper(mid)]
  end
  local function gen9()
    local dex = nil
    pcall(function()
      if type(PE.source) == "table" and type(PE.source.dex) == "function" then
        dex = PE.source.dex()
      end
    end)
    if type(dex) ~= "table" then return nil end
    if dex == cachedRef and type(cachedList) == "table" then return cachedList end
    local list = {}
    for id, d in pairs(dex) do
      id = math.floor(tonumber(id) or 0)
      if id > 0 and type(d) == "table" then
        local n = math.floor(tonumber(d.nat) or 0)
        if n >= 906 and n <= 1025 then list[#list + 1] = id end
      end
    end
    if #list == 0 then return nil end
    table.sort(list)
    cachedRef = dex
    cachedList = list
    return list
  end
  function G.pick(mid)
    if not on() then return nil end
    local r = routeOf(mid)
    if r == nil then return nil end
    local list = gen9()
    if list == nil then return nil end
    local per = math.ceil(#list / 4)
    local lo = ((r - 1) * per % #list) + 1
    if lo > #list then return nil end
    local hi = lo + per - 1
    if hi > #list then hi = #list end
    counters[r] = counters[r] + 1
    return list[lo + ((counters[r] - 1) % (hi - lo + 1))]
  end
  local function engine()
    local h = nil
    pcall(function()
      if mod.find ~= nil then h = mod.find("untamed_advanced") end
    end)
    if type(h) ~= "table" or type(h.exports) ~= "table" then return nil end
    local E = h.exports.engine
    if type(E) ~= "table" then return nil end
    return E
  end
  local function link()
    local H = PE.hooks
    if type(H) == "table" and type(H.substitute) == "function"
      and H.__pe_gen9sub ~= true then
      H.__pe_gen9sub = true
      local nativeSub = H.substitute
      H.substitute = function(enc, mapId, terrainName, rod)
        local res = nativeSub(enc, mapId, terrainName, rod)
        if res == nil then return nil end
        local sp = G.pick(mapId)
        if sp == nil then return res end
        res.species = sp
        res.speciesId = sp
        return res
      end
    end
    local E = engine()
    if type(E) == "table" and type(E.wildArea) == "function"
      and E.__pe_gen9wild ~= true then
      E.__pe_gen9wild = true
      local nativeWild = E.wildArea
      E.wildArea = function(header, kind)
        local slots = nativeWild(header, kind)
        if slots == nil then return nil end
        local mid = nil
        pcall(function()
          if type(E.mapId) == "function" then mid = E.mapId() end
        end)
        if mid == nil then
          pcall(function()
            if type(PE.context) == "table" and type(PE.context.mapId) == "function" then
              mid = PE.context.mapId(nil)
            end
          end)
        end
        if routeOf(mid) == nil or not on() then return slots end
        local out = {}
        for i, s in ipairs(slots) do
          if type(s) == "table" then
            local sp = G.pick(mid)
            if sp == nil then sp = s.species end
            out[#out + 1] = { species = sp, level = s.level }
          end
        end
        if #out == 0 then return slots end
        return out
      end
    end
    return true
  end
  pcall(link)
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function()
      pcall(link)
    end)
    mod.events:on("map.entered", function()
      pcall(link)
    end)
    mod.events:on("battle.started", function()
      pcall(link)
    end)
  end
  PE.gen9diag = G
end
