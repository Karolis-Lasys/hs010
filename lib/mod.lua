local mod = require 'core/mods'
local cs = require 'controlspec'
local textentry = require('textentry')
local hsparams = require 'hs010/lib/Engine_HS010'
local name = "hs010"
local selected_pset = ""

local function n(s)
  return name .. "_" .. s
end

local function format_exp(i)
  return i - 1
end

local function return_unchanged(s)
  return s
end

local function set_params_from_file(filename)
  local partab = hsparams:load_pset(filename)
  for key, val in pairs(partab) do
    params:set(n(key), val)
  end
end

local function save_params_to_file()
  textentry.enter(function(fname)
    if fname ~= nil then
      local pset_pars = {}
      local par_list = hsparams.ret_list()
      for _, val in ipairs(par_list) do
        local parval = params:get(n(val[1]))
        pset_pars[val[1]] = parval
      end
      hsparams:save_pset(fname, pset_pars)
    end
  end, tostring(os.date('%Y%m%d_%H_%M')), "Enter preset name")
end

local function add_hs010_params(reg)
    local par_list = hsparams.ret_list()
    params:add_group(n("group"), "hs010", #par_list + 8)
    params:hide(n("group"))
    params:add_separator(n("util"), "Utilities")
    params:add_trigger(n("refresh"), "Refresh Params")
    params:add_trigger(n("kill_midi"), "Stop All Playing Notes")
    params:set_action(n("refresh"), function(param)
      params:bang()
    end)
    params:set_action(n("kill_midi"), function(param)
      osc.send({ "localhost", 57120 }, "/hs010/note_off_all", {})
    end)
    params:add_separator(n("engine_par"), "Engine")
    for _, val in ipairs(par_list) do

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

      params:add_control(
        id,
        vname,
        cs.new(vmin, vmax, scaling, step, default_val, "", quantum),
        function(i)
          return tostring(vformatter(i:get()))
        end
      )
      table.insert(reg.parids, id)
      params:set_action(id, function(param)
        osc.send({ "localhost", 57120 }, "/hs010/" .. val[1], { vformatter(param) }) -- send param value
      end)
    end
    params:add_separator(n("presets"), "Presets")
    params:add_file(n("pselect"), "Select Preset", hsparams.pset_loc)
    params:set_action(n("pselect"), function(file)
      selected_pset = file
    end)
    params:add_trigger(n("pload"), "Load Preset")
    params:set_action(n("pload"), function(param)
      set_params_from_file(selected_pset)
    end)
    params:add_trigger(n("psave"), "Save Preset")
    params:set_action(n("psave"), function(param)
      save_params_to_file()
    end)
    _menu.rebuild_params()
end

function add_hs010_player()
    local player = {
      parids = {}
    }

    function player:active()
        if self.name ~= nil then
            params:show(n("group"))
            params:bang()
            _menu.rebuild_params()
        end
    end

    function player:inactive()
        if self.name ~= nil then
            params:hide(n("group"))
            _menu.rebuild_params()
        end
    end

    function player:modulate(val)
    end

    function player:set_slew(s)
    end

    function player:describe()
        return {
            name = "hs010",
            supports_bend = false,
            supports_slew = false,
            params = parids
        }
    end

    function player:pitch_bend(note, amount)
    end

    function player:modulate_note(note, key, value)
    end

    function player:note_on(note, vel, properties)
        local forceslide = false
        properties = properties or {}
        if properties.slide ~= nil then
          forceslide = properties.slide
        end
        osc.send({ "localhost", 57120 }, "/hs010/note_on", {
            note, -- note no
            vel, -- velocity
            forceslide -- is forced slide
        })
    end

    function player:note_off(note)
      osc.send({ "localhost", 57120 }, "/hs010/note_off", {
          note -- note no
      })
    end

    function player:add_params()
        add_hs010_params(self)
        params:bang()
    end

    function player:stop_all()
        osc.send({ "localhost", 57120 }, "/hs010/note_off_all", {})
    end

    if note_players == nil then
        note_players = {}
    end
    note_players["hs010"] = player
end

function pre_init()
    add_hs010_player() -- due to the nature of the engine, only one player is supported
end

mod.hook.register("script_pre_init", "hs010 pre init", pre_init)

mod.hook.register("script_post_init", "hs010 post init", function()
  params:bang()
end)

mod.hook.register("script_post_cleanup", "hs010 post cleanup", function()
      local p = note_players["hs010"]
      if p then
          p:stop_all()
      end
end)

mod.hook.register("system_pre_shutdown", "hs010 shutdown", function()
  osc.send({ "localhost", 57120 }, "/hs010/free_synth", {})
end)
