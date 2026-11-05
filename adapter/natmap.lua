return function(mod)
  local PE = mod.exports.pokeEcology
  local N = {}
  local linked = false
  local engCache = nil
  local cachedActive = nil
  local warnedInactive = false
  local engine
  local function provider()
    local h = nil
    pcall(function()
      if mod.find ~= nil then h = mod.find("national_dex_gen3") end
    end)
    if h == nil then return false end
    return true
  end
  local function anchors()
    local E = engine()
    if type(E) ~= "table" or type(E.Data) ~= "table" then return false end
    local A = E.Data.ATLAS
    if type(A) ~= "table" or type(A.species) ~= "table" then return false end
    return A.species[1301] == 1265 and A.species[917] == 1013
  end
  function N.hasProvider()
    return provider()
  end
  function N.active()
    if cachedActive == nil then
      cachedActive = provider() and anchors()
    end
    return cachedActive
  end
  function N.resetActive()
    cachedActive = nil
    engCache = nil
  end
  function N.toSpecies(nat)
    if type(nat) ~= "number" then return nat end
    nat = math.floor(nat)
    if nat <= 0 then return nat end
    if not N.active() then return nat end
    local m = mod.exports.peDexToSpecies
    if type(m) ~= "table" then return nat end
    local v = math.floor(tonumber(m[nat]) or 0)
    if v <= 0 then return nat end
    return v
  end
  function N.checkAnchors()
    if cachedActive ~= nil then return end
    if N.hasProvider() and not N.active() and not warnedInactive then
      warnedInactive = true
      pcall(function()
        mod.log:warn("poke-ecology: national_dex_gen3 present but Untamed atlas anchors mismatch; dex->SPECIES translation off and gen 9 overworld spawns suppressed")
      end)
    end
  end
  function N.dropInactive(nat)
    nat = math.floor(tonumber(nat) or 0)
    if nat < 906 or nat > 1025 then return false end
    if N.active() then return false end
    return N.hasProvider()
  end
  engine = function()
    if type(engCache) == "table" then return engCache end
    local h = nil
    pcall(function()
      if mod.find ~= nil then h = mod.find("untamed_advanced") end
    end)
    if type(h) ~= "table" or type(h.exports) ~= "table" then return nil end
    local E = h.exports.engine
    if type(E) ~= "table" then return nil end
    engCache = E
    return E
  end
  local function link()
    if linked then return true end
    local E = engine()
    if type(E) ~= "table" then return false end
    if type(E.Gfx) ~= "table" or type(E.Gfx.sheetFor) ~= "function" then return false end
    if E.__pe_sheetFor == true then linked = true return true end
    local nativeSheetFor = E.Gfx.sheetFor
    E.__pe_sheetFor = true
    E.Gfx.sheetFor = function(species, ...)
      local sp = species
      pcall(function()
        local M = PE.natmap
        if type(M) == "table" and type(M.toSpecies) == "function" then
          sp = M.toSpecies(species)
        end
      end)
      return nativeSheetFor(sp, ...)
    end
    linked = true
    return true
  end
  function N.ensure()
    return link()
  end
  pcall(link)
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function()
      N.resetActive()
      pcall(link)
      pcall(function() N.checkAnchors() end)
    end)
    mod.events:on("map.entered", function()
      N.resetActive()
      pcall(link)
      pcall(function() N.checkAnchors() end)
    end)
    mod.events:on("battle.started", function()
      pcall(link)
    end)
  end
  PE.natmap = N
end
