-- module
local s = require 'sequins'
local hsc = require('hs010/lib/hsconst')
local HSDATA = {}

HSDATA.hsseqlane = {}

function HSDATA.hsseqlane:new(type, seq, div)
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  obj.seq = s{}
  obj.prev = {}
  obj.seq:settable(seq)
  obj.div = div or 7
  obj.type = type
  return obj
end

function HSDATA.hsseqlane:reset()
  self.seq:reset()
end

function HSDATA.hsseqlane:shrink(newlen)
  local seq = self.seq.data
  local num = newlen - #seq
  if num > 0 then
    for x = 0, num - 1 do
      local val
      if self.type == "off" then
        val = {}
        for k, v in pairs(seq[1]) do
          val[k] = v
        end
      else
        val = seq[1]
      end
      if #self.prev > 0 then
        val = table.remove(self.prev)
      end
      table.insert(seq, val)
    end
  else
    for x = 0, math.abs(num) - 1 do
      if #seq > 1 then
        table.insert(self.prev, table.remove(seq))
      end
    end
  end
  self.seq:settable(seq)
end

function HSDATA.hsseqlane:next()
  return self.seq()
end

function HSDATA.hsseqlane:set_div(newdiv)
  self.div = newdiv
end

function HSDATA.hsseqlane:get_div()
  return hsc.NOTELEN[self.div]
end

HSDATA.hsp = {}

function HSDATA.hsp:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  obj.note = HSDATA.hsseqlane:new("note", {0, 0, 0, 0})
  obj.vel = HSDATA.hsseqlane:new("vel", {7, 7, 7, 7})
  obj.oct = HSDATA.hsseqlane:new("oct", {3, 3, 3, 3})
  obj.off_a = HSDATA.hsseqlane:new("off", {{0, false}, {0, false}, {0, false}, {0, false}})
  obj.off_b = HSDATA.hsseqlane:new("off", {{0, false}, {0, false}, {0, false}, {0, false}})
  obj.gate = HSDATA.hsseqlane:new("trig", {true, true, true, true})
  obj.slide = HSDATA.hsseqlane:new("trig", {false, false, false, false})
  obj.plen = 16
  obj.pdiv = 3
  obj.init = false
  return obj
end

function HSDATA.hsp:reset()
  self.note:reset()
  self.vel:reset()
  self.oct:reset()
  self.off_a:reset()
  self.off_b:reset()
  self.gate:reset()
  self.slide:reset()
  self.slide:next()
end

function HSDATA.hsp:get_div()
  return hsc.NOTELEN[self.pdiv]
end

HSDATA.hspt = {}

function HSDATA.hspt:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  obj.pat = {}
  obj.cur = 1
  obj.next = 1
  obj.switching = false
  for i = 1, 32 do
    obj.pat[i] = HSDATA.hsp:new()
  end
  obj:current().init = true
  return obj
end

function HSDATA.hspt:reset()
  self:current():reset()
end

function HSDATA.hspt:current()
  return self.pat[self.cur]
end

function HSDATA.hspt:idx()
  return self.cur
end

function HSDATA.hspt:set(patno)
  if patno <= 32 and patno > 0 then
    self:reset()
    if self.pat[patno].init ~= true then
      self:copy(self.cur, patno)
    end
    self.cur = patno
    self:update_param()
    self:current().init = true
  end
end

function HSDATA.hspt:update_param()
  params:set(hsc.n("patchange_len"), self:current().plen, true)
  params:set(hsc.n("patchange_div"), self:current().pdiv, true)
  params:set(hsc.n("note_len"), #self:current().note.seq.data, true)
  params:set(hsc.n("vel_len"), #self:current().vel.seq.data, true)
  params:set(hsc.n("oct_len"), #self:current().oct.seq.data, true)
  params:set(hsc.n("off_a_len"), #self:current().off_a.seq.data, true)
  params:set(hsc.n("off_b_len"), #self:current().off_b.seq.data, true)
  params:set(hsc.n("slide_len"), #self:current().slide.seq.data, true)
  params:set(hsc.n("gate_len"), #self:current().gate.seq.data, true)
  params:set(hsc.n("note_div"), self:current().note.div)
  params:set(hsc.n("vel_div"), self:current().vel.div)
  params:set(hsc.n("oct_div"), self:current().oct.div)
  params:set(hsc.n("off_a_div"), self:current().off_a.div)
  params:set(hsc.n("off_b_div"), self:current().off_b.div)
  params:set(hsc.n("slide_div"), self:current().slide.div)
  params:set(hsc.n("gate_div"), self:current().gate.div)
end

function HSDATA.hspt:copy(from, to)
  for _, v in pairs(hsc.ARRAYNAMES) do
    self.pat[to][v].seq = self.pat[from][v].seq:copy()
    self.pat[to][v].div = self.pat[from][v].div
  end
  self.pat[to].plen = self.pat[from].plen
  self.pat[to].pdiv = self.pat[from].pdiv
  self.pat[to].init = self.pat[from].init
end

function HSDATA.hspt:serialize()
  local tt = {}
  tt.cur = self.cur
  tt.pat = {}
  for k, v in pairs(self.pat) do
    table.insert(tt.pat, {})
    tt.pat[k].init = v.init
    tt.pat[k].pdev = v.pdev
    tt.pat[k].plen = v.plen
    for _, vv in pairs(hsc.ARRAYNAMES) do
      tt.pat[k][vv] = {}
      tt.pat[k][vv].type = v[vv].type
      tt.pat[k][vv].div = v[vv].div
      tt.pat[k][vv].prev = v[vv].prev
      tt.pat[k][vv].seq = v[vv].seq.data
    end
  end
  return tt
end

function HSDATA.hspt:deserialise(tt)
  self.cur = tt.cur
  for k, v in pairs(self.pat) do
    v.init = tt.pat[k].init
    v.pdev = tt.pat[k].pdev
    v.plen = tt.pat[k].plen
    for _, vv in pairs(hsc.ARRAYNAMES) do
      v[vv].type = tt.pat[k][vv].type
      v[vv].div = tt.pat[k][vv].div
      v[vv].prev = tt.pat[k][vv].prev
      v[vv].seq:settable(tt.pat[k][vv].seq)
    end
  end
end

return HSDATA
