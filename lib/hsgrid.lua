-- module
local HSGRID = {}
local hsc = require('hs010/lib/hsconst')
local hsgrp = require('hs010/lib/hsgraphics')

-- private variables
local g
local grid_page = 1 -- page 1 - edit, page 2 - length, page 3 - division, page 4 - patterns
local grid_offset = 1
local val_select = false
local val_select_item
local copypat = nil

-- private grid drawing/formatting functions

local function degree(v)
  return math.floor(util.linlin(1,7,2,12,v))
end

local function vel(v)
  return math.floor(util.linlin(1,8,2,12,v))
end

local function oct(v)
  return math.floor(util.linlin(1,8,2,12,v))
end

local function off_a(v)
  local blink = 1
  if v[2] then
    blink = hsgrp.frame % 10 / 9
  end
  return math.floor(util.linlin(-12,12,2,12,v[1]) * blink)
end

local function off_b(v)
  local blink = 1
  if v[2] then
    blink = hsgrp.frame % 10 / 9
  end
  return math.floor(util.linlin(-12,12,2,12,v[1]) * blink)
end

local function gate(v)
  return v and 8 or 2
end

local function slide(v)
  return v and 8 or 2
end

local grid_page_func = {degree, vel, oct, off_a, off_b, gate, slide}

-- private functions

local function draw_value_picker(data, arrname, x, y)
  local val_amount = hsc.BOUNDS[y][2] - hsc.BOUNDS[y][1] + 1
  local idx = 1
  local list_val = data:current()[arrname].seq.data[x + (grid_offset - 1) * 16]
  local curval = math.floor(util.linlin(
    hsc.BOUNDS[y][1], hsc.BOUNDS[y][2],
    1, val_amount,
    y > 3 and list_val[1] or list_val
  ))
  local offset_x = x < 9 and 8 or 0;
  for iy = 1, 7, 1 do
    for ix = offset_x + 1, offset_x + 8, 1 do
      local lightval = 0
      if idx == curval then
        lightval = 15
        idx = idx + 1
      elseif idx <= val_amount then
        lightval = math.floor(12 * idx / val_amount)
        idx = idx + 1
      end
      g:led(ix, iy, lightval)
    end
  end
  if y > 3 then
    local poly_on = list_val[2]
    g:led(offset_x + 1, 7, poly_on and 2 or 15)
    g:led(offset_x + 2, 7, poly_on and 15 or 2)
  end
end

local function pick_value(data, val, item, x, y)
  local arrname = val[1]
  local ox = val[2]
  local oy = val[3]
  local val_amount = hsc.BOUNDS[oy][2] - hsc.BOUNDS[oy][1] + 1
  local offset_x = x < 9 and 0 or 8;
  local retval = data:current()[arrname].seq.data[ox + (grid_offset - 1) * 16]
  local selectedval = (y - 1) * 8 + (x - offset_x)
  if val_amount >= selectedval then
    local vv = math.floor(util.linlin(
      1, val_amount,
      hsc.BOUNDS[oy][1], hsc.BOUNDS[oy][2],
      selectedval
    ))
    if oy > 3 then retval[1] = vv
    else retval = vv
    end
  end
  if oy > 3 then
    if y == 7 and x == offset_x + 1 then retval[2] = false end
    if y == 7 and x == offset_x + 2 then retval[2] = true end
  end
  return retval
end

local function handle_grid(x, y, z, data, seqlat)

  if z == 0 then
    if grid_page == 4 and y < 3 then
        local idx = x + (y - 1) * 16
        if copypat == idx then
          data.next = idx
          data.switching = true
          copypat = nil
        end
    end
  end

  if z == 1 then
    if y == 8 then
      if x == 1 then seqlat:toggle() end
      if x == 2 then data:current():reset() end
      if x > 3 and x < 8 then grid_page = x - 3 end
      if x > 12 then
          grid_offset = x - 12
      end
    elseif val_select then
      local item = val_select_item[2] + (grid_offset - 1) * 16
      local newval = pick_value(data, val_select_item, item, x, y)
      data:current()[val_select_item[1]].seq.data[item] = newval
    else
      if grid_page == 4 and y < 3 then
        idx = x + (y - 1) * 16
        if copypat ~= nil then
          data:copy(copypat, idx)
          copypat = nil
        else
          copypat = x + (y - 1) * 16
        end
      elseif grid_page == 3 then
        local arrname = hsc.ARRAYNAMES[y]
        params:set(hsc.n(arrname .. "_div"), x)
      elseif grid_page == 2 then
        local arrname = hsc.ARRAYNAMES[y]
        params:set(hsc.n(arrname .. "_len"), x + (grid_offset - 1) * 16)
      elseif grid_page == 1 and y < 6 then
        local arrname = hsc.ARRAYNAMES[y]
        if x + (grid_offset - 1) * 16 <= #data:current()[arrname].seq.data then
          val_select = true
          val_select_item = {arrname, x, y}
        end
      else
        local arrname = hsc.ARRAYNAMES[y]
        local item = x + (grid_offset - 1) * 16
        if item <= #data:current()[arrname].seq.data then
          local v = data:current()[arrname].seq.data[item]
          data:current()[arrname].seq.data[item] = not v
        end
      end
    end
  else
    if val_select and
      grid_page == 1 and
      x == val_select_item[2] and
      y == val_select_item[3] then val_select = false end
  end
  HSGRID.draw_grid(data, seqlat.enabled)
end

-- public functions

function HSGRID.draw_grid(data, running)
  g:all(0)
  if grid_page == 4 then
    for yy = 0, 1 do
      for xx = 1, 16 do
        local idx = yy * 16 + xx
        if not data.pat[idx].init then
          g:led(xx, yy + 1, 4)
        elseif idx == data:idx() then
          local blink = hsgrp.frame % 10 / 9
          g:led(xx, yy + 1, math.floor(15 * blink))
        else
          g:led(xx, yy + 1, 15)
        end
      end
    end
  elseif grid_page ~= 3 then
    for k, v in pairs(hsc.ARRAYNAMES) do
      local nt = data:current()[v].seq
      local ix = nt.ix
      local offset_x = (grid_offset - 1) * 16
      for ig=1,#nt-offset_x,1 do
        if ig > 16 then break end
        g:led(ig, k, ig + offset_x == ix and 15 or grid_page_func[k](nt[ig + offset_x]))
      end
    end
  else
    for k, v in pairs(hsc.ARRAYNAMES) do
      g:led(params:get(hsc.n(v .. "_div")), k, 15)
    end
  end
  if val_select then
    draw_value_picker(data, val_select_item[1], val_select_item[2], val_select_item[3])
  end
  g:led(1, 8, running and 15 or 4)
  g:led(2, 8, 4)
  for ig=1,4,1 do
    g:led(3 + ig, 8, ig == grid_page and 15 or 4)
  end

  for ig=1,4,1 do
    local lightval = 4
    local blink = hsgrp.frame % 10 / 9
    if grid_offset == ig then lightval = 15 end
    if grid_offset > 4 and ig == 4 then lightval = math.floor(15 * blink) end
    g:led(12+ig, 8, lightval)
  end
  g:refresh()
end

-- init grid
function HSGRID.init(data, seqlat)
  g = grid.connect()
  g:refresh()
  g.key = function(x,y,z) handle_grid(x,y,z,data,seqlat) end
  HSGRID.draw_grid(data, seqlat.enabled)
end

return HSGRID
