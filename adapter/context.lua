return function(mod)
  local PE = mod.exports.pokeEcology
  local C = {}
  local WEATHER_KEY = {
    [2] = "sun",
    [3] = "rain",
    [5] = "rain",
    [7] = "ash",
    [8] = "sandstorm",
    [12] = "sun",
    [13] = "rain",
  }
  function C.session()
    local ok, Runtime = pcall(require, "src.core.game3.runtime")
    if not ok or type(Runtime) ~= "table" then return nil end
    if type(Runtime.getSession) ~= "function" then return nil end
    local okS, s = pcall(Runtime.getSession)
    if not okS then return nil end
    return s
  end
  function C.mapId(hookCtx)
    if type(hookCtx) == "table" and hookCtx.mapId ~= nil then
      return hookCtx.mapId
    end
    local s = C.session()
    if type(s) == "table" and s.map ~= nil then return s.map end
    local okM, Map = pcall(require, "src.core.game3.map")
    if okM and type(Map) == "table" then return Map.current end
    return nil
  end
  function C.weather()
    local ok, Weather = pcall(require, "src.core.game3.weather")
    if not ok or type(Weather) ~= "table" then return "none" end
    local id = nil
    pcall(function()
      if type(Weather.get) == "function" then id = Weather.get() end
    end)
    id = math.floor(tonumber(id) or 0)
    return WEATHER_KEY[id] or "none", id
  end
  function C.clock()
    local s = C.session()
    local hour = nil
    local day = 0
    local rtcOk = false
    pcall(function()
      local Rtc = require("src.core.game3.rtc")
      if type(Rtc) == "table" and type(Rtc.enabled) == "function"
          and Rtc.enabled(s) and type(Rtc.calcLocalTime) == "function" then
        local t = Rtc.calcLocalTime(s)
        if type(t) == "table" then
          hour = tonumber(t.hours)
          day = math.floor(tonumber(t.days) or 0)
          rtcOk = true
        end
      end
    end)
    if hour == nil then
      pcall(function()
        if type(os) == "table" and type(os.date) == "function" then
          local d = os.date("*t")
          if type(d) == "table" then hour = tonumber(d.hour) end
        end
      end)
    end
    if not rtcOk then
      pcall(function()
        if type(os) == "table" and type(os.time) == "function" then
          day = math.floor(os.time() / 86400)
        end
      end)
    end
    if hour == nil then hour = 8 end
    hour = math.floor(hour) % 24
    return hour, day
  end
  function C.bucket(hour)
    return PE.bands.bucketFor(mod.exports.peBuckets, hour)
  end
  function C.seed()
    local v = nil
    pcall(function()
      if mod.save and type(mod.save.get) == "function" then v = mod.save:get("peSeed") end
    end)
    v = tostring(v or "")
    if v == "" or v == "nil" then
      local t = 0
      pcall(function()
        if type(os) == "table" and type(os.time) == "function" then t = os.time() end
      end)
      v = tostring(101 + (math.floor(tonumber(t) or 0) % 1000000))
      pcall(function()
        if mod.save and type(mod.save.set) == "function" then mod.save:set("peSeed", v) end
      end)
    end
    return v
  end
  function C.repelBlocks(level)
    local ok, F = pcall(require, "src.core.game3.field_semantics")
    local s = C.session()
    if not ok or type(F) ~= "table" or type(s) ~= "table" then return false end
    local steps = 0
    pcall(function()
      if type(F.getVar) == "function" then steps = tonumber(F.getVar(s, "repelSteps")) or 0 end
    end)
    if steps <= 0 then return false end
    local party = s.party
    if type(party) ~= "table" then return false end
    for i = 1, 6 do
      local mon = party[i]
      if type(mon) == "table" and (tonumber(mon.hp) or tonumber(mon.currentHp) or 1) > 0
          and not mon.isEgg and not mon.egg then
        return (tonumber(level) or 0) < (tonumber(mon.level) or 0)
      end
    end
    return false
  end
  PE.context = C
end
