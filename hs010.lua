-- HS010
--
-- Happy Synthesis 010
-- lead and bass synthesizer
-- (with 6 voice polyphony)
-- and sequencer
--
-- Made by @onegin


-- set engine name
engine.name = 'HS010'

-- prereqs
local metro = require 'metro'
local clock = require 'clock'
local er = require 'er'
local lattace = require 'lattice'
local musicutil = require 'musicutil'
local HS010 = require 'hs010/lib/Engine_HS010'

-- globals
local lat, tab, seq_a, seq_b, note_len, redraw_loop, screen_dirty;

-- data structures

-- note cell
local Note = {}

function Note:new(note_no = 60, note_len = 1, note_pat = 0, note_vel = 100, note_vel_drift = 0)
  new_note = {
    note_id = note_no, -- note no.
    note_len = note_len, -- amount of repeats
    note_pat = note_pat, -- 0 to 7 with 7 being a tie
    note_vel = note_vel, -- default velocity
    note_vel_drift = note_vel_drift, -- velocity drift
    note_idx = 0, -- index of playing note within pattern
    note_pat = {} -- final note pattern
  }
  self.__index = self
  self:gen_pat()
  return setmetatable(new_note, self)
end

function Note:change_len(new_len)
  self.note_len = new_len
  self:gen_pat()
end

function Note:gen_pat()
  if note_pat == 0 then
    self.note_pat = er.gen(0, note_len, 0)
  elseif note_pat == 1 then
    self.note_pat = er.gen(1, note_len, 0)
  elseif note_pat == 2 then
    self.note_pat = er.gen(note_len, note_len, 0)
  elseif note_pat == 3 then
    self.note_pat = er.gen(math.ceil(note_len / 2), note_len, 0)
  elseif note_pat = 4 then
    self.note_pat = er.gen(math.ceil(note_len / 3), note_len, 0)
  elseif note_pat = 5 then
    self.note_pat = er.gen(math.ceil(note_len / 4), note_len, 0)
  elseif note_pat = 6 then
    self.note_pat = er.gen(math.random(note_len), note_len, math.random(note_len))
  elseif note_pat = 7 then -- edge case for tie
    self.note_pat = er.gen(1, note_len, 0)
  end

  for k, v in ipairs(self.note_pat) do
    if v then
      local tie = note_pat == 7
      self.note_pat[k] = Note.gen_midinote(
        self.note_id,
        self.note_vel + math.random(-self.note_vel_drift, self.note_vel_drift),
        tie
      )
    else
      self.note_pat[k] = Note.gen_midinote(self.note_id, 0)
    end
  end
end

function Note:get_note()
  local note = self.note_pat[self.idx + 1]
  self.idx = self.idx + 1
  self.idx = math.fmod(self.idx, note_len)
  return note
end

function Note:advance()
  return self.idx == 0
end

function Note.gen_silent()
  return Note.gen_midinote(0, 0, false)
end

function Note.gen_midinote(note_no, note_vel, tie = false)
  return {note_no, note_vel, tie}
end


-- sequencer note table
local Note_Table = {}

function Note_Table:new()
  new_table = {
    table = {},
    split_index = 8,
    idx_a = 0,
    idx_b = 7,
    tab_len = 8
  }
  for i = 1, new_table.tab_len do
    new_table.table[i] = Note:new();
  end
  self.__index = self
  return setmetatable(new_note, self)
end

function Note_Table:get_note(which)
  local note;

  if which == 1 then
    if self.split_idx != 0 then
      local supernote = self.table[self.idx_a]
      note = supernote:get_note()
      if supernote:advance() then
        self.idx_a = self.idx_a + 1
        self.idx_a = math.fmod(self.idx_a, split_index)
      end
    else
      note = Note.gen_silent()
    end
  else then
    if self.split_idx != 8 then
      local supernote = self.table[self.idx_b]
      note = supernote:get_note()
      if supernote:advance() then
        self.idx_b = self.idx_a + 1
        self.idx_b = split_index + math.fmod(self.idx_b - split_index, tab_len - split_index)
      else
    else
      note = Note.gen_silent()
    end
  end

  return note;
end

-- sequencer logic
function init()
  -- add engine params
  HS010.add_params()
  -- start redraw loop
  redraw_loop = metro.init(redraw, 0.1, -1)
  redraw_loop:start()
  -- init default note len
  note_len = 1/16
  -- init seq a and seq b lattace
  lat = lib_lat:new()
  -- init note table
  tab = Note_table:new()
  -- init seq a and seq b
  seq_a = lat:new_sprocket{
    action = play_note_a()
    division = 1/4
    enabled = true
  }
  seq_b = lat:new_sprocket{
    action = play_note_b()
    division = 1/4
    enabled = true
  }
  -- start the sequencer
  lat:start()
  screen_dirty = true
end

function play_note_a()
  local note = tab:get_note(1)
  play_note(note)
end

function play_note_b()
  local note = tab:get_note(2)
  play_note(note)
end

function play_note(note)
  engine.noteOn(note[0], note[1]/128)
  clock.run(end_note, note[0], note_len)
end

function end_note(note, note_len)
  clock.sync(note_len)
  engine.noteOff(note);
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
