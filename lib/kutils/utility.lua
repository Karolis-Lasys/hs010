-- module
local KUTILS = {}
local musicutil = require 'musicutil'
local util = require 'util'

KUTILS.debug = false -- global debug flag

function KUTILS.pd(string)
  if KUTILS.debug then print(string) end
end

function KUTILS.d2s(item)
  local ret = ""
  if type(item) == "table" then
    ret = ret .. "{"
    for k, v in pairs(item) do
      ret = ret .. k .. ": " .. KUTILS.d2s(v) .. " "
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

function KUTILS.from_degree_to_note(degree, scale, purgeoct)
  local note_number = #scale
  local degree_pure = util.wrap(degree, 1, note_number)
  local degree_oct = 0
  if not purgeoct then
    degree_oct = (degree - degree_pure) // note_number
  end
  return scale[degree_pure] + degree_oct * 12
end

function KUTILS.scale_quant(note, scale)
  local fnote = math.fmod(math.min(math.max(note, 0), 127), 12)
  local oct = note - fnote
  return musicutil.snap_note_to_array(fnote, scale) + oct
end

return KUTILS
