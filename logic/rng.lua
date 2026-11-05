return function(mod)
  local PE = mod.exports.pokeEcology
  if not PE then
    PE = {}
    mod.exports.pokeEcology = PE
  end
  local R = {}
  local function imul32(a, b)
    a = a % 4294967296
    b = b % 4294967296
    local ah = math.floor(a / 65536)
    local al = a % 65536
    local bh = math.floor(b / 65536)
    local bl = b % 65536
    return (al * bl + 65536 * ((ah * bl + al * bh) % 65536)) % 4294967296
  end
  function R.hash(str)
    local h = 2166136261
    local s = tostring(str or "")
    for i = 1, #s do
      h = imul32(h + string.byte(s, i), 16777619)
    end
    return h
  end
  local function xor32(a, b)
    a = a % 4294967296
    b = b % 4294967296
    local r = 0
    local bit = 1
    for _ = 1, 32 do
      local ab = a % 2
      local bb = b % 2
      if ab ~= bb then r = r + bit end
      a = (a - ab) / 2
      b = (b - bb) / 2
      bit = bit * 2
    end
    return r
  end
  local function or32(a, b)
    a = a % 4294967296
    b = b % 4294967296
    local r = 0
    local bit = 1
    for _ = 1, 32 do
      local ab = a % 2
      local bb = b % 2
      if ab == 1 or bb == 1 then r = r + bit end
      a = (a - ab) / 2
      b = (b - bb) / 2
      bit = bit * 2
    end
    return r
  end
  function R.stream(seed)
    local a = math.floor(tonumber(seed) or 0) % 4294967296
    return function()
      a = (a + 1831565813) % 4294967296
      local t = a
      t = imul32(xor32(t, math.floor(t / 32768)), or32(t, 1))
      t = xor32(t + imul32(xor32(t, math.floor(t / 128)), or32(t, 61)), t)
      t = xor32(t, math.floor(t / 16384))
      return t / 4294967296
    end
  end
  function R.int(rnd, lo, hi)
    lo = math.floor(tonumber(lo) or 0)
    hi = math.floor(tonumber(hi) or lo)
    if hi < lo then lo, hi = hi, lo end
    return lo + math.floor(rnd() * (hi - lo + 1))
  end
  function R.pickWeighted(rnd, weights)
    local total = 0
    for i = 1, #weights do total = total + (tonumber(weights[i]) or 0) end
    if total <= 0 then return 1 end
    local x = rnd() * total
    local acc = 0
    for i = 1, #weights do
      acc = acc + (tonumber(weights[i]) or 0)
      if x < acc then return i end
    end
    return #weights
  end
  PE.rng = R
end
