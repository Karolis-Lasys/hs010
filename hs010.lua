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
local util = require 'util'
local UI = require 'ui'
local player

-- consts
local CONST_NOTELEN = {1 / 64, 1 / 32, 1 / 24, 1 / 16, 1 / 12, 1 / 8, 1 / 6, 1 / 4, 1 / 3, 1 / 2, 3 / 4, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32}
local CONST_NOTELEN_STR = {"1/64", "1/32", "1/24", "1/16", "1/12", "1/8", "1/6", "1/4", "1/3", "1/2", "3/4", "1", "2", "3", "4", "6", "8", "12", "16", "24", "32"}
local CONST_W = 128
local CONST_H = 64
local CONST_LINEHEIGHT = 8
local CONST_ARRAYNAMES = {"note", "vel", "oct", "off_a", "off_b", "gate", "slide"}
local CONST_ARRDIS = {"Deg", "Vel", "Oct", "M-A", "M-B", "Gat", "Sld"}
local CONST_BOUNDS = {{1, 7}, {1, 8}, {1, 8}, {-12, 12}, {-12, 12}, {0, 0}, {0, 0}}

-- globals
-- general stuff
local ALTKEY = false
local redraw_loop
-- sequencer stuff
local seqlat = lib_lat:new{}
local note_table = {}
local prev_note_buf = {}
local seq_table = {}
local note_const = {}
local cur_scale = {}
local notetab = 1
local cursor_idx = 1
-- debugging stuff
debugscriptflag = false
-- scale stuff
local scale_name
local scale_root

-- various utility functions (move to other file)
function data_to_string(item)
  local ret = ""
  if type(item) == "table" then
    ret = ret .. "{"
    for k, v in pairs(item) do
      ret = ret .. k .. ": " .. data_to_string(v) .. " "
    end
    ret = ret .. "} "
  elseif type(item) == "boolean" then
    ret = item and "true" or "false"
  elseif type(item) == "function" then
    ret = "--function--"
  else
    ret = "" .. item
  end
  return ret
end

function printdeb(string)
  if debugscriptflag then print(string) end
end

function draw_note_array(bx, by, idx, selected, array, ismainnotes)
  -- vars
  local arrlen = #array
  local x = bx
  local y = by
  local lx = 0
  local ly = 0
  local doffset = 0
  local notes_to_draw = {}
  local idxpos = -1
  local selectedpos = -1

  -- form array
  if arrlen > 8 then
    local following = selected == -1 and idx or selected
    if following < 4 then
      doffset = 0
    elseif following > (arrlen - 4) then
      doffset = arrlen - 8
    else
      doffset = following - 4
    end
    notes_to_draw = {table.unpack(array, doffset + 1, doffset + 8)}
  else
    notes_to_draw = array
  end

  -- calc cursor pos
  if idx > doffset and idx < doffset + 9 then
    idxpos = idx - doffset
  end
  if selected ~= -1 then
    selectedpos = selected - doffset
  end

  local degrees = {}
  local drawlines = false
  local isarray = false
  local gates = {}
  if type(array[1]) == "number" then
    degrees = notes_to_draw
    drawlines = true
  elseif type(array[1]) == "boolean" then
    for k, v in ipairs(notes_to_draw) do
      degrees[k] = v and "X" or "0"
    end
  else
    isarray = true
    for k, v in ipairs(notes_to_draw) do
      degrees[k] = v[1]
      gates[k] = v[2]
    end
    drawlines = true
  end

  -- draw stuff
  for k, v in ipairs(degrees) do
    local off_y = 0
    local off_y_n = 0
    if drawlines then
      if isarray then
        off_y = v
        off_y_n = degrees[util.wrap(k + 1, 1, #degrees)]
      else
        off_y = notes_to_draw[k]
        off_y_n = notes_to_draw[util.wrap(k + 1, 1, #notes_to_draw)]
      end
    end
    screen.move(x, y - off_y)
    if isarray then
      if gates[k] then
        v = v .. "P"
      end
    end
    local width = screen.text_extents(v)
    if k ~= #degrees and drawlines then
      screen.level(5)
      screen.line_width(1)
      screen.line(x + 12, y - off_y_n)
      screen.stroke()
    end
    screen.move(x, y - off_y)
    screen.level(k ~= selectedpos and 0 or 1)
    screen.rect(x - (width + 2) / 2, y - 4-off_y, width + 2, 8)
    screen.fill()
    screen.move(x, y - off_y + 2)
    screen.level(k ~= idxpos and 4 or 15)
    screen.text_center(v)
    x = x + 12
  end
end

-- logic and such
function init()
  -- init nb
  nb:init()
  nb:add_param("voice_id", "voice_id")
  nb:add_player_params()
  -- init stuff
  init_const()
  init_scale("Phrygian", 1)
  init_tables()
  init_seqs()
  init_prev_bufs()
  -- init some screen stuff
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
  screen.font_size(CONST_LINEHEIGHT)
  screen.font_face(1)
  -- add params
  init_params()
  -- start lattice
  seqlat:start()
  -- set up encoder stuff
  norns.enc.sens(2, 3)
  -- start redraw loop
  redraw_loop = metro.init(redraw_screen, 0.25, - 1)
  redraw_loop:start()
  -- init done!
end

function n(name)
  return "hs_ohoneoh_seq_" .. name
end

function reset_seqs()
  for k, _ in pairs(note_table) do
    note_table[k]:reset()
  end
  set_slide()
end

function init_params()

  local scalenames = {}
  for k,v in ipairs(musicutil.SCALES) do
    table.insert(scalenames, v.name)
  end

  -- scale stuff
  params:add_separator(n("scale"), "Scale")
  params:add_option(n("scale_name"), "Scale name", scalenames, 1)
  params:set_action(n("scale_name"),
    function(name)
      init_scale(name, scale_root + 1)
    end
  )
  params:add_option(n("root_note"), "Root note", musicutil.NOTE_NAMES, 1)
  params:set_action(n("root_note"),
    function(notename)
      init_scale(scale_name, notename)
    end
  )

  -- sequence lengths
  params:add_separator(n("seq_len"), "Sequence lengths")
  params:add_number(n("note_len"), "Note len", 1, 64, 8)
  params:set_action(n("note_len"), set_update_len("note"))
  params:add_number(n("vel_len"), "Velocity len", 1, 64, 8)
  params:set_action(n("vel_len"), set_update_len("vel"))
  params:add_number(n("oct_len"), "Octave len", 1, 64, 8)
  params:set_action(n("oct_len"), set_update_len("oct"))
  params:add_number(n("off_a_len"), "Offset A len", 1, 64, 8)
  params:set_action(n("off_a_len"), set_update_len("off_a"))
  params:add_number(n("off_b_len"), "Offset B len", 1, 64, 8)
  params:set_action(n("off_b_len"), set_update_len("off_b"))
  params:add_number(n("slide_len"), "Slide len", 1, 64, 8)
  params:set_action(n("slide_len"), set_update_len("slide"))
  params:add_number(n("gate_len"), "Gate len", 1, 64, 8)
  params:set_action(n("gate_len"), set_update_len("gate"))

  -- sequence divisions
  params:add_separator(n("seq_dev"), "Sequence pulse divisions")
  params:add_option(n("note_div"), "Note div", CONST_NOTELEN_STR, 8)
  params:set_action(n("note_div"), set_update_division("note"))
  params:add_option(n("vel_div"), "Velocity div", CONST_NOTELEN_STR, 8)
  params:set_action(n("vel_div"), set_update_division("vel"))
  params:add_option(n("oct_div"), "Octave div", CONST_NOTELEN_STR, 8)
  params:set_action(n("oct_div"), set_update_division("oct"))
  params:add_option(n("off_a_div"), "Offset A div", CONST_NOTELEN_STR, 8)
  params:set_action(n("off_a_div"), set_update_division("off_a"))
  params:add_option(n("off_b_div"), "Offset B div", CONST_NOTELEN_STR, 8)
  params:set_action(n("off_b_div"), set_update_division("off_b"))
  params:add_option(n("slide_div"), "Slide div", CONST_NOTELEN_STR, 8)
  params:set_action(n("slide_div"), set_update_division("slide"))
  params:add_option(n("gate_div"), "Gate div", CONST_NOTELEN_STR, 8)
  params:set_action(n("gate_div"), set_update_division("gate"))

  -- misc stuff
  params:add_separator(n("settings"), "Misc")
  params:add_number(n("vel_deviation"), "Velocity deviation", 0, 127, 16)

  params.action_write = function(psetfilename,psetname,psetnumber)
    local formatted_tables = {}
    local savepath = norns.state.data .. psetnumber .. ".txt"
    for k, v in pairs(note_table) do
      formatted_tables[k] = {}
      for kk, vv in ipairs(v.data) do
        table.insert(formatted_tables[k], vv)
      end
    end
    tab.save(formatted_tables, savepath)
  end

  params.action_read = function(psetfilename,psetsilent,psetnumber)
    local formatted_tables = tab.load(norns.state.data .. psetnumber .. ".txt")
    for k, v in pairs(formatted_tables) do
      note_table[k]:settable(v)
    end
  end

  params.action_delete = function(psetfilename,psetname,psetnumber)
    norns.system_cmd("rm -rf " .. norns.state.data .. psetnumber .. ".txt")
  end

end

function set_update_len(parname)
  return function(val)
    shrink_seq(parname, val)
  end
end


function set_update_division(parname)
  return function(val)
      seq_table[parname]:set_division(CONST_NOTELEN[val])
  end
end

function init_prev_bufs()
  for k, v in pairs(note_const) do
    prev_note_buf[k] = {}
  end
end

function init_scale(name, root)
  scale_name = name
  scale_root = math.fmod(root - 1, 12)
  cur_scale = musicutil.generate_scale(scale_root, name, 1)
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
end

function init_tables()
  note_table = {}
  note_table.note = s{1, 2, 3, 4, 5, 6, 7, 6}
  note_table.vel = s{3, 7, 3, 5, 3, 4, 3, 7}
  note_table.oct = s{3, 3, 4, 3, 3, 2, 3, 3}
  note_table.off_a = s{{0, false}, {0, false}, {0, false}, {0, false}, {0, false}, {0, false}, {0, false}, {0, false}}
  note_table.off_b = s{{0, false}, {0, false}, {0, false}, {0, false}, {0, false}, {0, false}, {0, false}, {0, false}}
  note_table.gate = s{true, true, false, true, true, false, true, true}
  note_table.slide = s{false, false, false, false, false, false, false, true}
end

function init_seqs()
  seq_table.note = seqlat:new_sprocket{
    action = set_note,
    division = 1 / 4,
    enabled = true,
    order = 1
  }
  seq_table.vel = seqlat:new_sprocket{
    action = set_vel,
    division = 1 / 4,
    enabled = true,
    order = 1
  }
  seq_table.oct = seqlat:new_sprocket{
    action = set_oct,
    division = 1 / 4,
    enabled = true,
    order = 1
  }
  seq_table.off_a = seqlat:new_sprocket{
    action = set_a,
    division = 1 / 4,
    enabled = true,
    order = 1
  }
  seq_table.off_b = seqlat:new_sprocket{
    action = set_b,
    division = 1 / 4,
    enabled = true,
    order = 1
  }
  seq_table.slide = seqlat:new_sprocket{
    action = set_slide,
    division = 1 / 4,
    enabled = true,
    order = 1
  }
  seq_table.gate = seqlat:new_sprocket{
    action = play_note,
    division = 1 / 4,
    enabled = true,
    order = 2
  }
  set_slide()
end

function set_slide()
  note_const.slide = note_table.slide()
end

function set_note()
  note_const.note = note_table.note()
end

function set_vel()
  note_const.vel = util.clamp(note_table.vel() * 16, 0, 127)
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

function play_note()
  local gate = note_table.gate()
  if gate then
    local poly_a = note_const.off_a[2]
    local poly_b = note_const.off_b[2]
    local root = from_degree_to_note(note_const.note, false)
    local finalnote = root
    local off_a = note_const.off_a[1]
    local off_b = note_const.off_b[1]
    if not poly_a then
      finalnote = finalnote + off_a
    else
      format_and_play_note(root + off_a, params:get(n("vel_deviation")), note_const.oct, note_const.vel)
    end
    if not poly_b then
      finalnote = finalnote + off_b
    else
      format_and_play_note(root + off_b, params:get(n("vel_deviation")), note_const.oct, note_const.vel)
    end
    format_and_play_note(finalnote, 0, note_const.oct, note_const.vel, note_const.slide)
  end
end

function from_degree_to_note(idegree, purgeoct)
  local degree = idegree - 1
  local note_number = #cur_scale
  local degree_pure = math.fmod(degree, note_number)
  local degree_oct = 0
  if not purgeoct then
    local degree_oct = (degree - degree_pure) // note_number
  end
  return cur_scale[degree_pure + 1] + degree_oct * 12
end

function format_and_play_note(note, vdev, oct, vel, slide)
  local vd = math.min(127, math.max(math.random(-vdev, vdev) + vel, 0))
  local nnote = scale_quant(note) + oct
  play_note_engine(nnote, vd, CONST_NOTELEN[params:get(n("gate_div"))], slide)
end

function scale_quant(note)
  local fnote = math.fmod(math.min(math.max(note, 0), 127), 12)
  local oct = note - fnote
  return musicutil.snap_note_to_array(fnote, cur_scale) + oct
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
  local seq = note_table[name].data
  local num = newlen - tab.count(seq)
  if num > 0 then
    for x = 0, num - 1 do
      local val
      if type(seq[1]) == "table" then
        val = {}
        for k, v in pairs(seq[1]) do
          val[k] = v
        end
      else
        val = seq[1]
      end
      if #prev_note_buf[name] > 0 then
        val = table.remove(prev_note_buf[name])
      end
      table.insert(seq, val)
    end
  else
    for x = 0, math.abs(num) - 1 do
      if #seq > 1 then
        table.insert(prev_note_buf[name], table.remove(seq))
      end
    end
  end
  note_table[name]:settable(seq)
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
    reset_seqs()
  end
  redraw_screen()
end

function enc(nn, d)
  if nn == 1 then
    if ALTKEY then
      local arrname = CONST_ARRAYNAMES[notetab]
      params:delta(n(arrname .. "_len"), d)
    else
      notetab = util.wrap(notetab + d, 1, #CONST_ARRAYNAMES)
    end
  end
  if nn == 2 then
    if ALTKEY then
      local arrname = CONST_ARRAYNAMES[notetab]
      local curdiv = tab.key(CONST_NOTELEN, seq_table[arrname].division)
      params:delta(n(arrname .. "_div"), d)
    else
      cursor_idx = cursor_idx + d
    end
  end
  if nn == 3 then
    local arrname = CONST_ARRAYNAMES[notetab]
    local idx = util.wrap(cursor_idx, 1, #note_table[arrname])
    if type(note_table[arrname][idx]) == "number" then
      note_table[arrname][idx] = util.wrap(note_table[arrname][idx] + d, CONST_BOUNDS[notetab][1], CONST_BOUNDS[notetab][2])
    elseif type(note_table[arrname][idx]) == "boolean" then
      note_table[arrname][idx] = not note_table[arrname][idx]
    else
      if ALTKEY then
        note_table[arrname][idx][2] = not note_table[arrname][idx][2]
      else
        note_table[arrname][idx][1] = util.wrap(
          note_table[arrname][idx][1] + d,
          CONST_BOUNDS[notetab][1],
          CONST_BOUNDS[notetab][2]
        )
      end
    end
  end
  redraw_screen()
end

function redraw_screen()
  redraw()
end

-- norns screen is 128 by 64 pixels
function redraw()
  screen.clear()
  local todraw = {}
  local arraynames = #CONST_ARRAYNAMES
  if notetab == 1 then
    todraw = {{false, 0}, {CONST_ARRAYNAMES[1], 1}, {CONST_ARRAYNAMES[2], 2}}
  elseif notetab == arraynames then
    todraw = {
      {CONST_ARRAYNAMES[arraynames - 1], arraynames - 1},
      {CONST_ARRAYNAMES[arraynames], arraynames},
      {false, 0}
    }
  else
    todraw = {
      {CONST_ARRAYNAMES[notetab - 1], notetab - 1},
      {CONST_ARRAYNAMES[notetab], notetab},
      {CONST_ARRAYNAMES[notetab + 1], notetab + 1}
    }
  end

  local selector = 0
  for k, v in ipairs(todraw) do
    if v[1] ~= false then
      screen.move(5, k * 18)
      screen.level(selector == 1 and 10 or 1)
      screen.text(CONST_ARRDIS[v[2]] .. ":")
      draw_note_array(
        26,
        k * 18,
        note_table[v[1]].ix,
        util.wrap(cursor_idx, 1, #note_table[v[1]]),
        note_table[v[1]],
        v[2] == 1
      )
    end
    selector = selector + 1
  end

  if ALTKEY then
    local lenstr = "alt/" .. #note_table[todraw[2][1]]
    local pulstr = (seqlat.enabled and "stop" or "play") .. "/" .. CONST_NOTELEN_STR[params:get(n(todraw[2][1] .. "_div"))]
    local synstr = "rst/" .. (type(note_table[todraw[2][1]][1]) == "table" and "poly" or "----")
    screen.move(124, 8)
    screen.rect(124, 8, - (screen.text_extents(lenstr) + 4), 12)
    screen.level(0)
    screen.fill()
    screen.level(15)
    screen.move(122, 10)
    screen.text_right(lenstr)
    screen.move(4, 61)
    screen.rect(4, 61, screen.text_extents(pulstr) + 4, 12)
    screen.level(0)
    screen.fill()
    screen.level(15)
    screen.move(6, 63)
    screen.text(pulstr)
    screen.move(120, 61)
    screen.rect(120, 61, screen.text_extents(synstr) + 4, 12)
    screen.level(0)
    screen.fill()
    screen.level(15)
    screen.move(122, 63)
    screen.text_right(synstr)
  end
  screen.update()
end
