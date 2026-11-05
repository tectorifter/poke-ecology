return function(mod)
  local PE = mod.exports.pokeEcology
  local T = {}
  function T.resolveLevel(band, rolePos, jitter, power, rules)
    local lo = band.lo
    local hi = band.hi
    local w = hi - lo
    local r = 0
    if tonumber(band.bst) and tonumber(band.bst) > 0 then
      r = ((tonumber(power) or 0) - tonumber(band.bst)) / tonumber(band.bst)
    end
    if r > 0.5 then r = 0.5 elseif r < -0.5 then r = -0.5 end
    local raw = lo + w * (tonumber(rolePos) or 0) - w * r + (tonumber(jitter) or 0)
    local level = math.floor(raw + 0.5)
    if level < lo then level = lo end
    if level > hi then level = hi end
    return level
  end
  function T.resolveStage(line, branch, level, ceilBst, terrain)
    if type(line) ~= "table" or type(branch) ~= "table" then return nil end
    local stages = type(branch.stages) == "table" and branch.stages or {}
    if #stages == 0 then return nil end
    level = math.floor(tonumber(level) or 1)
    ceilBst = math.floor(tonumber(ceilBst) or 1000000)
    local pick = 1
    for i, st in ipairs(stages) do
      if (tonumber(st.threshold) or 1) <= level then pick = i end
    end
    while pick > 1 and (tonumber(stages[pick].bst) or 0) > ceilBst do
      pick = pick - 1
    end
    if PE.admit.stageSpawnOk(stages[pick], terrain) then return stages[pick], pick end
    local below = nil
    for i = pick - 1, 1, -1 do
      if (tonumber(stages[i].bst) or 0) <= ceilBst
          and PE.admit.stageSpawnOk(stages[i], terrain) then
        below = i
        break
      end
    end
    if below ~= nil then return stages[below], below end
    for i = pick + 1, #stages do
      if (tonumber(stages[i].bst) or 0) <= ceilBst
          and PE.admit.stageSpawnOk(stages[i], terrain) then
        return stages[i], i
      end
    end
    return nil
  end
  PE.stage = T
end
