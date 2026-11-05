return function(mod)
  local PE = mod.exports.pokeEcology
  local U = {}
  local function opt(key, dflt)
    local v = dflt
    pcall(function()
      if mod.options and type(mod.options.get) == "function" then
        v = mod.options:get(key)
      end
    end)
    return v
  end
  function U.on()
    return opt("urtc", false) == true
  end
  function U.hourLen()
    local h = math.floor(tonumber(opt("urtc_hour", "2")) or 2)
    if h < 1 then h = 1 end
    if h > 8 then h = 8 end
    return h
  end
  local function wallNow()
    local t = nil
    pcall(function()
      if type(os) == "table" and type(os.time) == "function" then
        t = os.time()
      end
    end)
    return math.floor(tonumber(t) or 0)
  end
  local function anchorGet()
    local a = nil
    pcall(function()
      if mod.save and type(mod.save.get) == "function" then
        a = mod.save:get("peUrtc", nil)
      end
    end)
    return a
  end
  local function anchorSet(a)
    pcall(function()
      if mod.save and type(mod.save.set) == "function" then
        mod.save:set("peUrtc", a)
      end
    end)
  end
  local function toLinear(Rtc, info)
    local f = {
      year = 2000 + math.floor(tonumber(info.year) or 0),
      month = math.floor(tonumber(info.month) or 1),
      day = math.floor(tonumber(info.day) or 1),
      hour = math.floor(tonumber(info.hour) or 0),
      minute = math.floor(tonumber(info.minute) or 0),
      second = math.floor(tonumber(info.second) or 0),
    }
    if type(Rtc) == "table" and type(Rtc._linearOf) == "function" then
      local ok, v = pcall(Rtc._linearOf, f)
      if ok and tonumber(v) ~= nil then return math.floor(v) end
    end
    return (((((f.year * 12 + (f.month - 1)) * 31 + (f.day - 1)) * 24
      + f.hour) * 60 + f.minute) * 60 + f.second)
  end
  local function fromLinear(Rtc, total)
    total = math.floor(tonumber(total) or 0)
    if type(Rtc) == "table" and type(Rtc._fieldsOf) == "function" then
      local ok, f = pcall(Rtc._fieldsOf, total)
      if ok and type(f) == "table" then
        return {
          year = math.floor(tonumber(f.year) or 2000) - 2000,
          month = math.floor(tonumber(f.month) or 1),
          day = math.floor(tonumber(f.day) or 1),
          hour = math.floor(tonumber(f.hour) or 0),
          minute = math.floor(tonumber(f.minute) or 0),
          second = math.floor(tonumber(f.second) or 0),
        }
      end
    end
    local s = total
    local sec = s % 60
    s = (s - sec) / 60
    local mi = s % 60
    s = (s - mi) / 60
    local h = s % 24
    s = (s - h) / 24
    local d = s % 31
    s = (s - d) / 31
    local mo = s % 12
    local y = (s - mo) / 12
    return { year = y, month = mo + 1, day = d + 1, hour = h, minute = mi, second = sec }
  end
  local function rtcBroken(Rtc)
    local bad = false
    pcall(function()
      if type(Rtc) == "table" and type(Rtc.errorStatus) == "function"
          and type(Rtc.ERR) == "table" and tonumber(Rtc.ERR.FLAG_MASK) ~= nil
          and type(bit) == "table" and type(bit.band) == "function" then
        bad = bit.band(Rtc.errorStatus(), Rtc.ERR.FLAG_MASK) ~= 0
      end
    end)
    return bad
  end
  local function anchorNow(Rtc, orig, session)
    local info = orig(session)
    if type(info) ~= "table" then return nil end
    local a = { wall = wallNow(), base = toLinear(Rtc, info), hourLen = U.hourLen() }
    anchorSet(a)
    return a
  end
  local function shifted(Rtc, orig, session)
    local h = U.hourLen()
    local a = anchorGet()
    if type(a) ~= "table" or tonumber(a.base) == nil or tonumber(a.wall) == nil
        or math.floor(tonumber(a.hourLen) or 0) ~= h then
      a = anchorNow(Rtc, orig, session)
      if a == nil then return orig(session) end
    end
    local el = wallNow() - math.floor(a.wall)
    if el < 0 then el = 0 end
    return fromLinear(Rtc, math.floor(a.base) + el * 60 / math.floor(a.hourLen))
  end
  function U.ensure()
    local Rtc = nil
    pcall(function() Rtc = require("src.core.game3.rtc") end)
    if type(Rtc) ~= "table" then return false end
    if type(Rtc.getInfo) ~= "function" then return false end
    local orig = Rtc.__peUrtcOrig
    if Rtc.__peUrtcWrapped == true and type(orig) == "function" then return true end
    if type(orig) ~= "function" then orig = Rtc.getInfo end
    Rtc.__peUrtcOrig = orig
    Rtc.getInfo = function(session)
      if not U.on() then return orig(session) end
      if rtcBroken(Rtc) then return orig(session) end
      local ok, info = pcall(shifted, Rtc, orig, session)
      if not ok or type(info) ~= "table" then return orig(session) end
      return info
    end
    Rtc.__peUrtcWrapped = true
    return true
  end
  PE.urtc = U
  U.ensure()
end
