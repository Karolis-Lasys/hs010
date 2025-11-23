-- module
local HSGRP = {}
local hsc = require('hs010/lib/hsconst')

-- private functions
-- drawing note array data to screen
local function draw_note_array(bx, by, idx, selected, array)
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

-- public variables
HSGRP.frame = 0

-- public functions
function HSGRP.init()
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
  screen.font_size(hsc.LINEHEIGHT)
  screen.font_face(1)
  HSGRP.frame = 0
end

function HSGRP.tick_frame()
  HSGRP.frame = HSGRP.frame + 1
  if HSGRP.frame > 254 then HSGRP.frame = 0 end
end

function HSGRP.redraw_screen(data, seqlat, notetab, ALTKEY, cursor_idx)
  screen.clear()
  local todraw = {}
  local arrn = #hsc.ARRAYNAMES + 1
  local arrnlist = {}
  for _, v in pairs(hsc.ARRAYNAMES) do
    table.insert(arrnlist, v)
  end
  table.insert(arrnlist, "Pat")
  if notetab == 1 then
    todraw = {{false, 0}, {arrnlist[1], 1}, {arrnlist[2], 2}}
  elseif notetab == arrn then
    todraw = {
      {arrnlist[arrn - 1], arrn - 1},
      {arrnlist[arrn], arrn},
      {false, 0}
    }
  else
    todraw = {
      {arrnlist[notetab - 1], notetab - 1},
      {arrnlist[notetab], notetab},
      {arrnlist[notetab + 1], notetab + 1}
    }
  end

  for k, v in ipairs(todraw) do
    screen.move(5, k * 18)
    screen.level(k == 2 and 10 or 1)
    if v[1] == "Pat" then
      local nxt = data.next
      if not data.switching then nxt = "~"..nxt.."~" end
      screen.text("Pat: " .. data:idx() .. " -> " .. nxt)
    elseif v[1] ~= false then
      screen.text(hsc.ARRDIS[v[2]] .. ":")
      draw_note_array(
        26,
        k * 18,
        data:current()[v[1]].seq.ix,
        util.wrap(cursor_idx, 1, #data:current()[v[1]].seq.data),
        data:current()[v[1]].seq,
        v[2] == 1
      )
    end
  end

  if ALTKEY then
    local arrname = todraw[2][1]
    local seqlen = notetab == 8 and data:current().plen or #data:current()[arrname].seq
    local seqdiv = hsc.NOTELEN_STR[notetab == 8 and data:current().pdiv or params:get(hsc.n(arrname .. "_div"))]
    local seqalt = notetab == 8 and "----" or (data:current()[arrname].type == "off" and "poly" or "----")
    local lenstr = "alt/" .. seqlen
    local pulstr = (seqlat.enabled and "stop" or "play") .. "/" .. seqdiv
    local synstr = notetab == 8 and "Confirm" or "Rst" .. "/" .. seqalt
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

return HSGRP
