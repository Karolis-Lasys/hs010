-- HS010
--
-- Happy Synthesis 010
-- lead and bass synthesizer
-- (with 6 voice polyphony)
-- and sequencer
--
-- Made by @onegin

-- prereqs
local metro = require 'metro'
local clock = require 'clock'
local er = require 'er'
local lattace = require 'lattice'
local musicutil = require 'musicutil'
local s = require 'sequins'
local HS010 = require 'hs010/lib/Engine_HS010'
local player

-- globals
local lat, tab, note_len, redraw_loop, screen_dirty;
local note_table = {}
local seq_table = {}
local note_const = {}
local cur_scale = {}
local scale_name, scale_root

-- logic and such
function init()
  -- init nb
  nb:init()
  nb:add_param("voice_id", "voice_id")
  nb:add_player_params()
  clock.run(function()
    clock.sleep(2)
    params:bang()
  end)
  -- start redraw loop
  redraw_loop = metro.init(redraw, 0.1, -1)
  redraw_loop:start()
  -- init default note len
  note_len = 1/16
  -- init lattaces
  lat = lib_lat:new()
  -- init stuff
  init_const()
  init_tables()
  init_seqs()
  init_scale("Phrygian", 60)
  -- start the sequencer
  lat:start()
  screen_dirty = true
end

function init_scale(name, root)
    scale_name = name
    scale_root = math.fmod(root, 12)
    cur_scale = MusicUtil.generate_scale(root, name, 1)
end

function init_const()
  note_const = {};
  note_const.note = 0
  note_const.vel = 127
  note_const.oct = 3
  note_const.off_a = 0
  note_const.off_b = 0
  note_const.slide = false
end

function init_tables()
  note_table = {};
  note_table.note = s{0,0,0,0,0,0,0,0}
  note_table.vel = s{127, 80}
  note_table.oct = s{3, 3, 4, 3}
  note_table.off_a = s{{0, false}, {5, false}, {3, false}, {12, false}}
  note_table.off_b = s{{0, false}}
  note_table.gate = s{true}
  note_table.slide = s{false}
end

function init_seqs()
  seq_table.note = lat:new_sprocket{
    action = set_note()
    division = 1/4
    enabled = true
    order = 1
  }
  seq_table.vel = lat:new_sprocket{
    action = set_vel()
    division = 1/4
    enabled = true
    order = 2
  }
  seq_table.oct = lat:new_sprocket{
    action = set_oct()
    division = 1/4
    enabled = true
    order = 3
  }
  seq_table.off_a = lat:new_sprocket{
    action = set_a()
    division = 1/4
    enabled = true
    order = 4
  }
  seq_table.off_b = lat:new_sprocket{
    action = set_b()
    division = 1/4
    enabled = true
    order = 5
  }
  seq_table.slide = lat:new_sprocket{
    action = set_slide()
    division = 1/4
    enabled = true
    order = 6
  }
  seq_table.gate = lat:new_sprocket{
    action = play_note()
    division = 1/4
    enabled = true
    order = 7
  }
end

function set_slide()
  note_const.slide = note_table.slide()
end

function set_note()
  note_const.note = note_table.note()
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

function set_note()
  note_const.off_b = note_table.off_b()
end

-- implement ties
function play_note()
  local gate = note_table.gate()
  if gate then
    local note = {}
    local poly_a = note_const.off_a[2]
    local poly_a = note_const.off_b[2]
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
end

function format_and_play_note(note, vdev, oct, vel)
  local add_oct = note - fnote
  local vd = math.min(127, math.abs(math.random(-vdev, vdev) + vel))
  local nnote = scale_quant(note, oct)
  play_note_engine(nnote, vd, note_len)
end

function scale_quant(note)
  local fnote = math.fmod(math.min(math.max(note, 0), 127), 12)
  local oct = note - fnote
  return musicutil.snap_note_to_array(fnote, cur_scale) + oct
end

function play_note_engine(note, vel, note_time)
  player = params:lookup_param("voice_id"):get_player()
  player:play_note(note, vel/128, note_time)
end

-- control logic
function key(n,z)
  if n == 3 and z == 1 then
    engine.noteOffAll();
    lat:toggle()
  end
end

function redraw()
  if screen_dirty then
    screen.clear()

    screen_dirty = false
    screen.update()
  end
end
