--- HS010 engine lib
-- Engine params and functions.
--
local cs = require 'controlspec'
local util = require 'util'
local HS010 = {}

local function return_unchanged(s)
  return s
end

local function format_exp(i)
    return i - 1
end

local function _subtype(s)
  local retval = {"off", "-1 sqr", "-2 sqr", "-2 pul"}
  return retval[s+1]
end

local function _lfotype(s)
  local mix = {{0, "sin"}, {0.27, "tri"}, {0.54, "sqr"}, {0.8, "saw"}}
  retval = nil
  if s <= 0.8 then
    for k, v in pairs(mix) do
      if v[1] == s then
        retval = v[2]
        break
      end
    end
    if retval == nil then
      table.sort(mix, function(x, y)
        return math.abs(x[1] - s) < math.abs(y[1] - s)
      end)
      local gap_size = math.abs(mix[1][1] - mix[2][1])
      local right_v = math.floor((math.abs(s - mix[1][1]) / gap_size) * 100)
      local left_v = 100 - right_v
      retval = mix[1][2] .. "/" .. tostring(left_v) .. " " .. mix[2][2] .. "/" .. tostring(right_v)
    end
  elseif s < 0.9 then
    retval = "snh"
  else
    retval = "noise"
  end
  return retval
end

local function _res(s)
  return math.floor((1 - ((s - 0.2) / 1.3)) * 100) / 100
end

local function _envtype(s)
  local retval = {"env", "gate"}
  return retval[s+1]
end

local function _voicemode(s)
  local retval = {"mono", "uni", "poly"}
  return retval[s+1]
end

local function _monomode(s)
  local retval = {"legato", "retrig", "glide"}
  return retval[s+1]
end

local hs_specs = {
  {"sinelev", "Sine", 0, 1, "lin", 0.01, 0, 0.01, return_unchanged},
  {"trilev", "Triangle", 0, 1, "lin", 0.01, 0, 0.01, return_unchanged},
  {"sawlev", "Saw", 0, 1, "lin", 0.01, 1, 0.01, return_unchanged},
  {"pulselev", "Pulse", 0, 1, "lin", 0.01, 0, 0.01, return_unchanged},
  {"sublev", "Sub", 0, 1, "lin", 0.01, 0.3, 0.01, return_unchanged},
  {"noiselev", "Noise", 0, 1, "lin", 0.01, 0, 0.01, return_unchanged},
  {"subtype", "Sub Type", 0, 3, "lin", 1, 0, 1/3, _subtype},
  {"pw", "Pulsewidth", 0, 1, "lin", 0.01, 0.5, 0.01, return_unchanged},
  {"pwlfo", "LFO->PW", -1, 1, "lin", 0.01, 0, 0.01, return_unchanged},
  {"pitchlfo", "LFO->Pitch", 1, 18001, "exp", 1, 0, 0.01, format_exp},
  {"pwenv", "ENV->PW", -1, 1, "lin", 0.01, 0, 0.01, return_unchanged},
  {"lfosel", "LFO Type", 0, 1, "lin", 0.01, 0, 0.01, _lfotype},
  {"lfofreq", "LFO Freq", 0.1, 100, "lin", 0.1, 5, 0.1/(100-0.1), return_unchanged},
  {"lpf", "Cutoff", 20, 18000, "exp", 1, 400, 0.01, return_unchanged},
  {"lpq", "Resonance", 1.5, 0.2, "lin", 0.01, 1, 0.01, _res},
  {"lpflfo", "LFO->Cutoff", 1, 18001, "exp", 1, 100, 0.01, format_exp},
  {"lpfenv", "ENV->Cutoff", 1, 18001, "exp", 1, 500, 0.01, format_exp},
  {"lpfpitch", "Pitch->Cutoff", 0, 1, "lin", 0.01, 0, 0.01, return_unchanged},
  {"att", "Attack", 0.01, 10, "lin", 0.01, 0.01, 0.01/(10-0.01), return_unchanged},
  {"dec", "Decay", 0.01, 10, "lin", 0.01, 0.5, 0.01/(10-0.01), return_unchanged},
  {"sus", "Sustain", 0, 1, "lin", 0.01, 0.5, 0.01, 0.01, return_unchanged},
  {"rel", "Release", 0.01, 10, "lin", 0.01, 0.5, 0.01/(10-0.01), return_unchanged},
  {"crv", "Env. Curve", -6, 0, "lin", 1, -4, 0.01, return_unchanged},
  {"envtype", "Env. Type", 0, 1, "lin", 1, 0, 1, _envtype},
  {"unidetune", "Uni. Detune", 0, 10, "lin", 0.01, 0.1, 0.01/10, return_unchanged},
  {"voicemode", "Voice Mode", 0, 2, "lin", 1, 0, 1/2, _voicemode},
  {"monomode", "Mono Mode", 0, 2, "lin", 1, 0, 1/2, _monomode},
  {"pitchslide", "Glide", 0, 2, "lin", 0.1, 0, 0.01, return_unchanged},
  {"pan", "Pan", -1, 1, "lin", 0.05, 0, 0.01, return_unchanged},
  {"amp", "Volume", 0, 1, "lin", 0.01, 0.5, 0.01, return_unchanged},
  {"sendA", "Send A", 0, 1, "lin", 0.01, 0.0, 0.01, return_unchanged},
  {"sendB", "Send B", 0, 1, "lin", 0.01, 0.0, 0.01, return_unchanged}
}

HS010.pset_loc = _path.data .. 'hs010/presets/'

function HS010:add_params()

  params:add_separator ("HS010 engine")

  for _, val in ipairs(hs_specs) do
    local id = n(val[1])
    local vname = val[2]
    local vmin = val[3]
    local vmax = val[4]
    local scaling = val[5]
    local step = val[6]
    local default_val = val[7]
    local quantum = val[8]
    local vformatter = val[9]

    params:add {
      type = "control",
      id = id,
      name = vname,
      controlspec = cs.new(vmin, vmax, scaling, step, default_val, "", quantum),
      action = function(i)
        engine[val[1]](i)
      end,
      formatter = function(i)
        return tostring(vformatter(i:get()))
      end
    }
  end

end

function HS010.ret_list()
  return hs_specs
end

function HS010:save_pset(filename, preset)
  tab.save(preset, self.pset_loc .. filename)
end

function HS010:load_pset(filename)
  return tab.load(filename)
end

if not util.file_exists(HS010.pset_loc .. 'init') then
  print("Creating preset folder for HS010")
  local init_pset = {}
  util.make_dir(HS010.pset_loc)
  for _, val in ipairs(hs_specs) do
    init_pset[val[1]] = val[7]
  end
  tab.save(init_pset, HS010.pset_loc .. "init")
end

return HS010
