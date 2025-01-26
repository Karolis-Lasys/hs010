-- HS010
--
-- Happy Synthesis 010
-- lead and bass synthesizer
-- (with 6 voice polyphony)
-- and sequencer
--
-- Made by @onegin

-- prereqs
local lib_lat = require 'lattice'
local musicutil = require 'musicutil'
local s = require 'sequins'
local nb = require('hs010/lib/nb/lib/nb')
local player

-- globals
local lat = lib_lat:new{}
local debugflag = true
local tab, note_len = 1/16, redraw_loop, screen_dirty
local note_table = {}
local seq_table = {}
local note_const = {}
local cur_scale = {}
local scale_name, scale_root

-- various utility functions (move to other file)
function data_to_string(item)
  local ret = ""
  if type(item) == "table" then
    ret = ret .. "{"
    for k, v in pairs(item) do
      ret = ret .. k .. ": " .. data_to_string(v) .. ", "
    end
    ret = ret .. "}, "
  elseif type(item) == "boolean" then
    ret = item and "true" or "false"
  else
    ret = "" .. item
  end
  return ret
end

function printdeb(string)
  if debugflag then print(string) end
end

-- logic and such
function init()
  -- init nb
  nb:init()
  nb:add_param("voice_id", "voice_id")
  nb:add_player_params()
  -- init stuff
  init_const()
  init_scale("Phrygian", note_const.note)
  init_tables()
  init_seqs()
  -- start lattice
  lat:start()
  -- set screen flag
  screen_dirty = true
  -- start draw loop
  redraw_loop = metro.init(redraw, 0.5, -1)
  redraw_loop:start()
  printdeb("init done")
end

function init_scale(name, root)
  scale_name = name
  scale_root = math.fmod(root, 12)
  cur_scale = musicutil.generate_scale(root, name, 1)
  printdeb("init scale" .. name)
end

function init_const()
  note_const = {}
  note_const.note = 0
  note_const.vel = 127
  note_const.oct = 36
  note_const.off_a = {0, false}
  note_const.off_b = {0, false}
  note_const.slide = false
  note_const.gate = true
  printdeb("init const: " .. data_to_string(note_const))
end

function init_tables()
  note_table = {}
  note_table.note = s{1,2,3,4,5,6,7,8}
  note_table.vel = s{127, 80}
  note_table.oct = s{3, 3, 4, 3}
  note_table.off_a = s{{0, false}, {5, false}, {3, false}, {12, false}}
  note_table.off_b = s{{0, false}}
  note_table.gate = s{true}
  note_table.slide = s{false}
  printdeb("init sequins: " .. data_to_string(note_table))
end

function init_seqs()
  seq_table.note = lat:new_sprocket{
    action = set_note(),
    division = 1/4,
    enabled = true,
    order = 1
  }
  seq_table.vel = lat:new_sprocket{
    action = set_vel(),
    division = 1/4,
    enabled = true,
    order = 1
  }
  seq_table.oct = lat:new_sprocket{
    action = set_oct(),
    division = 1/4,
    enabled = true,
    order = 1
  }
  seq_table.off_a = lat:new_sprocket{
    action = set_a(),
    division = 1/4,
    enabled = true,
    order = 1
  }
  seq_table.off_b = lat:new_sprocket{
    action = set_b(),
    division = 1/4,
    enabled = true,
    order = 1
  }
  seq_table.slide = lat:new_sprocket{
    action = set_slide(),
    division = 1/4,
    enabled = true,
    order = 1
  }
  seq_table.gate = lat:new_sprocket{
    action = play_note(),
    division = 1/4,
    enabled = true,
    order = 2
  }
end

function set_slide()
  note_const.slide = note_table.slide()
end

function set_note()
  note_const.note = note_table.note()
  printdeb("set note " .. note_const.note)
end

function set_vel()
  note_const.vel = note_table.vel()
end

function set_oct()
  note_const.oct = note_table.oct() * 12
end

function set_a()
  note_const.off_a = note_table.off_a()
end

function set_b()
  note_const.off_b = note_table.off_b()
end

-- implement ties
function play_note()
  printdeb("playing note")
  local gate = note_table.gate()
  if gate then
    local note = {}
    local poly_a = note_const.off_a[2]
    local poly_b = note_const.off_b[2]
    note[1] = note_const.note
    note[2] = note_const.off_a[1]
    note[3] = note_const.off_b[1]
    if not poly_a then
      note[1] = note[1] + note[2]
    else
      format_and_play_note(note[2], velocity_dev, note_const.oct, note_const.vel)
    end
    if not poly_b then
      note[1] = note[1] + note[3]
    else
      format_and_play_note(note[3], velocity_dev, note_const.oct, note_const.vel)
    end
    format_and_play_note(note[1], 0, note_const.oct, note_const.vel)
  end
  screen_dirty = true
end

function format_and_play_note(note, vdev, oct, vel)
  local vd = math.min(127, math.abs(math.random(-vdev, vdev) + vel))
  local nnote = scale_quant(note) + oct
  play_note_engine(nnote, vd, 1/16)
end

function scale_quant(note)
  local fnote = math.fmod(math.min(math.max(note, 0), 127), 12)
  local oct = note - fnote
  return musicutil.snap_note_to_array(fnote, cur_scale) + oct
end

function play_note_engine(note, vel, note_time)
  printdeb(note .. " " .. vel .. " " .. note_time)
  player = params:lookup_param("voice_id"):get_player()
  player:play_note(note, vel/128, note_time)
end

-- control logic
function key(n,z)
  if n == 3 and z == 1 then
    lat:toggle()
  end
end

function redraw(stage)
  screen_dirty = true
  if screen_dirty then
    local ofs = 20
    screen.clear()
    screen.move(10, 8)
    screen.text(lat.transport)
    screen.move(10, 14)
    screen.text(lat.enabled and "yes" or "no")
    for k, v in pairs(note_const) do
      screen.move(10, ofs)
      screen.text(k .. " " .. data_to_string(v))
      ofs = ofs + 6
    end
    screen_dirty = false
    screen.update()
  end
end

-- start redraw loop (for some reason doesn't work in init function)
-- the redraw loop somehow works here but not when started within the init function
-- redraw_loop = metro.init(redraw, 0.5, -1)
-- redraw_loop:start()
