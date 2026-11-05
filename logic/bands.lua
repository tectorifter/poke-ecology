return function(mod)
  local PE = mod.exports.pokeEcology
  local B = {}
  function B.bucketFor(buckets, hour)
    hour = math.floor(tonumber(hour) or 0) % 24
    local id = nil
    local start = -1
    if type(buckets) == "table" then
      for _, b in ipairs(buckets) do
        if type(b) == "table" and type(b.id) == "string" then
          local s = math.floor(tonumber(b.start_hour) or 0) % 24
          if s <= hour and s > start then start = s id = b.id end
        end
      end
    end
    if id == nil then id = "morning" end
    return id
  end
  function B.band(curves, ordinal, terrain)
    ordinal = math.floor(tonumber(ordinal) or 1)
    if ordinal < 1 then ordinal = 1 end
    local lo, hi, mid, bst = 2, 4, 3, 200
    local cap = 350
    if type(curves) == "table" and #curves > 0 then
      local prev = curves[1]
      local nxt = curves[#curves]
      for _, a in ipairs(curves) do
        if type(a) == "table" and math.floor(tonumber(a.o) or 0) <= ordinal then prev = a end
      end
      for _, a in ipairs(curves) do
        if type(a) == "table" and math.floor(tonumber(a.o) or 0) >= ordinal then
          nxt = a
          break
        end
      end
      local po = math.floor(tonumber(prev.o) or 1)
      local no = math.floor(tonumber(nxt.o) or po)
      local f = 0
      if no > po then f = (ordinal - po) / (no - po) end
      if f < 0 then f = 0 end
      if f > 1 then f = 1 end
      local function num(v, d)
        v = tonumber(v)
        if v == nil then return d end
        return v
      end
      lo = num(prev.lo, 2) + (num(nxt.lo, 2) - num(prev.lo, 2)) * f
      hi = num(prev.hi, 4) + (num(nxt.hi, 4) - num(prev.hi, 4)) * f
      bst = num(prev.bst, 200) + (num(nxt.bst, 200) - num(prev.bst, 200)) * f
      cap = num(prev.line_cap, 350) + (num(nxt.line_cap, 350) - num(prev.line_cap, 350)) * f
    end
    local loff = 0
    local boff = 0
    if type(terrain) == "table" then
      loff = math.floor(tonumber(terrain.level_off) or 0)
      boff = math.floor(tonumber(terrain.bst_off) or 0)
    end
    lo = math.floor(lo + loff + 0.5)
    hi = math.floor(hi + loff + 0.5)
    if lo < 1 then lo = 1 end
    if hi < lo then hi = lo end
    if hi > 100 then hi = 100 end
    bst = math.floor(bst + boff + 0.5)
    if bst < 50 then bst = 50 end
    mid = math.floor((lo + hi) / 2)
    return { lo = lo, hi = hi, mid = mid, bst = bst, cap = math.floor(cap + 0.5) }
  end
  PE.bands = B
end
