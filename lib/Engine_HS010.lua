--- HS010 engine lib
-- Engine params and functions.
--
local cs = require 'controlspec'
local HS010 = {}
local hs_specs = {
  {"sinelev", "Sine", 0, 1, "lin", 0.01, 0, 0.01},
  {"trilev", "Triangle", 0, 1, "lin", 0.01, 0, 0.01},
  {"sawlev", "Saw", 0, 1, "lin", 0.01, 1, 0.01},
  {"pulselev", "Pulse", 0, 1, "lin", 0.01, 0, 0.01},
  {"sublev", "Sub", 0, 1, "lin", 0.01, 0.3, 0.01},
  {"noiselev", "Noise", 0, 1, "lin", 0.01, 0, 0.01},
  {"subtype", "Sub Type", 0, 3, "lin", 1, 0, 1/3},
  {"pw", "Pulsewidth", 0, 1, "lin", 0.01, 0.5, 0.01},
  {"pwlfo", "LFO->PW", -1, 1, "lin", 0.01, 0, 0.01},
  {"pitchlfo", "LFO->Pitch", 1, 20001, "exp", 1, 0, 0.01},
  {"pwenv", "ENV->PW", -1, 1, "lin", 0.01, 0, 0.01},
  {"lfosel", "LFO Type", 0, 1, "lin", 0.01, 0, 0.01},
  {"lfofreq", "LFO Freq", 0.1, 100, "lin", 0.1, 5, 0.1/(100-0.1)},
  {"lpf", "Cutoff", 20, 20000, "exp", 1, 400, 0.01},
  {"lpq", "Resonance", 0.05, 1.5, "lin", 0.01, 1, 0.01},
  {"lpflfo", "LFO->Cutoff", 1, 20001, "exp", 1, 100, 0.01},
  {"lpfenv", "ENV->Cutoff", 1, 20001, "exp", 1, 500, 0.01},
  {"lpfpitch", "Pitch->Cutoff", 0, 1, "lin", 0.01, 0, 0.01},
  {"att", "Attack", 0.01, 10, "lin", 0.01, 0.01, 0.01/(10-0.01)},
  {"dec", "Decay", 0.01, 10, "lin", 0.01, 0.5, 0.01/(10-0.01)},
  {"sus", "Sustain", 0, 1, "lin", 0.01, 0.5, 0.01, 0.01},
  {"rel", "Release", 0.01, 10, "lin", 0.01, 0.5, 0.01/(10-0.01)},
  {"crv", "Env. Curve", -6, 0, "lin", 1, -4, 0.01},
  {"envtype", "Env. Type", 0, 1, "lin", 1, 0, 1},
  {"unidetune", "Uni. Detune", 0, 10, "lin", 0.01, 0.1, 0.01/10},
  {"voicemode", "Voice Mode", 0, 2, "lin", 1, 0, 1/2},
  {"monomode", "Mono Mode", 0, 2, "lin", 1, 0, 1/2},
  {"pitchslide", "Glide", 0, 2, "lin", 0.1, x0, 0.01},
  {"pan", "Pan", -1, 1, "lin", 0.05, 0, 0.01},
  {"amp", "Volume", 0, 1, "lin", 0.01, 0.5, 0.01},
  {"sendA", "Send A", 0, 1, "lin", 0.01, 0.0, 0.01},
  {"sendB", "Send B", 0, 1, "lin", 0.01, 0.0, 0.01}
}

HS010.pset_loc = _path.data .. 'hs010/presets/'

local function format_exp(i)
    return i - 1
end

local function return_unchanged(s)
  return s
end

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
    local vformatter = return_unchanged

    if vmin == 1 and scaling == "exp" then
      vformatter = format_exp
    end

    params:add {
      type = "control",
      id = id,
      name = vname,
      controlspec = cs.new(vmin, vmax, scaling, step, default_val, "", quantum),
      action = function(i)
        engine[val[1]](vformatter(i))
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
