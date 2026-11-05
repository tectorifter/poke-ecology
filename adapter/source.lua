return function(mod)
  local PE = mod.exports.pokeEcology
  local S = {}
  local dexCache = nil
  local dexSig = nil
  local linesCache = nil
  local hiWater = 0
  local function probe(Pokemon, id)
    local ok, nm = pcall(Pokemon.name, id)
    if not ok then return nil end
    if type(nm) ~= "string" or nm == "" or nm == "??????????" then return nil end
    return nm
  end
  local function readDex()
    local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
    if not okP or type(Pokemon) ~= "table" then return nil end
    local natApi = type(Pokemon.national) == "function"
    local dex = {}
    local count = 0
    local maxId = 0
    local h = 0
    local function foldNum(n)
      h = (h * 31 + (math.floor(tonumber(n) or 0) % 65536 + 65536) % 65536) % 1000000007
    end
    local function foldStr(s)
      if type(s) ~= "string" then foldNum(-1) return end
      foldNum(string.len(s))
      for i = 1, string.len(s) do foldNum(string.byte(s, i)) end
    end
    local function scan(lo, hi)
      for id = lo, hi do
        local nm = probe(Pokemon, id)
        if nm ~= nil then
          local bst = 0
          local t1, t2 = 0, 0
          pcall(function()
            local st = Pokemon.stats(id)
            if type(st) == "table" then
              bst = (tonumber(st.hp) or 0) + (tonumber(st.atk) or 0)
                + (tonumber(st.def) or 0) + (tonumber(st.spe) or 0)
                + (tonumber(st.spa) or 0) + (tonumber(st.spd) or 0)
            end
          end)
          pcall(function()
            local ts = Pokemon.types(id)
            if type(ts) == "table" then
              t1 = math.floor(tonumber(ts[1]) or 0)
              t2 = math.floor(tonumber(ts[2]) or t1)
            end
          end)
          local catch = nil
          pcall(function()
            local meta = Pokemon.speciesMeta(id)
            if type(meta) == "table" then catch = tonumber(meta.catchRate) end
          end)
          local evos = {}
          pcall(function()
            local rows = Pokemon.evolutions(id)
            if type(rows) == "table" then evos = rows end
          end)
          local nat = nil
          if natApi then
            pcall(function()
              nat = math.floor(tonumber(Pokemon.national(id)) or 0)
            end)
            if nat == 0 then nat = nil end
          end
          if bst > 0 then
            dex[id] = { bst = bst, t1 = t1, t2 = t2, catch = catch, evos = evos, name = nm, nat = nat }
            count = count + 1
            if id > maxId then maxId = id end
            foldNum(id)
            foldNum(nat or -1)
            foldStr(nm)
            foldNum(bst)
            foldNum(t1)
            foldNum(t2)
            foldNum(catch or -1)
            for _, e in ipairs(evos) do
              if type(e) == "table" then
                foldStr(tostring(e.method or e[1]))
                foldNum(e.target or e[3])
                foldNum(e.param or e[2])
              end
            end
          end
        end
      end
    end
    scan(1, 4096)
    scan(9000, 11000)
    if count < 1 then return nil end
    if maxId > hiWater then hiWater = maxId end
    return dex, count .. "|" .. maxId .. "|" .. h .. "|" .. (natApi and "1" or "0"), natApi
  end
  local function blockedName(nm)
    if type(nm) ~= "string" then return false end
    local u = string.upper(nm)
    if string.find(u, "GIGANTAMAX", 1, true) then return true end
    if string.find(u, "GMAX", 1, true) then return true end
    return string.find(u, "%f[%a]MEGA%f[%A]") ~= nil
  end
  local function blockedMethod(m)
    if type(m) ~= "string" then return false end
    local u = string.upper(m)
    return string.find(u, "MEGA", 1, true) ~= nil
      or string.find(u, "GMAX", 1, true) ~= nil
      or string.find(u, "GIGANTAMAX", 1, true) ~= nil
  end
  function S.rescan()
    local dex, sig, natApi = readDex()
    if dex == nil then return false end
    dexCache = dex
    if sig ~= dexSig then
      dexSig = sig
      linesCache = nil
      local dexLegends = {}
      local blocked = {}
      for id, d in pairs(dex) do
        id = math.floor(tonumber(id) or 0)
        if id > 0 and type(d) == "table" then
          if blockedName(d.name) then blocked[id] = true end
          local evos = type(d.evos) == "table" and d.evos or {}
          for _, e in ipairs(evos) do
            if type(e) == "table" and blockedMethod(e.method or e[1]) then
              local tgt = math.floor(tonumber(e.target or e[3]) or 0)
              if tgt > 0 then blocked[tgt] = true end
            end
          end
        end
      end
      local prov = {}
      pcall(function()
        local h = mod.find and mod.find("national_dex_gen3")
        local xp = type(h) == "table" and h.exports or nil
        if type(xp) == "table" and type(xp.listSpecies) == "function" then
          for _, r in ipairs(xp.listSpecies() or {}) do
            if type(r) == "table" then
              local slot = math.floor(tonumber(r.slot) or 0)
              if slot > 0 then
                if r.legendary or r.mythical then dexLegends[slot] = true end
                if r.mega or r.gmax or r.gigantamax or r.isMega or r.isGmax or r.isGigantamax then
                  blocked[slot] = true
                else
                  for _, k in ipairs({ "form", "forme", "kind", "variant" }) do
                    local v = r[k]
                    if type(v) == "string" and (blockedName(v) or blockedMethod(v)) then
                      blocked[slot] = true
                      break
                    end
                  end
                end
                if prov[slot] == nil then prov[slot] = r end
              end
            end
          end
        end
      end)
      local conflicts = {}
      local slotNat = {}
      local liveNats = {}
      local deadNames = {}
      local dead = {}
      for id, d in pairs(dex) do
        id = math.floor(tonumber(id) or 0)
        if id > 0 and type(d) == "table" then
          if d.nat ~= nil then liveNats[id] = d.nat end
          local r = prov[id]
          if r ~= nil then
            local wantNat = math.floor(tonumber(r.dex) or 0)
            if natApi and wantNat > 0 and d.nat ~= nil and d.nat ~= wantNat then
              conflicts[id] = true
              dead[#dead + 1] = id
              deadNames[id] = d.name
            else
              slotNat[id] = d.nat or (wantNat > 0 and wantNat or nil)
            end
          else
            if natApi then
              if d.nat ~= nil then
                slotNat[id] = d.nat
              else
                conflicts[id] = true
                blocked[id] = true
                deadNames[id] = d.name
              end
            end
          end
        end
      end
      for _, id in ipairs(dead) do
        dex[id] = nil
        blocked[id] = true
      end
      mod.exports.peDexLegendaries = dexLegends
      mod.exports.peBlockedForms = blocked
      mod.exports.peSlotNat = natApi and slotNat or nil
      mod.exports.peSlotNatLive = natApi and liveNats or nil
      mod.exports.peConflicts = conflicts
      local n = 0
      for _ in pairs(conflicts) do n = n + 1 end
      if n > 0 then
        pcall(function()
          mod.log:warn("poke-ecology: " .. tostring(n) .. " conflicted species excluded from overworld")
        end)
        pcall(function()
          local ids = {}
          for id in pairs(conflicts) do ids[#ids + 1] = id end
          table.sort(ids)
          local cap = 20
          if #ids < cap then cap = #ids end
          for i = 1, cap do
            local nm = deadNames[ids[i]]
            if type(nm) ~= "string" then nm = "?" end
            mod.log:warn("poke-ecology: conflict slot " .. tostring(ids[i]) .. " '" .. nm
              .. "' live_nat=" .. tostring(liveNats[ids[i]]))
          end
          if #ids > cap then
            mod.log:warn("poke-ecology: ... and " .. tostring(#ids - cap) .. " more (PE.diag.reportText() has them all)")
          else
            mod.log:warn("poke-ecology: PE.diag.reportText() has the modder-ready breakdown")
          end
        end)
      end
      return true
    end
    return false
  end
  function S.natOk(id)
    local m = mod.exports.peSlotNat
    if type(m) ~= "table" then return true end
    id = math.floor(tonumber(id) or 0)
    if id <= 0 then return false end
    local want = m[id]
    if want == nil then return false end
    local got = nil
    local ok = false
    pcall(function()
      local Pokemon = require("src.core.game3.pokemon")
      got = math.floor(tonumber(Pokemon.national(id)) or 0)
      ok = true
    end)
    if not ok then return true end
    if got == nil or got <= 0 then return false end
    return got == want
  end
  function S.dex()
    if dexCache == nil then S.rescan() end
    return dexCache
  end
  function S.sig()
    return dexSig
  end
  function S.lines()
    local dex = S.dex()
    if dex == nil then return {} end
    if linesCache ~= nil then
      local found = false
      pcall(function()
        local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
        if okP and type(Pokemon) == "table" then
          for id = hiWater + 1, hiWater + 8 do
            if probe(Pokemon, id) ~= nil then found = true break end
          end
        end
      end)
      if found then
        if S.rescan() then dex = S.dex() end
      end
    end
    if dex == nil then return {} end
    if linesCache == nil then
      linesCache = PE.lines.build(dex, mod.exports.peRules, mod.exports.peOverrides)
    end
    return linesCache
  end
  function S.count()
    local n = 0
    if type(dexCache) == "table" then
      for _ in pairs(dexCache) do n = n + 1 end
    end
    return n
  end
  PE.source = S
end
