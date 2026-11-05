return function(mod)
  local PE = mod.exports.pokeEcology
  local D = {}
  local function num(v)
    local n = math.floor(tonumber(v) or 0)
    if n <= 0 then return nil end
    return n
  end
  local function up(s)
    if type(s) ~= "string" then return "" end
    return string.upper(s)
  end
  local function show(v)
    if v == nil then return "-" end
    return tostring(v)
  end
  local function qname(nm)
    if type(nm) ~= "string" then return "-" end
    return "'" .. nm .. "'"
  end
  local function pokemon()
    local ok, P = pcall(require, "src.core.game3.pokemon")
    if not ok or type(P) ~= "table" then return nil end
    return P
  end
  local function engineName(P, slot)
    local nm = nil
    pcall(function() nm = P.name(slot) end)
    if type(nm) ~= "string" or nm == "" or nm == "??????????" then return nil end
    return nm
  end
  local function engineNat(P, slot)
    if type(P.national) ~= "function" then return nil, false end
    local n = nil
    local ok = pcall(function()
      n = math.floor(tonumber(P.national(slot)) or 0)
    end)
    if not ok then return nil, true end
    if n == nil or n <= 0 then return nil, true end
    return n, true
  end
  local function megaToken(nm)
    local u = up(nm)
    if u == "" then return false end
    if string.find(u, "GIGANTAMAX", 1, true) then return true end
    if string.find(u, "GMAX", 1, true) then return true end
    return string.find(u, "%f[%a]MEGA%f[%A]") ~= nil
  end
  local function provider(slot)
    local rec = nil
    local present = false
    pcall(function()
      local h = mod.find and mod.find("national_dex_gen3")
      local xp = type(h) == "table" and h.exports or nil
      if type(xp) == "table" and type(xp.listSpecies) == "function" then
        present = true
        local list = xp.listSpecies() or {}
        if type(list) == "table" then
          for _, r in ipairs(list) do
            if type(r) == "table" and math.floor(tonumber(r.slot) or 0) == slot then
              rec = r
              break
            end
          end
        end
      end
    end)
    return rec, present
  end
  local function providerMega(rec)
    if type(rec) ~= "table" then return false end
    if rec.mega or rec.gmax or rec.gigantamax or rec.isMega or rec.isGmax or rec.isGigantamax then
      return true
    end
    for _, k in ipairs({ "form", "forme", "kind", "variant" }) do
      local v = rec[k]
      if type(v) == "string" and megaToken(v) then return true end
    end
    return false
  end
  local function rivals()
    local found = {}
    pcall(function()
      for _, id in ipairs({ "national_dex_gen3", "1025dex" }) do
        local h = mod.find and mod.find(id)
        if type(h) == "table" then found[#found + 1] = id end
      end
    end)
    if #found == 0 then found[1] = "none" end
    return found
  end
  local function art(slot, nat)
    local info = { present = false }
    pcall(function()
      local h = mod.find and mod.find("untamed_advanced")
      local E = type(h) == "table" and type(h.exports) == "table" and h.exports.engine or nil
      if type(E) ~= "table" then return end
      info.present = true
      local key = nat
      if type(E.expansionSpecies) == "function" then
        local ok, v = pcall(E.expansionSpecies, slot, 0)
        if ok and tonumber(v) ~= nil and math.floor(tonumber(v)) > 0 then
          info.expansion = math.floor(tonumber(v))
          key = info.expansion
        end
      end
      if key ~= nil and type(E.Gfx) == "table" and type(E.Gfx.sheetFor) == "function" then
        local ok, s = pcall(E.Gfx.sheetFor, key, false, false)
        if ok and tonumber(s) ~= nil and math.floor(tonumber(s)) > 0 then
          info.sheet = math.floor(tonumber(s))
        end
      end
      if type(E.Data) == "table" and type(E.Data.ATLAS) == "table" then
        local A = E.Data.ATLAS
        if key ~= nil and type(A.species) == "table" then
          local v = A.species[key]
          if tonumber(v) ~= nil and math.floor(tonumber(v)) > 0 then
            info.atlas = math.floor(tonumber(v))
          end
        end
        if tonumber(A.SUBSTITUTE) ~= nil and math.floor(tonumber(A.SUBSTITUTE)) > 0 then
          info.substitute = math.floor(tonumber(A.SUBSTITUTE))
        end
      end
    end)
    return info
  end
  local function scanEntry(slot)
    local entry = nil
    pcall(function()
      local src = PE.source
      if type(src) == "table" and type(src.dex) == "function" then
        local dex = src.dex()
        if type(dex) == "table" then entry = dex[slot] end
      end
    end)
    return entry
  end
  local function decide(r)
    if r.engineMissing then
      return "NO_ENGINE", "The engine Pokemon module is unavailable, so nothing could be read. Run this diagnostic in-game (any map, then read the game log or call PE.diag.reportText())."
    end
    if r.api == false then
      return "NO_NATIONAL_API", "This engine exposes no Pokemon.national, so sprite agreement cannot be checked and the overworld guard stays fail-open by design. Nothing is excluded and no modder action is needed."
    end
    if r.name == nil then
      return "EMPTY_SLOT", "Engine slot " .. tostring(r.slot) .. " has no name, so nothing spawns from it. If a mod should register a species here, that mod never installed its name row."
    end
    if r.mega then
      return "MEGA_BLOCKED", "Slot " .. tostring(r.slot) .. " " .. qname(r.name) .. " is a mega/gigantamax form. poke-ecology never spawns it overworld; if it appears in-game it comes from vanilla tables or another mod's spawn list, not from ecology pops. Send this report to that list's owner."
    end
    if r.provider.present and r.provider.dex ~= nil and r.liveNat ~= nil and r.liveNat ~= r.provider.dex then
      if r.rescanNat ~= nil and r.rescanNat == r.provider.dex then
        return "ENGINE_FLIP", "Slot " .. tostring(r.slot) .. " " .. qname(r.name) .. " agreed at rescan (national " .. tostring(r.rescanNat) .. " = provider dex " .. tostring(r.provider.dex) .. ") but now reads " .. tostring(r.liveNat) .. ". Something rewrote the registry after rescan: a late installer or a load-order race. Send this report plus the mod load order to the author of the mod that registers slot " .. tostring(r.slot) .. " last."
      end
      return "PROVIDER_CONFLICT", "Two content mods claim engine slot " .. tostring(r.slot) .. ": live national " .. tostring(r.liveNat) .. " " .. qname(r.name) .. " vs provider dex " .. tostring(r.provider.dex) .. " " .. qname(r.provider.name) .. ". The slot is excluded from ecology overworld pops (battles still use it). Send this report to the author of the second writer (any mod besides national_dex_gen3 that registers slot " .. tostring(r.slot) .. "), or to national_dex_gen3 if its slot table is the stale one."
    end
    if r.liveNat == nil then
      if r.provider.listed then
        return "NO_LIVE_NATIONAL", "Slot " .. tostring(r.slot) .. " " .. qname(r.name) .. " is listed by the dex provider (dex " .. show(r.provider.dex) .. ") but Pokemon.national returns nil at runtime, so Untamed aborts the spawn. The provider's national table did not install for this slot. Send this report to national_dex_gen3."
      end
      return "UNLISTED_NO_NATIONAL", "Slot " .. tostring(r.slot) .. " " .. qname(r.name) .. " is registered by an unknown mod (no provider record) and has no live national id, so Untamed cannot render it. The mod that registered the name must also register a national id. Excluded from ecology pops."
    end
    if r.provider.listed and r.provider.name ~= nil and up(r.provider.name) ~= up(r.name) then
      return "NAME_MISMATCH", "Slot " .. tostring(r.slot) .. ": national ids agree (" .. tostring(r.liveNat) .. ") but the live name " .. qname(r.name) .. " differs from the provider's " .. qname(r.provider.name) .. ": the name table and the national table were written by different mods (or one is stale). Art is right but battle data may be mixed. Send this report to whichever mod owns the stale table."
    end
    if r.art.present then
      if r.art.sheet == nil then
        return "ATLAS_GAP", "All registry layers agree (slot " .. tostring(r.slot) .. " = national " .. tostring(r.liveNat) .. " " .. qname(r.name) .. ") but Untamed has no sprite sheet for national " .. tostring(r.liveNat) .. " (sheetFor returns nil), so the spawn is skipped. Untamed-Advanced needs the OW sprite for national " .. tostring(r.liveNat) .. "."
      end
      if r.art.substitute ~= nil and r.art.sheet == r.art.substitute then
        return "ATLAS_SUBSTITUTE", "All registry layers agree (slot " .. tostring(r.slot) .. " = national " .. tostring(r.liveNat) .. " " .. qname(r.name) .. ") but the sheet maps to Untamed's SUBSTITUTE placeholder: the sprite for national " .. tostring(r.liveNat) .. " is missing. Untamed-Advanced needs the real OW sprite."
      end
    else
      return "AGREE_NO_UNTAMED", "Registry layers agree (slot " .. tostring(r.slot) .. " = national " .. tostring(r.liveNat) .. " " .. qname(r.name) .. ") but Untamed is absent so art could not be checked. Nothing to report."
    end
    return "AGREE", "Every layer agrees for slot " .. tostring(r.slot) .. " (engine name/national, provider record, rescan snapshot, Untamed sheet " .. show(r.art.sheet) .. "). If the wrong sprite still shows in-game, the spawn predates the last rescan or another mod rewrote the slot mid-session: re-enter the map and attach the fresh log."
  end
  local function headline(r)
    local p = r.provider
    local a = r.art
    local prov = "absent"
    if p.listed then prov = "dex=" .. show(p.dex) .. " " .. qname(p.name)
    elseif p.present then prov = "unlisted" end
    local artS = "untamed-absent"
    if a.present then
      artS = "expansion=" .. show(a.expansion) .. " sheet=" .. show(a.sheet) .. " atlas=" .. show(a.atlas)
    end
    return "slot " .. tostring(r.slot) .. " " .. qname(r.name)
      .. ": live_nat=" .. show(r.liveNat)
      .. " provider=" .. prov
      .. " rescan_nat=" .. show(r.rescanNat)
      .. " conflict=" .. tostring(r.conflict)
      .. " blocked=" .. tostring(r.blocked)
      .. " natOk=" .. tostring(r.natOk)
      .. " art=" .. artS
      .. " verdict=" .. tostring(r.verdict)
  end
  function D.slotReport(slot)
    slot = math.floor(tonumber(slot) or 0)
    local r = { slot = slot, provider = {}, art = { present = false },
      mega = false, conflict = false, blocked = false, natOk = nil,
      rescanNat = nil, rescanName = nil, liveNat = nil, api = true,
      name = nil, engineMissing = false }
    local P = pokemon()
    if P == nil then
      r.engineMissing = true
    else
      r.name = engineName(P, slot)
      local nat, api = engineNat(P, slot)
      r.liveNat = nat
      r.api = api
    end
    local rec, present = provider(slot)
    r.provider.present = present
    r.provider.listed = rec ~= nil
    if type(rec) == "table" then
      r.provider.dex = num(rec.dex)
      if type(rec.name) == "string" then r.provider.name = rec.name end
      r.provider.mega = providerMega(rec)
    end
    local set = mod.exports.peBlockedForms
    if type(set) == "table" then r.blocked = set[slot] == true end
    local cf = mod.exports.peConflicts
    if type(cf) == "table" then r.conflict = cf[slot] == true end
    local sn = mod.exports.peSlotNat
    if type(sn) == "table" then r.slotNat = sn[slot] end
    local ln = mod.exports.peSlotNatLive
    if type(ln) == "table" then r.rescanNat = ln[slot] end
    local entry = scanEntry(slot)
    if type(entry) == "table" and type(entry.name) == "string" then r.rescanName = entry.name end
    pcall(function()
      local src = PE.source
      if type(src) == "table" and type(src.natOk) == "function" then
        r.natOk = src.natOk(slot)
      end
    end)
    r.mega = megaToken(r.name) or r.provider.mega == true
    if not r.engineMissing then r.art = art(slot, r.liveNat) end
    local v, fix = decide(r)
    r.verdict = v
    r.fix = fix
    r.headline = headline(r)
    return r
  end
  function D.focusSlots(extra)
    local seen = {}
    local list = {}
    local function add(id)
      id = math.floor(tonumber(id) or 0)
      if id > 0 and not seen[id] then
        seen[id] = true
        list[#list + 1] = id
      end
    end
    local cf = mod.exports.peConflicts
    if type(cf) == "table" then for id in pairs(cf) do add(id) end end
    local bf = mod.exports.peBlockedForms
    if type(bf) == "table" then for id in pairs(bf) do add(id) end end
    if type(extra) == "table" then
      if #extra > 0 then
        for _, id in ipairs(extra) do add(id) end
      else
        for id in pairs(extra) do add(id) end
      end
    elseif tonumber(extra) ~= nil then
      add(extra)
    end
    table.sort(list)
    local out = {}
    for i = 1, math.min(#list, 48) do out[#out + 1] = list[i] end
    return out, #list
  end
  function D.reportText(slots)
    local list, total = D.focusSlots(slots)
    local eco = true
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        eco = mod.options:get("ecology")
      end
    end)
    local ndx = false
    pcall(function() ndx = mod.find and mod.find("national_dex_gen3") ~= nil end)
    local un = false
    pcall(function() un = mod.find and mod.find("untamed_advanced") ~= nil end)
    local natApi = false
    pcall(function()
      local P = require("src.core.game3.pokemon")
      natApi = type(P) == "table" and type(P.national) == "function"
    end)
    local ncf = 0
    local cf = mod.exports.peConflicts
    if type(cf) == "table" then for _ in pairs(cf) do ncf = ncf + 1 end end
    local nbf = 0
    local bf = mod.exports.peBlockedForms
    if type(bf) == "table" then for _ in pairs(bf) do nbf = nbf + 1 end end
    local out = {}
    out[#out + 1] = "poke-ecology overworld-sprite diagnostic: paste this whole block to the modder named in the FIX line that matches your case"
    out[#out + 1] = "env: ecology=" .. tostring(eco ~= false) .. " national_api=" .. tostring(natApi)
      .. " dex_provider=" .. (ndx and "present" or "absent")
      .. " untamed=" .. (un and "present" or "absent")
      .. " rivals=" .. table.concat(rivals(), ",")
    out[#out + 1] = "flagged_slots=" .. tostring(total) .. " shown=" .. tostring(#list)
      .. " conflicts=" .. tostring(ncf) .. " blocked=" .. tostring(nbf)
      .. " (battle rolls are untouched; ecology already excludes every slot below from its own overworld pops)"
    local counts = {}
    local order = {}
    local fixes = {}
    for _, id in ipairs(list) do
      local r = D.slotReport(id)
      out[#out + 1] = r.headline
      if counts[r.verdict] == nil then
        counts[r.verdict] = 0
        order[#order + 1] = r.verdict
      end
      counts[r.verdict] = counts[r.verdict] + 1
      if fixes[r.verdict] == nil then fixes[r.verdict] = r.fix end
    end
    for _, v in ipairs(order) do
      out[#out + 1] = "FIX " .. tostring(v) .. " (" .. tostring(counts[v]) .. " slots): " .. tostring(fixes[v])
    end
    out[#out + 1] = "repro: re-enter the map (rescan) then watch the spawn; attach the game log lines starting 'poke-ecology: conflict slot'"
    return table.concat(out, "\n")
  end
  function D.logReport(slots)
    local txt = D.reportText(slots)
    pcall(function()
      for line in string.gmatch(txt, "[^\n]+") do
        mod.log:warn("poke-ecology: " .. line)
      end
    end)
    return txt
  end
  PE.diag = D
end
