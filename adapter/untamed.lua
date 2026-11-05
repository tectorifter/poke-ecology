return function(mod)
  local PE = mod.exports.pokeEcology
  local U = {}
  local linked = false
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
  local function shape(terrain, pop, mid)
    local tpl = mod.exports.peSlots
    tpl = type(tpl) == "table" and tpl[terrain] or nil
    local target = 0
    if type(tpl) == "table" and type(tpl.roles) == "table" then target = #tpl.roles end
    local items = {}
    if type(pop) == "table" then
      for _, s in ipairs(pop) do
        if type(s) ~= "table" then break end
        local sp = math.floor(tonumber(s.species) or 0)
        local lv = math.floor(tonumber(s.level) or 0)
        if sp >= 1 and lv >= 1 then
          local bad = false
          pcall(function()
            local A = PE.admit
            if type(A) == "table" and type(A.blocked) == "function" then
              bad = A.blocked(sp) == true
            end
          end)
          if not bad then
            pcall(function()
              local src = PE.source
              if type(src) == "table" and type(src.natOk) == "function" then
                if src.natOk(sp) ~= true then bad = true end
              end
            end)
          end
          if not bad then
            pcall(function()
              local M = PE.natmap
              if type(M) == "table" and type(M.dropInactive) == "function" then
                local nat = nil
                local src = PE.source
                if type(src) == "table" and type(src.dex) == "function" then
                  local dex = src.dex()
                  if type(dex) == "table" and type(dex[sp]) == "table" then
                    nat = dex[sp].nat
                  end
                end
                if M.dropInactive(nat) then bad = true end
              end
            end)
          end
          if not bad then items[#items + 1] = s end
        end
      end
    end
    if #items == 0 then return nil end
    pcall(function()
      local M = PE.natmap
      if type(M) == "table" and type(M.checkAnchors) == "function" then
        M.checkAnchors()
      end
    end)
    local weights = {}
    pcall(function()
      local ov = nil
      local mods = mod.exports.peModifiers
      local wctx = nil
      if type(PE.context) == "table" then
        local hour = 8
        if type(PE.context.clock) == "function" then hour = PE.context.clock() end
        local bucket = "morning"
        if type(PE.context.bucket) == "function" then
          bucket = PE.context.bucket(hour)
        end
        local tags = nil
        if type(PE.context) == "table" then
          local areas = mod.exports.peAreas
          if type(areas) == "table" then
            local a = areas[mid]
            if type(a) == "table" then tags = a.tags end
          end
        end
        local weather = "none"
        if type(PE.context.weather) == "function" then weather = PE.context.weather() end
        wctx = { terrain = terrain, bucket = bucket, weather = weather, areaTags = tags }
      end
      if type(PE.overlay) ~= "table" or type(PE.overlay.apply) ~= "function" then return end
      ov = PE.overlay.apply(items, wctx and wctx.weather or "none", mods, wctx)
      if type(ov) ~= "table" then return end
      local mults = type(ov.mults) == "table" and ov.mults or {}
      local banned = type(ov.banned) == "table" and ov.banned or {}
      for i = 1, #items do
        if banned[i] then weights[i] = 0
        else weights[i] = tonumber(mults[i]) or 1 end
      end
    end)
    if #weights ~= #items then
      for i = 1, #items do weights[i] = 1 end
    end
    local total = 0
    for i = 1, #items do total = total + (tonumber(weights[i]) or 0) end
    if total <= 0 then return nil end
    if target < 1 then target = #items end
    local seats = {}
    local assigned = 0
    for i = 1, #items do
      local q = target * (tonumber(weights[i]) or 0) / total
      local s = math.floor(q)
      seats[i] = { n = s, frac = q - s, idx = i }
      assigned = assigned + s
    end
    local left = target - assigned
    while left > 0 do
      local best = nil
      for i = 1, #items do
        if (tonumber(weights[i]) or 0) > 0 and (best == nil or seats[i].frac > seats[best].frac) then
          best = i
        end
      end
      if best == nil then break end
      seats[best].n = seats[best].n + 1
      seats[best].frac = -1
      left = left - 1
    end
    local out = {}
    local emitted = 0
    while emitted < target do
      local moved = false
      for i = 1, #items do
        if seats[i].n > 0 and emitted < target then
          seats[i].n = seats[i].n - 1
          local s = items[i]
          if type(s) ~= "table" then break end
          local sp = math.floor(tonumber(s.species) or 0)
          local lv = math.floor(tonumber(s.level) or 0)
          if sp < 1 or lv < 1 then break end
          out[#out + 1] = { species = sp, level = lv }
          emitted = emitted + 1
          moved = true
        end
      end
      if not moved then break end
    end
    if #out == 0 then return nil end
    return out
  end
  local function link()
    if linked then return true end
    local E = engine()
    if type(E) ~= "table" then return false end
    if type(E.wildArea) ~= "function" then return false end
    local H = PE.hooks
    if type(H) ~= "table" or type(H.popSlots) ~= "function" then return false end
    if E.__pe_wildArea == true then linked = true return true end
    local native = E.wildArea
    E.__pe_wildArea = true
    E.wildArea = function(header, kind)      local slots = native(header, kind)
      if slots == nil then return nil end
      if not on() then return slots end
      local terrain = "land"
      if kind == "water" then terrain = "water" end
      local mid = nil
      pcall(function()
        if type(E.mapId) == "function" then mid = E.mapId() end
      end)
      if mid == nil then mid = PE.context.mapId(nil) end
      local pop = nil
      pcall(function() pop = H.popSlots(mid, terrain, nil) end)
      if type(pop) ~= "table" or #pop == 0 then return slots end
      return shape(terrain, pop, mid) or slots
    end
    linked = true
    pcall(function()
      mod.log:info("poke-ecology: Untamed overworld spawns follow ecology tables")
    end)
    return true
  end
  function U.ensure()
    return link()
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
  PE.untamed = U
end
