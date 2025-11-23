-- HS010
--
-- Happy Synthesis 010
-- lead and bass synthesizer
-- (with 6 voice polyphony)
-- and sequencer
--
-- Made by @onegin
--
-- E1 - select seq lane
-- E2 - select step
-- E3 - change step value
-- hold K1 - ALT
-- K2 - play/stop seq
-- K3 - reset playheads
-- A+E1 - lane length
-- A+E2 - lane clock div
-- A+E3 - lane modifier

-- prereqs
local lib_lat = require 'lattice'
local musicutil = require 'musicutil'
local s = require 'sequins'
local nb = require('hs010/lib/nb/lib/nb')
local util = require 'util'
local UI = require 'ui'
local hsdata = require('hs010/lib/hsdata') -- handling of seq data
local ku = require('hs010/lib/kutils/utility') -- generic utilities
local hsgrp = require('hs010/lib/hsgraphics') -- drawing on screen
local hsg = require('hs010/lib/hsgrid') -- grid stuff
local hsc = require('hs010/lib/hsconst') -- constant values
local player

-- globals
-- general stuff
local ALTKEY = false
local redraw_loop
-- sequencer stuff
local seqlat = lib_lat:new{}
local current_pattern = 1
local seq_table = {}
local note_const = {}
local notetab = 1
local cursor_idx = 1
local patchange_idx = 0
local patterns = hsdata.hspt:new()
-- scale stuff
local cur_scale = {}
local scale_name = "Phrygian"
local scale_root = 1

-- logic and such
function init()
  -- init nb
  nb:init()
  nb:add_param("voice_id", "voice_id")
  nb:add_player_params()
  -- init stuff
  init_const()
  init_scale("Phrygian", 1)
  init_seqs()
  -- init some screen stuff
  hsgrp.init()
  -- init grid
  hsg.init(patterns, seqlat)
  -- add params
  init_params()
  -- start lattice
  seqlat:start()
  -- set up encoder stuff
  norns.enc.sens(2, 3)
  -- set up midi transport
  clock.transport.start = function()
    seqlat:start()
  end
  clock.transport.stop = function()
    if seqlat.enabled then
      seqlat:stop()
    else
      reset_seqs()
    end
  end
  -- start redraw loop
  redraw_loop = metro.init(redraw_everything, 0.125, - 1)
  redraw_loop:start()
  -- init done!
end

function init_const()
  note_const = {}
  note_const.note = 1
  note_const.vel = 127
  note_const.oct = 36
  note_const.off_a = {0, false}
  note_const.off_b = {0, false}
  note_const.slide = false
  note_const.gate = true
end

function init_scale(name, root)
  scale_name = name
  scale_root = math.fmod(root - 1, 12)
  cur_scale = musicutil.generate_scale(scale_root, name, 1)
end

function redraw_everything()
  hsgrp.tick_frame()
  redraw()
  hsg.draw_grid(patterns, seqlat.enabled)
end

function reset_seqs()
  patterns:current():reset()
end

function init_params()

  local scalenames = {}
  for k,v in ipairs(musicutil.SCALES) do
    table.insert(scalenames, v.name)
  end

  -- scale stuff
  params:add_separator(hsc.n("scale"), "Scale")
  params:add_option(hsc.n("scale_name"), "Scale name", scalenames, 1)
  params:set_action(hsc.n("scale_name"),
    function(name)
      init_scale(name, scale_root + 1)
    end
  )
  params:add_option(hsc.n("root_note"), "Root note", musicutil.NOTE_NAMES, 1)
  params:set_action(hsc.n("root_note"),
    function(notename)
      init_scale(scale_name, notename)
    end
  )

  -- sequence lengths
  params:add_separator(hsc.n("seq_len"), "Sequence lengths")
  params:add_number(hsc.n("note_len"), "Note len", 1, 64, 8)
  params:set_action(hsc.n("note_len"), set_update_len("note"))
  params:add_number(hsc.n("vel_len"), "Velocity len", 1, 64, 8)
  params:set_action(hsc.n("vel_len"), set_update_len("vel"))
  params:add_number(hsc.n("oct_len"), "Octave len", 1, 64, 8)
  params:set_action(hsc.n("oct_len"), set_update_len("oct"))
  params:add_number(hsc.n("off_a_len"), "Offset A len", 1, 64, 8)
  params:set_action(hsc.n("off_a_len"), set_update_len("off_a"))
  params:add_number(hsc.n("off_b_len"), "Offset B len", 1, 64, 8)
  params:set_action(hsc.n("off_b_len"), set_update_len("off_b"))
  params:add_number(hsc.n("slide_len"), "Slide len", 1, 64, 8)
  params:set_action(hsc.n("slide_len"), set_update_len("slide"))
  params:add_number(hsc.n("gate_len"), "Gate len", 1, 64, 8)
  params:set_action(hsc.n("gate_len"), set_update_len("gate"))

  -- sequence divisions
  params:add_separator(hsc.n("seq_dev"), "Sequence pulse divisions")
  params:add_option(hsc.n("note_div"), "Note div", hsc.NOTELEN_STR, 5)
  params:set_action(hsc.n("note_div"), set_update_division("note"))
  params:add_option(hsc.n("vel_div"), "Velocity div", hsc.NOTELEN_STR, 5)
  params:set_action(hsc.n("vel_div"), set_update_division("vel"))
  params:add_option(hsc.n("oct_div"), "Octave div", hsc.NOTELEN_STR, 5)
  params:set_action(hsc.n("oct_div"), set_update_division("oct"))
  params:add_option(hsc.n("off_a_div"), "Offset A div", hsc.NOTELEN_STR, 5)
  params:set_action(hsc.n("off_a_div"), set_update_division("off_a"))
  params:add_option(hsc.n("off_b_div"), "Offset B div", hsc.NOTELEN_STR, 5)
  params:set_action(hsc.n("off_b_div"), set_update_division("off_b"))
  params:add_option(hsc.n("slide_div"), "Slide div", hsc.NOTELEN_STR, 5)
  params:set_action(hsc.n("slide_div"), set_update_division("slide"))
  params:add_option(hsc.n("gate_div"), "Gate div", hsc.NOTELEN_STR, 5)
  params:set_action(hsc.n("gate_div"), set_update_division("gate"))

  -- patterns
  params:add_separator(hsc.n("patset"), "Patterns")
  params:add_number(hsc.n("patchange_len"), "Pattern change len", 1, 64, 16)
  params:set_action(hsc.n("patchange_len"), function(val) patterns:current().plen = val end)
  params:add_option(hsc.n("patchange_div"), "Pattern change div", hsc.NOTELEN_STR, 3)
  params:set_action(hsc.n("patchange_div"), function(val)
    patterns:current().pdiv = val
    seq_table.pchange.division = hsc.NOTELEN[val]
  end)

  -- misc stuff
  params:add_separator(hsc.n("settings"), "Misc")
  params:add_number(hsc.n("vel_deviation"), "Velocity deviation", 0, 127, 16)

  params.action_write = function(psetfilename,psetname,psetnumber)
    local formatted_tables = {}
    local savepath = norns.state.data .. psetnumber .. ".n.txt"
    tab.save(patterns:serialize(), savepath)
  end

  params.action_read = function(psetfilename,psetsilent,psetnumber)
    local oldpath = norns.state.data .. psetnumber .. ".txt"
    local newpath = norns.state.data .. psetnumber .. ".n.txt"
    local datapath = norns.state.path .. "data/" .. psetnumber .. ".txt"
    local pread = false
    if util.file_exists(newpath) then
      local psett = tab.load(newpath)
      patterns:deserialise(psett)
      patterns:update_param()
      pread = true
    end
    if util.file_exists(datapath) and not pread then
      util.os_capture("mv " .. datapath .. " " .. oldpath)
    end
    if util.file_exists(oldpath) and not pread then
      local psett = tab.load(oldpath)
      patterns.cur = 1
      for _, v in pairs(patterns.pat) do
        v.init = false
      end
      patterns:current().init = true
      for k, v in pairs(psett) do
        patterns:current()[k].seq:settable(v)
      end
      patterns:update_param()
    end
  end

  params.action_delete = function(psetfilename,psetname,psetnumber)
    norns.system_cmd("rm -rf " .. norns.state.data .. psetnumber .. ".n.txt")
  end
end

function set_update_len(parname)
  return function(val)
    patterns:current()[parname]:shrink(val)
  end
end


function set_update_division(parname)
  return function(val)
      patterns:current()[parname].div = val
      seq_table[parname].division = hsc.NOTELEN[val]
  end
end

function init_seqs()
  seq_table.note = seqlat:new_sprocket{
    action = set_note,
    division = patterns:current().note:get_div(),
    enabled = true,
    order = 1
  }
  seq_table.vel = seqlat:new_sprocket{
    action = set_vel,
    division = patterns:current().vel:get_div(),
    enabled = true,
    order = 1
  }
  seq_table.oct = seqlat:new_sprocket{
    action = set_oct,
    division = patterns:current().oct:get_div(),
    enabled = true,
    order = 1
  }
  seq_table.off_a = seqlat:new_sprocket{
    action = set_a,
    division = patterns:current().off_a:get_div(),
    enabled = true,
    order = 1
  }
  seq_table.off_b = seqlat:new_sprocket{
    action = set_b,
    division = patterns:current().off_b:get_div(),
    enabled = true,
    order = 1
  }
  seq_table.slide = seqlat:new_sprocket{
    action = set_slide,
    division = patterns:current().slide:get_div(),
    enabled = true,
    order = 1
  }
  seq_table.gate = seqlat:new_sprocket{
    action = play_note,
    division = patterns:current().gate:get_div(),
    enabled = true,
    order = 2
  }
  seq_table.pchange = seqlat:new_sprocket{
    action = trig_pat_change,
    division = patterns:current():get_div(),
    enabled = true,
    order = 3
  }
  set_slide()
end

function trig_pat_change()
  patchange_idx = math.fmod(patchange_idx + 1, params:get(hsc.n("patchange_len")))
  if patchange_idx == 0 then
    if patterns.next ~= patterns:idx() and patterns.switching then
      patterns:set(patterns.next)
      patterns:reset()
      patterns.next = patterns:idx()
      patterns.switching = false
      patchange_idx = 0
    end
  end
end

function set_slide()
  note_const.slide = patterns:current().slide:next()
end

function set_note()
  note_const.note = patterns:current().note:next()
end

function set_vel()
  note_const.vel = util.clamp(patterns:current().vel:next() * 16, 0, 127)
end

function set_oct()
  note_const.oct = 12 * patterns:current().oct:next()
end

function set_a()
  note_const.off_a = patterns:current().off_a:next()
end

function set_b()
  note_const.off_b = patterns:current().off_b:next()
end

function play_note()
  local gate = patterns:current().gate:next()
  if gate then
    local poly_a = note_const.off_a[2]
    local poly_b = note_const.off_b[2]
    local root = ku.from_degree_to_note(note_const.note, cur_scale, false)
    local finalnote = root
    local off_a = note_const.off_a[1]
    local off_b = note_const.off_b[1]
    if not poly_a then
      finalnote = finalnote + off_a
    else
      format_and_play_note(root + off_a, params:get(hsc.n("vel_deviation")), note_const.oct, note_const.vel)
    end
    if not poly_b then
      finalnote = finalnote + off_b
    else
      format_and_play_note(root + off_b, params:get(hsc.n("vel_deviation")), note_const.oct, note_const.vel)
    end
    format_and_play_note(finalnote, 0, note_const.oct, note_const.vel, note_const.slide)
  end
end

function format_and_play_note(note, vdev, oct, vel, slide)
  local vd = math.min(127, math.max(math.random(-vdev, vdev) + vel, 0))
  local nnote = ku.scale_quant(note, cur_scale) + oct
  play_note_engine(nnote, vd, hsc.NOTELEN[params:get(hsc.n("gate_div"))], slide)
end

function play_note_engine(note, vel, note_time, slide)
  player = params:lookup_param("voice_id"):get_player()
  if slide then
    player:note_on(note, vel / 128)
  else
    player:play_note(note, vel / 128, note_time)
  end
end

function shrink_seq(name, newlen)
  patterns:current()[name]:shrink(newlen)
end

-- control logic
function key(nn, z)
  if nn == 1 and z == 1 then
    ALTKEY = true
  end
  if nn == 1 and z == 0 then
    ALTKEY = false
  end
  if nn == 2 and z == 1 then
    seqlat:toggle()
  end
  if nn == 3 and z == 1 then
    if notetab == 8 then
      patterns.switching = true
    else
      reset_seqs()
    end
  end
  redraw_screen()
end

function enc(nn, d)
  if nn == 1 then
    if ALTKEY and notetab ~= 8 then
      local arrname = hsc.ARRAYNAMES[notetab]
      params:delta(hsc.n(arrname .. "_len"), d)
    elseif ALTKEY and notetab == 8 then
      params:delta(hsc.n("patchange_len"), d)
    else
      notetab = util.wrap(notetab + d, 1, #hsc.ARRAYNAMES + 1)
    end
  end
  if nn == 2 then
    if ALTKEY and notetab ~= 8 then
      local arrname = hsc.ARRAYNAMES[notetab]
      params:delta(hsc.n(arrname .. "_div"), d)
    elseif ALTKEY and notetab == 8 then
      params:delta(hsc.n("patchange_div"), d)
    else
      if notetab == 8 then
        patterns.switching = false
        patterns.next = util.wrap(patterns.next + d, 1, 32)
      else
        cursor_idx = cursor_idx + d
      end
    end
  end
  if nn == 3 then
    if notetab == 8 then
      patterns.next = util.wrap(patterns.next + d, 1, 32)
      patterns.switching = true
    else
      local arrname = hsc.ARRAYNAMES[notetab]
      local curar = patterns:current()[arrname].seq.data
      local idx = util.wrap(cursor_idx, 1, #curar)
      if type(curar[idx]) == "number" then
        curar[idx] = util.wrap(curar[idx] + d, hsc.BOUNDS[notetab][1], hsc.BOUNDS[notetab][2])
      elseif type(curar[idx]) == "boolean" then
        curar[idx] = not curar[idx]
      else
        if ALTKEY then
          curar[idx][2] = not curar[idx][2]
        else
          curar[idx][1] = util.wrap(
            curar[idx][1] + d,
            hsc.BOUNDS[notetab][1],
            hsc.BOUNDS[notetab][2]
          )
        end
      end
    end
  end
  redraw_screen()
end

function redraw_screen()
  redraw()
end

function redraw()
  hsgrp.redraw_screen(patterns, seqlat, notetab, ALTKEY, cursor_idx)
end
