return function(mod)
  local PE = mod.exports.pokeEcology
  local W = {}
  function W.pick(slots, weights, overlay, rnd)
    if type(slots) ~= "table" or #slots == 0 then return nil end
    local w = {}
    for i = 1, #slots do
      local v = tonumber(weights and weights[i]) or 1
      if overlay ~= nil and type(overlay.banned) == "table" and overlay.banned[i] then
        v = 0
      end
      if overlay ~= nil and type(overlay.mults) == "table" then
        v = v * (tonumber(overlay.mults[i]) or 1)
      end
      if v < 0 then v = 0 end
      w[i] = v
    end
    local idx = PE.rng.pickWeighted(rnd, w)
    return slots[idx], idx
  end
  PE.roll = W
end
